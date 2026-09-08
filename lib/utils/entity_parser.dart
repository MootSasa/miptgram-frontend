import 'package:flutter/widgets.dart';
import '../services/chat_service.dart';

/// Result of parsing markdown text into clean text with message entities.
class ParsedMessage {
  final String cleanText;
  final List<MessageEntity> entities;

  const ParsedMessage({
    required this.cleanText,
    required this.entities,
  });
}

/// Helper representing an unshifted entity during parsing
class _RawEntity {
  final String type;
  int offset;
  int length;
  final String? url;
  final String? language;
  final bool? collapsed;

  _RawEntity({
    required this.type,
    required this.offset,
    required this.length,
    this.url,
    this.language,
    this.collapsed,
  });

  MessageEntity toMessageEntity() => MessageEntity(
        type: type,
        offset: offset,
        length: length,
        url: url,
        language: language,
        collapsed: collapsed,
      );
}

/// Utility for parsing Markdown into Telegram-style [MessageEntity] lists and vice versa.
///
/// Ensures offsets and lengths are computed precisely in UTF-16 code units,
/// compatible with Dart strings, emoji surrogate pairs, and the Telegram Bot API standard.
class EntityParser {
  static final RegExp _urlRegex = RegExp(
    r'https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
  );

  /// Strip trailing punctuation and unbalanced closing parentheses from a URL.
  static String cleanUrl(String url) {
    var cleaned = url.trim();
    while (cleaned.isNotEmpty) {
      final lastChar = cleaned[cleaned.length - 1];
      if (lastChar == ')') {
        final openCount = '('.allMatches(cleaned).length;
        final closeCount = ')'.allMatches(cleaned).length;
        if (closeCount > openCount) {
          cleaned = cleaned.substring(0, cleaned.length - 1);
          continue;
        }
      } else if (lastChar == '.' ||
          lastChar == ',' ||
          lastChar == '!' ||
          lastChar == '?' ||
          lastChar == ';' ||
          lastChar == ':' ||
          lastChar == '>') {
        cleaned = cleaned.substring(0, cleaned.length - 1);
        continue;
      }
      break;
    }
    return cleaned;
  }

  /// Extract all URLs found in the text.
  static List<String> extractUrls(String text) {
    final urls = <String>[];

    // 1. Explicit markdown links: [label](url)
    final mdLinkRegex = RegExp(r'\[(?:[^\]]*)\]\((https?:\/\/[^\s\)]+)\)');
    for (final match in mdLinkRegex.allMatches(text)) {
      final u = cleanUrl(match.group(1)!);
      if (u.isNotEmpty && !urls.contains(u)) {
        urls.add(u);
      }
    }

    // 2. Plain URLs
    for (final match in _urlRegex.allMatches(text)) {
      final u = cleanUrl(match.group(0)!);
      if (u.isNotEmpty && !urls.contains(u)) {
        urls.add(u);
      }
    }

    return urls;
  }

