import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/entity_parser.dart';

/// Span representing rich text formatting without markdown delimiters.
class RichSpan {
  int start;
  int end;
  final String type; // bold, italic, strikethrough, underline, code, spoiler, blockquote, collapse, text_link
  final String? url;
  final String? language;

  RichSpan({
    required this.start,
    required this.end,
    required this.type,
    this.url,
    this.language,
  });

  RichSpan copyWith({int? start, int? end}) => RichSpan(
        start: start ?? this.start,
        end: end ?? this.end,
        type: type,
        url: url,
        language: language,
      );

  MessageEntity toMessageEntity() => MessageEntity(
        type: (type == 'collapse' || type == 'quote')
            ? 'blockquote'
            : (type == 'link' ? 'text_link' : type),
        offset: start,
        length: end - start,
        url: url,
        language: language,
        collapsed: type == 'collapse' ? true : (type == 'blockquote' || type == 'quote' ? false : null),
      );
}

/// Rich text editing controller that formats text in-place without inserting raw markdown characters.
///
/// Supports:
/// - Selecting text and applying formatting directly.
/// - Toggling active formatting when no text is selected (changing cursor appearance).
/// - Dynamic cursor appearance based on [activeFormat].
/// - Exporting clean text and entities for sending.
class RichTextEditingController extends TextEditingController {
  final List<RichSpan> _spans = [];
  String? _activeFormat;
  String _lastText = '';

  /// Returns unmodifiable list of rich text spans.
  List<RichSpan> get spans => List.unmodifiable(_spans);

  RichTextEditingController({String? text, List<MessageEntity>? initialEntities})
      : super(text: text ?? '') {
    _lastText = this.text;
    if (initialEntities != null && initialEntities.isNotEmpty) {
      for (final e in initialEntities) {
        _spans.add(RichSpan(
          start: e.offset,
          end: e.offset + e.length,
          type: e.type == 'blockquote' && e.collapsed == true ? 'collapse' : e.type,
          url: e.url,
          language: e.language,
        ));
      }
    }
  }

  /// Loads message content and its entities for editing in-place without markdown delimiters.
  void loadMessage(String content, [List<MessageEntity>? initialEntities]) {
    _spans.clear();
    _activeFormat = null;

    if (initialEntities != null && initialEntities.isNotEmpty) {
      value = TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
      );
      for (final e in initialEntities) {
        final start = e.offset.clamp(0, content.length);
        final end = (e.offset + e.length).clamp(start, content.length);
        if (start < end) {
          _spans.add(RichSpan(
            start: start,
            end: end,
            type: e.type == 'blockquote' && e.collapsed == true
                ? 'collapse'
                : (e.type == 'link' ? 'text_link' : e.type),
            url: e.url,
            language: e.language,
          ));
        }
      }
      _mergeSpans();
    } else {
      final parsed = EntityParser.parseMarkdown(content);
      if (parsed.entities.isNotEmpty) {
        value = TextEditingValue(
          text: parsed.cleanText,
          selection: TextSelection.collapsed(offset: parsed.cleanText.length),
        );
        for (final e in parsed.entities) {
          final start = e.offset.clamp(0, parsed.cleanText.length);
          final end = (e.offset + e.length).clamp(start, parsed.cleanText.length);
          if (start < end) {
            _spans.add(RichSpan(
              start: start,
              end: end,
              type: e.type == 'blockquote' && e.collapsed == true
                  ? 'collapse'
                  : (e.type == 'link' ? 'text_link' : e.type),
              url: e.url,
              language: e.language,
            ));
          }
        }
        _mergeSpans();
      } else {
        value = TextEditingValue(
          text: content,
          selection: TextSelection.collapsed(offset: content.length),
        );
      }
    }

