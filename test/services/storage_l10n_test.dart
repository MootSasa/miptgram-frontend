import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Section 3.6 Storage Management Localization Tests (10 Languages)', () {
    final expectedLocales = [
      'ru',
      'en',
      'de',
      'es',
      'fr',
      'it',
      'ja',
      'ko',
      'pt',
      'zh',
    ];

    final requiredKeys = [
      'storage_title',
      'storage_clear_cache',
      'storage_keep_media',
      'storage_media_size',
      'storage_device_cache',
      'storage_device_cache_desc',
      'storage_cloud_note',
      'storage_keep_3days',
      'storage_keep_media_desc',
      'storage_max_cache_size',
      'storage_max_cache_size_desc',
      'storage_no_limit',
      'storage_other',
      'storage_free_space',
      'storage_cache_cleared',
      'storage_calculating',
      'storage_select_all',
      'storage_deselect_all',
      'storage_clear_selected',
    ];

    for (final locale in expectedLocales) {
      test('Locale "$locale.json" contains all Section 3.6 storage keys', () {
        final file = File('assets/l10n/$locale.json');
        expect(file.existsSync(), isTrue,
            reason: 'Translation file assets/l10n/$locale.json should exist');

        final jsonString = file.readAsStringSync();
        final Map<String, dynamic> data = jsonDecode(jsonString);

        for (final key in requiredKeys) {
          expect(data.containsKey(key), isTrue,
              reason: 'Key "$key" missing in $locale.json');
          expect(data[key], isA<String>(),
              reason: 'Value for "$key" should be a String in $locale.json');
          expect((data[key] as String).trim().isNotEmpty, isTrue,
              reason: 'Value for "$key" must not be empty in $locale.json');
        }
      });
    }
  });
}
