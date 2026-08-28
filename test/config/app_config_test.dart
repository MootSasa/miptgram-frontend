import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miptgram/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig Helper Methods', () {
    test('deriveWsUrl converts http/https endpoints correctly', () {
      expect(
        AppConfig.deriveWsUrl('http://localhost:8080'),
        equals('ws://localhost:8080/api/ws'),
      );
      expect(
        AppConfig.deriveWsUrl('https://api.miptgram.ru'),
        equals('wss://api.miptgram.ru/api/ws'),
      );
      expect(
        AppConfig.deriveWsUrl('http://192.168.1.50:8080/api'),
        equals('ws://192.168.1.50:8080/api/ws'),
      );
      expect(
        AppConfig.deriveWsUrl('http://192.168.1.50:8080/api/ws'),
        equals('ws://192.168.1.50:8080/api/ws'),
      );
      expect(
        AppConfig.deriveWsUrl('https://custom.domain.com:8443'),
        equals('wss://custom.domain.com:8443/api/ws'),
      );
    });

    test('deriveStorageUrl resolves MinIO storage endpoints correctly', () {
      expect(
        AppConfig.deriveStorageUrl('https://api.miptgram.ru'),
        equals('https://storage.miptgram.ru'),
      );
      expect(
        AppConfig.deriveStorageUrl('http://localhost:8080'),
        equals('http://localhost:9000'),
      );
      expect(
        AppConfig.deriveStorageUrl('http://192.168.1.50:8080'),
        equals('http://192.168.1.50:9000'),
      );
      expect(
        AppConfig.deriveStorageUrl('http://10.0.2.2:8080'),
        equals('http://10.0.2.2:9000'),
      );
    });

    test('getProfileUrl and getInviteUrl format deep links', () {
      final profileUrl = AppConfig.getProfileUrl('test_user_123');
      expect(profileUrl, contains('/u/test_user_123'));

      final inviteUrl = AppConfig.getInviteUrl('invite_abc_789');
      expect(inviteUrl, contains('/join/invite_abc_789'));
    });

    test('resolveMediaUrl handles relative and absolute paths', () {
      expect(AppConfig.resolveMediaUrl(null), isNull);
      expect(AppConfig.resolveMediaUrl(''), isNull);
      expect(
        AppConfig.resolveMediaUrl('https://example.com/image.png'),
        equals('https://example.com/image.png'),
      );
      expect(
        AppConfig.resolveMediaUrl('http://example.com/image.png'),
        equals('http://example.com/image.png'),
      );
      expect(
        AppConfig.resolveMediaUrl('data:image/png;base64,iVBORw0KGgo='),
        equals('data:image/png;base64,iVBORw0KGgo='),
      );

      final resolvedRelative = AppConfig.resolveMediaUrl('/avatars/user1.jpg');
      expect(resolvedRelative, isNotNull);
      expect(resolvedRelative, endsWith('/avatars/user1.jpg'));
      expect(resolvedRelative, startsWith('http'));

      final resolvedWithoutLeadingSlash = AppConfig.resolveMediaUrl('avatars/user2.jpg');
      expect(resolvedWithoutLeadingSlash, isNotNull);
      expect(resolvedWithoutLeadingSlash, endsWith('/avatars/user2.jpg'));
    });
  });

  group('AppConfig Dynamic Runtime Overrides', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
    });

    tearDown(() async {
      await AppConfig.resetToDefaults();
    });

    test('custom server URL overrides baseUrl, wsUrl, and storageUrl', () async {
      const customIp = 'http://192.168.1.120:8080';
      await AppConfig.setCustomServerUrl(customIp);

      expect(AppConfig.baseUrl, equals(customIp));
      expect(AppConfig.wsUrl, equals('ws://192.168.1.120:8080/api/ws'));
      expect(AppConfig.storageUrl, equals('http://192.168.1.120:9000'));

      // Verify persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConfig.prefCustomServerUrlKey), equals(customIp));

      // Reset
      await AppConfig.resetToDefaults();
      expect(AppConfig.baseUrl, equals(AppConfig.prodApiBaseUrl));
    });
  });
}