    _lastText = text;
    notifyListeners();
  }

  /// Finds any link span covering [offset].
  RichSpan? getLinkSpanAt(int offset) {
    for (final s in _spans) {
      if ((s.type == 'text_link' || s.type == 'link') &&
          s.start <= offset &&
          s.end >= offset) {
        return s;
      }
    }
    return null;
  }

  /// Finds any link span intersecting [selection].
  RichSpan? getLinkSpanForSelection(TextSelection selection) {
    if (!selection.isValid) return null;
    final start = math.min(selection.start, selection.end);
    final end = math.max(selection.start, selection.end);
    if (start == end) {
      return getLinkSpanAt(start);
    }
    for (final s in _spans) {
      if ((s.type == 'text_link' || s.type == 'link') &&
          (s.start < end && s.end > start)) {
        return s;
      }
    }
    return null;
  }

  /// Applies or updates a link on the given range or current selection.
  void applyLinkToSelection(String url,
      {int? start, int? end, String? replacementText}) {
    int s = start ??
        (selection.isValid ? math.min(selection.start, selection.end) : 0);
    int e = end ??
        (selection.isValid ? math.max(selection.start, selection.end) : 0);

    if (replacementText != null) {
      final oldText = text;
      final newText = oldText.replaceRange(s, e, replacementText);
      e = s + replacementText.length;
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: e),
      );
    }

    if (s >= e) return;

    // Remove any overlapping link spans
    _spans.removeWhere((span) =>
        (span.type == 'text_link' || span.type == 'link') &&
        (span.start < e && span.end > s));

    _spans.add(RichSpan(
      start: s,
      end: e,
      type: 'text_link',
      url: EntityParser.normalizeUrl(url),
    ));

    _mergeSpans();
    notifyListeners();
  }

  /// Removes link formatting covering the selection or range, preserving text.
  void removeLinkFromSelection({int? start, int? end}) {
    int s = start ??
        (selection.isValid ? math.min(selection.start, selection.end) : 0);
    int e = end ??
        (selection.isValid ? math.max(selection.start, selection.end) : 0);

    if (s == e && selection.isValid) {
      final link = getLinkSpanAt(s);
      if (link != null) {
        s = link.start;
        e = link.end;
      }
    }

    if (s >= e) return;

    _spans.removeWhere((span) =>
        (span.type == 'text_link' || span.type == 'link') &&
        (span.start < e && span.end > s));

    _mergeSpans();
    notifyListeners();
  }

  /// Clears rich formatting on the current selection.
  void clearFormatting() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final start = math.min(sel.start, sel.end);
    final end = math.max(sel.start, sel.end);
    for (int i = _spans.length - 1; i >= 0; i--) {
      final s = _spans[i];
      if (s.start < end && s.end > start) {
        _spans.removeAt(i);
        if (s.start < start) {
          _spans.add(s.copyWith(end: start));
        }
        if (s.end > end) {
          _spans.add(s.copyWith(start: end));
        }
      }
    }
    _mergeSpans();
    notifyListeners();
  }

  /// Currently active format mode for newly typed characters (e.g. 'bold', 'spoiler', 'code').
  String? get activeFormat => _activeFormat;

  set activeFormat(String? format) {
    if (_activeFormat != format) {
      _activeFormat = format;
      notifyListeners();
    }
  }

  /// Returns true if the cursor should be displayed in italic (slanted) style.
  /// This is true if [activeFormat] is 'italic', or if the collapsed selection
  /// is positioned within an italic span.
  bool get isCursorItalic {
    if (_activeFormat == 'italic') return true;
    if (!selection.isValid || !selection.isCollapsed) return false;
    final offset = selection.baseOffset;
    if (offset < 0) return false;
    return _spans.any((s) => s.type == 'italic' && s.start <= offset && s.end >= offset);
  }

  /// Toggles the active format mode when cursor is collapsed, or applies to selection.
  void toggleActiveFormat(String format) {
    if (_activeFormat == format) {
      _activeFormat = null;
    } else {
      _activeFormat = format;
    }
    notifyListeners();
  }

  /// Applies formatting to selection or toggles active format.
  void applyFormat(String formatType, {String? url, String? language}) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) {
      // No selection: toggle active format for cursor!
      toggleActiveFormat(formatType);
      return;
    }

    final start = math.min(sel.start, sel.end);
    final end = math.max(sel.start, sel.end);
    if (start == end) return;

    final normalizedType = (formatType == 'link')
        ? 'text_link'
        : (formatType == 'quote' ? 'blockquote' : formatType);
    if (normalizedType == 'text_link' && url != null) {
      applyLinkToSelection(url, start: start, end: end);
      return;
    }

    // Check if entire selection already has this format: toggle it off
    final existingIndex = _spans.indexWhere(
      (s) =>
          (s.type == normalizedType ||
              (normalizedType == 'text_link' && s.type == 'link')) &&
          s.start <= start &&
          s.end >= end,
    );

    if (existingIndex != -1) {
      // Remove or split the span
      final span = _spans[existingIndex];
      _spans.removeAt(existingIndex);
      if (span.start < start) {
        _spans.add(span.copyWith(end: start));
      }
      if (span.end > end) {
        _spans.add(span.copyWith(start: end));
      }
    } else {
      // Add formatting span
      _spans.add(RichSpan(
        start: start,
        end: end,
        type: normalizedType,
        url: url,
        language: language,
      ));
      _mergeSpans();
    }

    notifyListeners();
  }

  /// Returns clean plain text without any markdown delimiters.
  String get cleanText {
    if (_spans.isEmpty) {
      return EntityParser.parseMarkdown(text).cleanText;
    }
    return text;
  }

  /// Converts the current text and formatting entities into a markdown formatted string.
  String toMarkdown() => EntityParser.toMarkdown(cleanText, entities);

  /// Returns computed message entities matching the styled spans, plus any raw URLs.
  List<MessageEntity> get entities {
    List<MessageEntity> result = [];
    final effectiveText = cleanText;
    if (_spans.isEmpty) {
      // If user typed markdown tokens manually, fallback to parseMarkdown
      final parsed = EntityParser.parseMarkdown(text);
      result = List.from(parsed.entities);
    } else {
      result = _spans
          .where((s) => s.start < s.end && s.start < text.length)
          .map((s) => s
              .copyWith(end: math.min(s.end, text.length))
              .toMessageEntity())
          .toList();
    }

    // Also detect any raw URLs in text not covered by existing entities
    for (final match in EntityParser.urlRegex.allMatches(effectiveText)) {
      final url = match.group(0)!;
      final start = match.start;
      final len = url.length;
      final bool covered = result.any((e) =>
          e.offset <= start && (e.offset + e.length) >= (start + len));
      if (!covered) {
        result.add(MessageEntity(
          type: 'url',
          offset: start,
          length: len,
          url: url,
        ));
      }
    }

    result.sort((a, b) => a.offset.compareTo(b.offset));
    return result;
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = _lastText;
    final newText = newValue.text;

    if (oldText != newText) {
      _updateSpansForTextChange(oldText, newText);
      _lastText = newText;
    }

    super.value = newValue;
  }

  void _updateSpansForTextChange(String oldText, String newText) {
    int start = 0;
    while (start < oldText.length && start < newText.length && oldText[start] == newText[start]) {
      start++;
    }

    int oldEnd = oldText.length;
    int newEnd = newText.length;
    while (oldEnd > start && newEnd > start && oldText[oldEnd - 1] == newText[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }

    final int deletedCount = oldEnd - start;
    final int insertedCount = newEnd - start;
    final int delta = insertedCount - deletedCount;

    // Adjust existing spans
    for (int i = _spans.length - 1; i >= 0; i--) {
      final span = _spans[i];

      if (span.end <= start) {
        // Change occurred after span: unchanged
        continue;
      } else if (span.start >= oldEnd) {
        // Change occurred before span: shift
        span.start += delta;
        span.end += delta;
      } else {
        // Change overlaps with span
        if (deletedCount > 0) {
          final delInSpan = (math.min(span.end, oldEnd) - math.max(span.start, start)).toInt();
          span.end -= delInSpan;
        }
        if (insertedCount > 0 && span.start <= start && span.end >= start) {
          span.end += insertedCount;
        }
      }

      if (span.start >= span.end || span.start >= newText.length) {
        _spans.removeAt(i);
      }
    }

    // If new text was typed and activeFormat is set, apply activeFormat to the inserted range
    if (insertedCount > 0 && _activeFormat != null) {
      _spans.add(RichSpan(
        start: start,
        end: start + insertedCount,
        type: _activeFormat!,
      ));
      _mergeSpans();
    }

    // Clamp spans within [0, newText.length]
    for (final span in _spans) {
      span.start = span.start.clamp(0, newText.length);
      span.end = span.end.clamp(span.start, newText.length);
    }
    _spans.removeWhere((s) => s.start >= s.end);
  }

  void _mergeSpans() {
    _spans.sort((a, b) {
      if (a.start != b.start) return a.start.compareTo(b.start);
      return a.end.compareTo(b.end);
    });

    for (int i = 0; i < _spans.length - 1; i++) {
      final cur = _spans[i];
      final next = _spans[i + 1];
      if (cur.type == next.type && cur.url == next.url && cur.end >= next.start) {
        cur.end = math.max(cur.end, next.end);
        _spans.removeAt(i + 1);
        i--;
      }
    }
  }

  @override
  void clear() {
    _spans.clear();
    _activeFormat = null;
    _lastText = '';
    super.clear();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Collect all boundary points
    final points = <int>{0, text.length};
    for (final s in _spans) {
      if (s.start >= 0 && s.start <= text.length) points.add(s.start);
      if (s.end >= 0 && s.end <= text.length) points.add(s.end);
    }

    final sortedPoints = points.toList()..sort();
    final children = <InlineSpan>[];

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final segStart = sortedPoints[i];
      final segEnd = sortedPoints[i + 1];
      if (segStart >= segEnd) continue;

      final segText = text.substring(segStart, segEnd);

      // Find all spans covering this segment
      final activeSpans = _spans.where((s) => s.start <= segStart && s.end >= segEnd).toList();

      TextStyle segStyle = style ?? const TextStyle(fontSize: 17.0);

      // 1. Combine decorations
      final hasStrike = activeSpans.any((s) => s.type == 'strikethrough');
      final hasUnderline = activeSpans.any((s) =>
          s.type == 'underline' || s.type == 'text_link' || s.type == 'link');
      if (hasStrike && hasUnderline) {
        segStyle = segStyle.copyWith(
          decoration: TextDecoration.combine(
              [TextDecoration.lineThrough, TextDecoration.underline]),
          decorationColor: segStyle.color,
          decorationThickness: 1.5,
        );
      } else if (hasStrike) {
        segStyle = segStyle.copyWith(decoration: TextDecoration.lineThrough);
      } else if (hasUnderline) {
        segStyle = segStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: segStyle.color,
          decorationThickness: 1.5,
        );
      }

      // 2. Bold
      if (activeSpans.any((s) => s.type == 'bold')) {
        segStyle = segStyle.copyWith(fontWeight: FontWeight.bold);
      }

      // 3. Italic
      if (activeSpans.any((s) =>
          s.type == 'italic' ||
          s.type == 'quote' ||
          s.type == 'collapse' ||
          s.type == 'blockquote')) {
        segStyle = segStyle.copyWith(fontStyle: FontStyle.italic);
      }

      // 4. Monospace
      if (activeSpans.any((s) => s.type == 'code' || s.type == 'pre')) {
        segStyle = segStyle.copyWith(fontFamily: 'monospace');
      }

      // 5. Links
      if (activeSpans.any((s) => s.type == 'text_link' || s.type == 'link')) {
        segStyle = segStyle.copyWith(color: primaryColor);
      }

      // 6. Blockquote
      if (activeSpans.any((s) =>
          s.type == 'quote' ||
          s.type == 'collapse' ||
          s.type == 'blockquote')) {
        segStyle = segStyle.copyWith(
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1C2530),
          backgroundColor:
              isDark ? const Color(0x18FFFFFF) : const Color(0x12000000),
        );
      }

      // 7. Spoiler text appearance
      if (activeSpans.any((s) => s.type == 'spoiler')) {
        segStyle = segStyle.copyWith(
          backgroundColor: Colors.transparent,
          color: isDark ? Colors.white38 : Colors.black38,
        );
      }

      // Check for emojis
      if (EmojiUtils.isFontLoaded.value && EmojiUtils.emojiRegex.hasMatch(segText)) {
        segText.splitMapJoin(
          EmojiUtils.emojiRegex,
          onMatch: (m) {
            children.add(TextSpan(
              text: m.group(0),
              style: segStyle.copyWith(
                fontFamily: 'AppleEmoji',
              ),
            ));
            return '';
          },
          onNonMatch: (nonMatch) {
            if (nonMatch.isNotEmpty) {
              children.add(TextSpan(text: nonMatch, style: segStyle));
            }
            return '';
          },
        );
      } else {
        children.add(TextSpan(text: segText, style: segStyle));
      }
    }

    return TextSpan(style: style, children: children);
  }
}

/// Backwards-compatible alias for [RichTextEditingController].
class MarkdownTextEditingController extends RichTextEditingController {
  MarkdownTextEditingController({String? text, List<MessageEntity>? initialEntities})
      : super(text: text, initialEntities: initialEntities);
}
