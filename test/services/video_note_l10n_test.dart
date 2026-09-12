import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Video Note Localization Tests (10 Languages)', () {
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
      'chat_video_note',
      'chat_video_note_hold_hint',
      'chat_video_note_swipe_cancel',
      'chat_video_note_release_cancel',
      'chat_video_note_lock',
      'chat_video_note_too_short',
      'chat_video_note_send',
      'chat_video_note_discard',
      'chat_video_note_flip_camera',
      'chat_video_note_stop',
      'chat_video_note_tap_switch',
      'chat_video_note_tap_voice',
      'chat_video_note_permission_denied',
    ];

    for (final locale in expectedLocales) {
      test('Locale "$locale.json" contains all required video note keys', () {
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
