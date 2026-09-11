import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miptgram/services/account_manager.dart';
import 'package:miptgram/services/profile_theme_provider.dart';
import 'package:miptgram/utils/image_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Account Model localAvatarPath tests', () {
    test('Account serializes and deserializes localAvatarPath correctly', () {
      final account = Account(
        userId: 'u123',
        token: 'token_abc',
        username: 'alice',
        displayName: 'Alice M',
        avatarUrl: 'https://example.com/avatar.jpg',
        localAvatarPath: '/local/path/avatar_u123.jpg',
      );

      final json = account.toJson();
      expect(json['userId'], equals('u123'));
      expect(json['token'], equals('token_abc'));
      expect(json['avatarUrl'], equals('https://example.com/avatar.jpg'));
      expect(json['localAvatarPath'], equals('/local/path/avatar_u123.jpg'));

      final restored = Account.fromJson(json);
      expect(restored.userId, equals('u123'));
      expect(restored.token, equals('token_abc'));
      expect(restored.avatarUrl, equals('https://example.com/avatar.jpg'));
      expect(restored.localAvatarPath, equals('/local/path/avatar_u123.jpg'));
    });

    test('Account copyWith retains or updates localAvatarPath', () {
      final account = Account(
        userId: 'u123',
        token: 'token_abc',
        localAvatarPath: '/old/avatar.jpg',
      );

      final updatedToken = account.copyWith(token: 'new_token');
      expect(updatedToken.localAvatarPath, equals('/old/avatar.jpg'));

      final updatedAvatar = account.copyWith(localAvatarPath: '/new/avatar.jpg');
      expect(updatedAvatar.localAvatarPath, equals('/new/avatar.jpg'));
    });
  });

  group('ProfileThemeProvider Multi-Account Isolation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Styling preferences are scoped per user without leaking', () async {
      SharedPreferences.setMockInitialValues({
        'userA_profile_color_preset_id': 'red',
        'userA_user_name_color_preset_id': 'name_orange',
        'userB_profile_color_preset_id': 'blue',
        'userB_user_name_color_preset_id': 'name_green',
      });

      final provider = ProfileThemeProvider();
      
      // Switch to user A
      await provider.switchUser('userA');
      expect(provider.selectedPresetId, equals('red'));
      expect(provider.currentNameColorPreset.id, equals('name_orange'));

      // Switch to user B
      await provider.switchUser('userB');
      expect(provider.selectedPresetId, equals('blue'));
      expect(provider.currentNameColorPreset.id, equals('name_green'));
    });

    test('Updating styling for user A does not mutate user B preferences', () async {
      final provider = ProfileThemeProvider();

      // Set user A style
      await provider.switchUser('userA');
      await provider.setPreset(ProfileColorPresets.pink);
      expect(provider.selectedPresetId, equals('pink'));

      // Set user B style
      await provider.switchUser('userB');
      expect(provider.selectedPresetId, isNot(equals('pink')));
      await provider.setPreset(ProfileColorPresets.green);
      expect(provider.selectedPresetId, equals('green'));

      // Switch back to user A
      await provider.switchUser('userA');
      expect(provider.selectedPresetId, equals('pink'));
    });
  });

  group('ImageUtils URL & Fallback Tests', () {
    test('getValidAvatarUrl returns null for invalid inputs', () {
      expect(getValidAvatarUrl(null), isNull);
      expect(getValidAvatarUrl(''), isNull);
      expect(getValidAvatarUrl('invalid-url-without-scheme'), isNull);
    });

    test('getValidAvatarUrl handles data URLs and full http/https URLs', () {
      expect(getValidAvatarUrl('data:image/png;base64,iVBORw0KGgo='), isNotNull);
      expect(getValidAvatarUrl('https://miptgram.ru/avatar.jpg'), equals('https://miptgram.ru/avatar.jpg'));
      expect(getValidAvatarUrl('http://192.168.1.1:8080/avatar.jpg'), equals('http://192.168.1.1:8080/avatar.jpg'));
    });

    test('getValidAvatarUrl handles relative URLs by prefixing AppConfig baseUrl', () {
      final valid = getValidAvatarUrl('/avatars/user123.jpg');
      expect(valid, isNotNull);
      expect(valid!.endsWith('/avatars/user123.jpg'), isTrue);
      expect(valid.startsWith('http'), isTrue);
    });
  });
}
