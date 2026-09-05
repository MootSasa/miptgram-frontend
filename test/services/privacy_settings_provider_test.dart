import 'package:flutter_test/flutter_test.dart';
import 'package:miptgram/services/privacy_settings_provider.dart';

void main() {
  group('PrivacySettingsProvider TTL Tests', () {
    test('Default account TTL is 6 months', () {
      final provider = PrivacySettingsProvider();
      expect(provider.accountTTLMonths, equals(6));
    });
  });
}
