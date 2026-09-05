import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:miptgram/services/chat_service.dart';
import 'package:miptgram/services/websocket_service.dart';

void main() {
  group('Message Editing Unit Tests', () {
    test('Message copyWith updates content and isEdited', () {
      final msg = Message(
        id: 'msg-123',
        chatId: 'chat-456',
        senderId: 'user-789',
        senderName: 'Test User',
        content: 'Original content',
        messageType: 'text',
        createdAt: '2026-09-04T00:00:00Z',
        isEdited: false,
      );

      expect(msg.content, 'Original content');
      expect(msg.isEdited, false);

      final edited = msg.copyWith(
        content: 'Edited content',
        isEdited: true,
      );

      expect(edited.id, 'msg-123');
      expect(edited.chatId, 'chat-456');
      expect(edited.senderId, 'user-789');
      expect(edited.content, 'Edited content');
      expect(edited.isEdited, true);
    });

    test('WebSocketEvent parses message_edited event type', () {
      final rawEvent = {
        'type': 'message_edited',
        'data': {
          'chat_id': 'chat-456',
          'message_id': 'msg-123',
          'content': 'Updated text from websocket',
          'is_edited': true,
          'edited_at': '2026-09-04T02:00:00Z',
        },
        'timestamp': 1725415200000,
      };

      final event = WebSocketEvent.fromJson(rawEvent);

      expect(event.type, WebSocketEventType.messageEdited);
      expect(event.data['message_id'], 'msg-123');
      expect(event.data['content'], 'Updated text from websocket');
      expect(event.data['is_edited'], true);
    });

    test('All 10 localization files contain message editing keys', () {
      final languages = ['ru', 'en', 'de', 'es', 'fr', 'it', 'ja', 'ko', 'pt', 'zh'];
      final requiredKeys = [
        'chat_edited',
        'chat_edit_message',
        'chat_editing_title',
        'chat_edit_error',
      ];

      for (final lang in languages) {
        final file = File('assets/l10n/$lang.json');
        expect(file.existsSync(), isTrue, reason: 'File $lang.json must exist');

        final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final key in requiredKeys) {
          expect(
            content.containsKey(key),
            isTrue,
            reason: 'Language $lang must contain key $key',
          );
          expect(
            (content[key] as String).isNotEmpty,
            isTrue,
            reason: 'Key $key in language $lang must not be empty',
          );
        }
      }
    });
  });
}
