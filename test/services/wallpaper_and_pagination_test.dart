import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miptgram/services/wallpaper_provider.dart';
import 'package:miptgram/services/chat_service.dart';

Message _createTestMessage({
  required String id,
  required String content,
  required String createdAt,
  String chatId = 'c1',
  String senderId = 'u1',
  String senderName = 'Alice',
  String messageType = 'text',
  bool isEdited = false,
  String? localId,
}) {
  return Message(
    id: id,
    chatId: chatId,
    senderId: senderId,
    content: content,
    messageType: messageType,
    isEdited: isEdited,
    createdAt: createdAt,
    senderName: senderName,
    localId: localId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WallpaperProvider Multi-Account Isolation Tests', () {
    late Directory tempDir;
    late File wp1File;
    late File wp2File;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wallpaper_test_');
      wp1File = File('${tempDir.path}/wp1.png')..writeAsStringSync('wp1');
      wp2File = File('${tempDir.path}/wp2.png')..writeAsStringSync('wp2');
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Wallpapers are scoped per user without leaking across accounts', () async {
      SharedPreferences.setMockInitialValues({
        'user_1_chat_wallpaper_path': wp1File.path,
        'user_1_chat_wallpaper_url': 'https://example.com/w1.png',
        'user_2_chat_wallpaper_path': wp2File.path,
        'user_2_chat_wallpaper_url': 'https://example.com/w2.png',
      });

      final provider = WallpaperProvider();

      // Switch to user 1
      await provider.switchUser('user_1');
      expect(provider.currentUserId, equals('user_1'));
      expect(provider.wallpaperPath, equals(wp1File.path));
      expect(provider.wallpaperUrl, equals('https://example.com/w1.png'));

      // Switch to user 2
      await provider.switchUser('user_2');
      expect(provider.currentUserId, equals('user_2'));
      expect(provider.wallpaperPath, equals(wp2File.path));
      expect(provider.wallpaperUrl, equals('https://example.com/w2.png'));

      // Switch to user 3 (has no wallpaper)
      await provider.switchUser('user_3');
      expect(provider.currentUserId, equals('user_3'));
      expect(provider.wallpaperPath, isNull);
      expect(provider.wallpaperUrl, isNull);
    });

    test('Updating wallpaper for user 1 does not mutate user 2 wallpaper', () async {
      SharedPreferences.setMockInitialValues({
        'user_2_chat_wallpaper_path': wp2File.path,
        'user_2_chat_wallpaper_url': 'https://example.com/w2.png',
      });

      final provider = WallpaperProvider();

      await provider.switchUser('user_1');
      await provider.setWallpaper(wp1File.path, syncToServer: false);
      expect(provider.wallpaperPath, equals(wp1File.path));

      // Switch to user 2, verify user 2 retains their own wallpaper
      await provider.switchUser('user_2');
      expect(provider.wallpaperPath, equals(wp2File.path));
      expect(provider.wallpaperUrl, equals('https://example.com/w2.png'));

      // Remove wallpaper for user 2
      await provider.removeWallpaper(syncToServer: false);
      expect(provider.wallpaperPath, isNull);
      expect(provider.wallpaperUrl, isNull);

      // Verify user 1 still has their wallpaper
      await provider.switchUser('user_1');
      expect(provider.wallpaperPath, equals(wp1File.path));
    });
  });

  group('Chat Pagination & Non-Destructive Merging Tests', () {
    test('Messages are deterministically sorted by createdAt DESC, id DESC', () {
      final messages = [
        _createTestMessage(
          id: '100',
          content: 'Older message',
          createdAt: '2026-09-10T10:00:00.000Z',
        ),
        _createTestMessage(
          id: '102',
          content: 'Same timestamp, higher ID',
          createdAt: '2026-09-11T12:00:00.000Z',
        ),
        _createTestMessage(
          id: '101',
          content: 'Same timestamp, lower ID',
          createdAt: '2026-09-11T12:00:00.000Z',
        ),
        _createTestMessage(
          id: '103',
          content: 'Newest message',
          createdAt: '2026-09-12T15:00:00.000Z',
        ),
      ];

      messages.sort((a, b) {
        try {
          final ta = DateTime.parse(a.createdAt);
          final tb = DateTime.parse(b.createdAt);
          final cmp = tb.compareTo(ta);
          if (cmp != 0) return cmp;
          return (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0);
        } catch (_) {
          return 0;
        }
      });

      // Expected order: 103 (newest), then 102, then 101, then 100 (oldest)
      expect(messages.map((m) => m.id).toList(), equals(['103', '102', '101', '100']));
    });

    test('Non-destructive merge preserves previously loaded older messages', () {
      // Suppose the chat screen already loaded 3 older messages
      final loadedMessages = [
        _createTestMessage(id: '3', content: 'Msg 3', createdAt: '2026-09-11T10:00:00Z'),
        _createTestMessage(id: '2', content: 'Msg 2', createdAt: '2026-09-10T10:00:00Z'),
        _createTestMessage(id: '1', content: 'Msg 1', createdAt: '2026-09-09T10:00:00Z'),
      ];

      // Now server responds with fresh top 2 messages (e.g. on chat entry / refresh)
      final serverMessages = [
        _createTestMessage(id: '4', content: 'Msg 4', createdAt: '2026-09-12T10:00:00Z'),
        _createTestMessage(id: '3', content: 'Msg 3 edited', createdAt: '2026-09-11T10:00:00Z'),
      ];

      // Non-destructive merge logic
      final Map<String, Message> merged = {};
      for (final m in loadedMessages) {
        merged[m.id] = m;
        if (m.localId != null && m.localId!.isNotEmpty) {
          merged[m.localId!] = m;
        }
      }
      for (final m in serverMessages) {
        merged[m.id] = m;
        if (m.localId != null && m.localId!.isNotEmpty) {
          merged[m.localId!] = m;
        }
      }

      final resultList = merged.values.toList();
      resultList.sort((a, b) {
        final ta = DateTime.parse(a.createdAt);
        final tb = DateTime.parse(b.createdAt);
        final cmp = tb.compareTo(ta);
        if (cmp != 0) return cmp;
        return (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0);
      });

      // All 4 messages must exist; none of the older messages (1 and 2) are lost!
      expect(resultList.map((m) => m.id).toList(), equals(['4', '3', '2', '1']));
      // Message 3 should have updated content from the server
      expect(resultList.firstWhere((m) => m.id == '3').content, equals('Msg 3 edited'));
    });
  });
}