  /// Parses markdown tokens in [rawText] into clean plain text and a list of [MessageEntity].
  static ParsedMessage parseMarkdown(String rawText) {
    if (rawText.isEmpty) {
      return const ParsedMessage(cleanText: '', entities: []);
    }

    String currentText = rawText;
    final List<_RawEntity> entities = [];

    // 1. Code blocks: ```[language]\ncode\n```
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_-]*)\r?\n([\s\S]*?)```');
    while (true) {
      final match = codeBlockRegex.firstMatch(currentText);
      if (match == null) break;

      final fullMatch = match.group(0)!;
      final lang = match.group(1)?.trim();
      var codeContent = match.group(2) ?? '';
      if (codeContent.endsWith('\n')) {
        codeContent = codeContent.substring(0, codeContent.length - 1);
        if (codeContent.endsWith('\r')) {
          codeContent = codeContent.substring(0, codeContent.length - 1);
        }
      }
      final startIndex = match.start;

      currentText = currentText.replaceRange(
        startIndex,
        startIndex + fullMatch.length,
        codeContent,
      );

      _adjustEntities(entities, startIndex + fullMatch.length, codeContent.length - fullMatch.length);

      entities.add(_RawEntity(
        type: 'pre',
        offset: startIndex,
        length: codeContent.length,
        language: (lang != null && lang.isNotEmpty) ? lang : null,
      ));
    }

    // 2. Collapsible blockquote: lines starting with **>
    final collapsibleQuoteRegex = RegExp(r'(?:^|\n)\*\*>\s?([^\n]+(?:\n\*\*>\s?[^\n]+)*)');
    while (true) {
      final match = collapsibleQuoteRegex.firstMatch(currentText);
      if (match == null) break;

      final fullMatch = match.group(0)!;
      final quoteBodyRaw = match.group(1)!;

      final cleanedLines = quoteBodyRaw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^\*\*>\s?'), ''))
          .join('\n');

      final leadingNewline = fullMatch.startsWith('\n') ? 1 : 0;
      final startIndex = match.start + leadingNewline;
      final replaceEnd = match.start + fullMatch.length;

      currentText = currentText.replaceRange(startIndex, replaceEnd, cleanedLines);
      _adjustEntities(entities, replaceEnd, cleanedLines.length - (replaceEnd - startIndex));

      entities.add(_RawEntity(
        type: 'blockquote',
        offset: startIndex,
        length: cleanedLines.length,
        collapsed: true,
      ));
    }

    // 3. Regular blockquote: lines starting with >
    final blockquoteRegex = RegExp(r'(?:^|\n)>\s?([^\n]+(?:\n>\s?[^\n]+)*)');
    while (true) {
      final match = blockquoteRegex.firstMatch(currentText);
      if (match == null) break;

      final fullMatch = match.group(0)!;
      final quoteBodyRaw = match.group(1)!;

      final cleanedLines = quoteBodyRaw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^>\s?'), ''))
          .join('\n');

      final leadingNewline = fullMatch.startsWith('\n') ? 1 : 0;
      final startIndex = match.start + leadingNewline;
      final replaceEnd = match.start + fullMatch.length;

      currentText = currentText.replaceRange(startIndex, replaceEnd, cleanedLines);
      _adjustEntities(entities, replaceEnd, cleanedLines.length - (replaceEnd - startIndex));

      entities.add(_RawEntity(
        type: 'blockquote',
        offset: startIndex,
        length: cleanedLines.length,
        collapsed: false,
      ));
    }

    // 4. Links: [label](url)
    final linkRegex = RegExp(r'\[([^\]]+)\]\((https?:\/\/[^\s\)]+)\)');
    while (true) {
      final match = linkRegex.firstMatch(currentText);
      if (match == null) break;

      final fullMatch = match.group(0)!;
      final label = match.group(1)!;
      final url = match.group(2)!;
      final startIndex = match.start;

      currentText = currentText.replaceRange(
        startIndex,
        startIndex + fullMatch.length,
        label,
      );

      _adjustEntities(entities, startIndex + fullMatch.length, label.length - fullMatch.length);

      entities.add(_RawEntity(
        type: 'text_link',
        offset: startIndex,
        length: label.length,
        url: url,
      ));
    }

    // 5. Spoilers: ||text||
    _parseInlineDelimiter(
      pattern: RegExp(r'\|\|([\s\S]+?)\|\|'),
      type: 'spoiler',
      textRef: () => currentText,
      onReplace: (newText) => currentText = newText,
      entities: entities,
    );

    // 6. Bold: **text**
    _parseInlineDelimiter(
      pattern: RegExp(r'\*\*([^\*]+?)\*\*'),
      type: 'bold',
      textRef: () => currentText,
      onReplace: (newText) => currentText = newText,
      entities: entities,
    );

    // 7. Strikethrough: ~~text~~
    _parseInlineDelimiter(
      pattern: RegExp(r'~~([^~]+?)~~'),
      type: 'strikethrough',
      textRef: () => currentText,
      onReplace: (newText) => currentText = newText,
      entities: entities,
    );

    // 8. Underline: __text__ or --text-- or <u>text</u>
    _parseInlineDelimiter(
      pattern: RegExp(r'(?:__|\-\-|<u>)([\s\S]+?)(?:__|\-\-|</u>)'),
      type: 'underline',
      textRef: () => currentText,
      onReplace: (newText) => currentText = newText,
      entities: entities,
    );

    // 9. Inline code: `text`
    _parseInlineDelimiter(
      pattern: RegExp(r'`([^`\n]+?)`'),
      type: 'code',
      textRef: () => currentText,
      onReplace: (newText) => currentText = newText,
      entities: entities,
    );

    // 10. Italic: *text* or _text_
    _parseInlineDelimiter(
      pattern: RegExp(r'(?:_|\*)([^\*_\n]+?)(?:_|\*)'),
      type: 'italic',
      textRef: () => currentText,
      onReplace: (newText) => currentText = newText,
      entities: entities,
    );

    // 11. Raw URLs in remaining clean text that are not yet covered by a text_link
    for (final match in _urlRegex.allMatches(currentText)) {
      final url = match.group(0)!;
      final start = match.start;
      final len = url.length;

      final bool alreadyCovered = entities.any((e) =>
          e.offset <= start && (e.offset + e.length) >= (start + len));

      if (!alreadyCovered) {
        entities.add(_RawEntity(
          type: 'url',
          offset: start,
          length: len,
          url: url,
        ));
      }
    }

    // Sort entities primarily by offset ascending, secondarily by length descending (outer first)
    entities.sort((a, b) {
      if (a.offset != b.offset) return a.offset.compareTo(b.offset);
      return b.length.compareTo(a.length);
    });

    return ParsedMessage(
      cleanText: currentText,
      entities: entities.map((e) => e.toMessageEntity()).toList(),
    );
  }

  static void _parseInlineDelimiter({
    required RegExp pattern,
    required String type,
    required String Function() textRef,
    required void Function(String) onReplace,
    required List<_RawEntity> entities,
  }) {
    while (true) {
      final text = textRef();
      final match = pattern.firstMatch(text);
      if (match == null) break;

      final fullMatch = match.group(0)!;
      final innerContent = match.group(1)!;
      final startIndex = match.start;

      final newText = text.replaceRange(
        startIndex,
        startIndex + fullMatch.length,
        innerContent,
      );
      onReplace(newText);

      final diff = innerContent.length - fullMatch.length;
      _adjustEntities(entities, startIndex + fullMatch.length, diff);

      entities.add(_RawEntity(
        type: type,
        offset: startIndex,
        length: innerContent.length,
      ));
    }
  }

  static void _adjustEntities(List<_RawEntity> entities, int changePoint, int delta) {
    for (final entity in entities) {
      if (entity.offset >= changePoint) {
        entity.offset += delta;
      } else if (entity.offset + entity.length > changePoint) {
        entity.length += delta;
      }
    }
  }

  /// Converts clean text and a list of entities back to Markdown syntax.
  static String toMarkdown(String cleanText, List<MessageEntity> entities) {
    if (entities.isEmpty || cleanText.isEmpty) {
      return cleanText;
    }

    final sorted = List<MessageEntity>.from(entities)
      ..sort((a, b) {
        if (a.offset != b.offset) return b.offset.compareTo(a.offset);
        return a.length.compareTo(b.length);
      });

    String result = cleanText;

    for (final entity in sorted) {
      final start = entity.offset.clamp(0, result.length);
      final end = (entity.offset + entity.length).clamp(start, result.length);
      if (start >= end) continue;

      final substring = result.substring(start, end);
      String formatted;

      switch (entity.type) {
        case 'bold':
          formatted = '**$substring**';
          break;
        case 'italic':
          formatted = '*$substring*';
          break;
        case 'strikethrough':
          formatted = '~~$substring~~';
          break;
        case 'underline':
          formatted = '__${substring}__';
          break;
        case 'code':
          formatted = '`$substring`';
          break;
        case 'pre':
          final lang = entity.language ?? '';
          formatted = '```$lang\n$substring\n```';
          break;
        case 'spoiler':
          formatted = '||$substring||';
          break;
        case 'blockquote':
          if (entity.collapsed == true) {
            formatted = substring.split('\n').map((l) => '**> $l').join('\n');
          } else {
            formatted = substring.split('\n').map((l) => '> $l').join('\n');
          }
          break;
        case 'url':
          formatted = substring;
          break;
        case 'text_link':
        case 'link':
          final url = entity.url ?? substring;
          if (url == substring) {
            formatted = substring;
          } else {
            formatted = '[$substring]($url)';
          }
          break;
        default:
          formatted = substring;
      }

      result = result.replaceRange(start, end, formatted);
    }

    return result;
  }

  /// Applies formatting tokens around the user's current selection.
  static void applyFormatting({
    required TextEditingController controller,
    required String formatType,
    String? url,
    String? language,
  }) {
    final selection = controller.selection;
    final text = controller.text;
    final int start;
    final int end;
    final String selectedText;

    if (!selection.isValid) {
      start = text.length;
      end = text.length;
      selectedText = '';
    } else if (selection.isCollapsed) {
      start = selection.baseOffset.clamp(0, text.length);
      end = start;
      selectedText = '';
    } else {
      start = selection.start;
      end = selection.end;
      selectedText = text.substring(start, end);
    }

    String prefix = '';
    String suffix = '';

    switch (formatType) {
      case 'bold':
        prefix = '**';
        suffix = '**';
        break;
      case 'italic':
        prefix = '*';
        suffix = '*';
        break;
      case 'strikethrough':
        prefix = '~~';
        suffix = '~~';
        break;
      case 'underline':
        prefix = '__';
        suffix = '__';
        break;
      case 'code':
        prefix = '`';
        suffix = '`';
        break;
      case 'pre':
        final lang = language ?? '';
        prefix = '```$lang\n';
        suffix = '\n```';
        break;
      case 'spoiler':
        prefix = '||';
        suffix = '||';
        break;
      case 'quote':
        prefix = '> ';
        suffix = '';
        break;
      case 'collapse':
      case 'collapsible_quote':
        prefix = '**> ';
        suffix = '';
        break;
      case 'link':
        final targetUrl = url ?? 'https://';
        prefix = '[';
        suffix = ']($targetUrl)';
        break;
      case 'clear':
        if (selectedText.isEmpty) return;
        final cleaned = selectedText
            .replaceAll(RegExp(r'^\*\*|\*\*$'), '')
            .replaceAll(RegExp(r'^\*|\*$'), '')
            .replaceAll(RegExp(r'^`|`$'), '')
            .replaceAll(RegExp(r'^\|\||\|\|$'), '')
            .replaceAll(RegExp(r'^~~|~~$'), '')
            .replaceAll(RegExp(r'^__|^--|__$|--$'), '')
            .replaceAll(RegExp(r'^<u>|</u>$'), '')
            .replaceAll(RegExp(r'^\*\*>\s?'), '')
            .replaceAll(RegExp(r'^>\s?'), '');
        final newText = text.replaceRange(start, end, cleaned);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: start,
            extentOffset: start + cleaned.length,
          ),
        );
        return;
      default:
        return;
    }

    final formatted = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, formatted);
    final newSelectionStart = start + prefix.length;
    final newSelectionEnd = selectedText.isEmpty
        ? newSelectionStart
        : newSelectionStart + selectedText.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: newSelectionStart,
        extentOffset: newSelectionEnd,
      ),
    );
  }
}
