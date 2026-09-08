import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:miptgram/utils/entity_parser.dart';
import 'package:miptgram/services/chat_service.dart';
import 'package:miptgram/widgets/chat/rich_text_editing_controller.dart';

void main() {
  group('EntityParser Markdown Parsing', () {
    test('parses bold syntax', () {
      final res = EntityParser.parseMarkdown('Hello **bold text** world');
      expect(res.cleanText, 'Hello bold text world');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'bold');
      expect(res.entities.first.offset, 6);
      expect(res.entities.first.length, 'bold text'.length);
    });

    test('parses italic syntax', () {
      final res = EntityParser.parseMarkdown('Hello *italic* and _italic2_');
      expect(res.cleanText, 'Hello italic and italic2');
      expect(res.entities.length, 2);
      expect(res.entities[0].type, 'italic');
      expect(res.entities[0].offset, 6);
      expect(res.entities[0].length, 'italic'.length);
      expect(res.entities[1].type, 'italic');
      expect(res.entities[1].offset, 17);
      expect(res.entities[1].length, 'italic2'.length);
    });

    test('parses strikethrough syntax', () {
      final res = EntityParser.parseMarkdown('~~strikethrough~~');
      expect(res.cleanText, 'strikethrough');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'strikethrough');
      expect(res.entities.first.offset, 0);
      expect(res.entities.first.length, 'strikethrough'.length);
    });

    test('parses underline syntax', () {
      final res = EntityParser.parseMarkdown('__underlined text__');
      expect(res.cleanText, 'underlined text');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'underline');
      expect(res.entities.first.offset, 0);
      expect(res.entities.first.length, 'underlined text'.length);
    });

    test('parses spoiler syntax', () {
      final res = EntityParser.parseMarkdown('Look at ||this secret|| now');
      expect(res.cleanText, 'Look at this secret now');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'spoiler');
      expect(res.entities.first.offset, 8);
      expect(res.entities.first.length, 'this secret'.length);
    });

    test('parses inline code syntax', () {
      final res = EntityParser.parseMarkdown('run `flutter test` here');
      expect(res.cleanText, 'run flutter test here');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'code');
      expect(res.entities.first.offset, 4);
      expect(res.entities.first.length, 'flutter test'.length);
    });

    test('parses pre / code block syntax with language', () {
      final res = EntityParser.parseMarkdown('```dart\nvoid main() {}\n```');
      expect(res.cleanText, 'void main() {}');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'pre');
      expect(res.entities.first.language, 'dart');
      expect(res.entities.first.offset, 0);
      expect(res.entities.first.length, 'void main() {}'.length);
    });

    test('parses blockquote syntax', () {
      final res = EntityParser.parseMarkdown('> This is a quote');
      expect(res.cleanText, 'This is a quote');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'blockquote');
      expect(res.entities.first.collapsed, false);
      expect(res.entities.first.offset, 0);
      expect(res.entities.first.length, 'This is a quote'.length);
    });

    test('parses collapsible blockquote syntax', () {
      final res = EntityParser.parseMarkdown('**> This is a collapsible quote');
      expect(res.cleanText, 'This is a collapsible quote');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'blockquote');
      expect(res.entities.first.collapsed, true);
    });

    test('parses text_link syntax', () {
      final res = EntityParser.parseMarkdown('Visit [MIPT](https://mipt.ru) today');
      expect(res.cleanText, 'Visit MIPT today');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'text_link');
      expect(res.entities.first.url, 'https://mipt.ru');
      expect(res.entities.first.offset, 6);
      expect(res.entities.first.length, 4);
    });

    test('parses standalone URL syntax', () {
      final res = EntityParser.parseMarkdown('Check https://example.com for info');
      expect(res.cleanText, 'Check https://example.com for info');
      expect(res.entities.length, 1);
      expect(res.entities.first.type, 'url');
      expect(res.entities.first.url, 'https://example.com');
      expect(res.entities.first.offset, 6);
      expect(res.entities.first.length, 'https://example.com'.length);
    });
  });

  group('EntityParser UTF-16 Offset Handling', () {
    test('handles emoji surrogate pairs correctly in offsets', () {
      // 🚀 is 2 UTF-16 code units (surrogate pair)
      final res = EntityParser.parseMarkdown('🚀 **rocket**');
      expect(res.cleanText, '🚀 rocket');
      // '🚀 ' length in UTF-16 is 2 + 1 = 3
      expect(res.entities.first.offset, 3);
      expect(res.entities.first.length, 'rocket'.length);
    });
  });

  group('EntityParser toMarkdown', () {
    test('reconstructs markdown from plain text and entities', () {
      const text = 'Hello world spoiler';
      const entities = [
        MessageEntity(type: 'bold', offset: 0, length: 5),
        MessageEntity(type: 'spoiler', offset: 12, length: 7),
      ];

      final md = EntityParser.toMarkdown(text, entities);
      expect(md, '**Hello** world ||spoiler||');
    });

    test('reconstructs links and quotes', () {
      const text = 'Quote text';
      const entities = [
        MessageEntity(type: 'blockquote', offset: 0, length: 10, collapsed: true),
      ];

      final md = EntityParser.toMarkdown(text, entities);
      expect(md, '**> Quote text');
    });
  });

  group('EntityParser URL Extraction', () {
    test('extracts multiple URLs', () {
      final urls = EntityParser.extractUrls(
        'Go to https://flutter.dev and http://dart.dev now',
      );
      expect(urls, ['https://flutter.dev', 'http://dart.dev']);
    });

    test('strips trailing parenthesis from markdown links and text', () {
      final urls = EntityParser.extractUrls(
        'Visit [Google](https://google.com) or (https://example.com)',
      );
      expect(urls, contains('https://google.com'));
      expect(urls, contains('https://example.com'));
      for (final u in urls) {
        expect(u.endsWith(')'), isFalse);
      }
    });

    test('cleanUrl strips trailing punctuation but preserves balanced parentheses', () {
      expect(EntityParser.cleanUrl('https://example.com)'), 'https://example.com');
      expect(EntityParser.cleanUrl('https://example.com.'), 'https://example.com');
      expect(EntityParser.cleanUrl('https://example.com,'), 'https://example.com');
      expect(
        EntityParser.cleanUrl('https://en.wikipedia.org/wiki/Dart_(programming_language)'),
        'https://en.wikipedia.org/wiki/Dart_(programming_language)',
      );
    });
  });

  group('EntityParser applyFormatting', () {
    test('wraps selected text with bold markdown', () {
      final controller = TextEditingController(text: 'Hello world');
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);

      EntityParser.applyFormatting(controller: controller, formatType: 'bold');
      expect(controller.text, 'Hello **world**');
    });

    test('inserts spoiler markers when nothing is selected', () {
      final controller = TextEditingController(text: 'Hello');
      controller.selection = const TextSelection.collapsed(offset: 5);

      EntityParser.applyFormatting(controller: controller, formatType: 'spoiler');
      expect(controller.text, 'Hello||||');
      expect(controller.selection.baseOffset, 7);
    });
  });

  group('RichTextEditingController Delimiter-Free Formatting', () {
    test('formats selection without inserting raw delimiter characters', () {
      final ctrl = RichTextEditingController(text: 'Hello secret world');
      ctrl.selection = const TextSelection(baseOffset: 6, extentOffset: 12); // 'secret'

      ctrl.applyFormat('spoiler');

      // Text remains clean! No || inserted!
      expect(ctrl.text, 'Hello secret world');
      expect(ctrl.cleanText, 'Hello secret world');
      expect(ctrl.entities.length, 1);
      expect(ctrl.entities.first.type, 'spoiler');
      expect(ctrl.entities.first.offset, 6);
      expect(ctrl.entities.first.length, 6);
    });

    test('toggles active format when nothing is selected and changes cursor mode', () {
      final ctrl = RichTextEditingController(text: 'Hello');
      ctrl.selection = const TextSelection.collapsed(offset: 5);

      // Tapping spoiler without selection toggles activeFormat, no characters inserted
      ctrl.applyFormat('spoiler');
      expect(ctrl.activeFormat, 'spoiler');
      expect(ctrl.text, 'Hello'); // No |||| added!

      // Typing with active format attaches spoiler entity
      ctrl.value = const TextEditingValue(
        text: 'Hello hidden',
        selection: TextSelection.collapsed(offset: 12),
      );

      expect(ctrl.cleanText, 'Hello hidden');
      expect(ctrl.entities.length, 1);
      expect(ctrl.entities.first.type, 'spoiler');
      expect(ctrl.entities.first.offset, 5);
      expect(ctrl.entities.first.length, 7);
    });

    test('isCursorItalic detects italic mode and cursor inside italic spans', () {
      final ctrl = RichTextEditingController(text: 'Hello italic world');
      expect(ctrl.isCursorItalic, isFalse);

      // Active format set to italic
      ctrl.activeFormat = 'italic';
      expect(ctrl.isCursorItalic, isTrue);

      ctrl.activeFormat = null;
      expect(ctrl.isCursorItalic, isFalse);

      // Format 'italic' on word 'italic' (offset 6 to 12)
      ctrl.selection = const TextSelection(baseOffset: 6, extentOffset: 12);
      ctrl.applyFormat('italic');

      // Cursor inside italic text (e.g. offset 8)
      ctrl.selection = const TextSelection.collapsed(offset: 8);
      expect(ctrl.isCursorItalic, isTrue);

      // Cursor outside italic text (e.g. offset 2)
      ctrl.selection = const TextSelection.collapsed(offset: 2);
      expect(ctrl.isCursorItalic, isFalse);
    });
  });
}
