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
        type: type == 'collapse' ? 'blockquote' : (type == 'link' ? 'text_link' : type),
        offset: start,
        length: end - start,
        url: url,
        language: language,
        collapsed: type == 'collapse' ? true : (type == 'blockquote' ? false : null),
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

  /// Currently active format mode for newly typed characters (e.g. 'bold', 'spoiler', 'code').
  String? get activeFormat => _activeFormat;

  set activeFormat(String? format) {
    if (_activeFormat != format) {
      _activeFormat = format;
      notifyListeners();
    }
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

    // Check if entire selection already has this format: toggle it off
    final existingIndex = _spans.indexWhere(
      (s) => s.type == formatType && s.start <= start && s.end >= end,
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
        type: formatType,
        url: url,
        language: language,
      ));
      _mergeSpans();
    }

    notifyListeners();
  }

  /// Returns clean plain text without any markdown delimiters.
  String get cleanText => text;

  /// Returns computed message entities matching the styled spans.
  List<MessageEntity> get entities {
    if (_spans.isEmpty) {
      // If user typed markdown tokens manually, fallback to parseMarkdown
      final parsed = EntityParser.parseMarkdown(text);
      if (parsed.entities.isNotEmpty) {
        return parsed.entities;
      }
      return [];
    }

    return _spans
        .where((s) => s.start < s.end && s.start < text.length)
        .map((s) => s.copyWith(end: math.min(s.end, text.length)).toMessageEntity())
        .toList();
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

      for (final s in activeSpans) {
        switch (s.type) {
          case 'bold':
            segStyle = segStyle.copyWith(fontWeight: FontWeight.bold);
            break;
          case 'italic':
            segStyle = segStyle.copyWith(fontStyle: FontStyle.italic);
            break;
          case 'strikethrough':
            segStyle = segStyle.copyWith(decoration: TextDecoration.lineThrough);
            break;
          case 'underline':
            segStyle = segStyle.copyWith(decoration: TextDecoration.underline);
            break;
          case 'code':
            segStyle = segStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
            );
            break;
          case 'spoiler':
            segStyle = segStyle.copyWith(
              backgroundColor: isDark ? const Color(0xFF3B2D54) : const Color(0xFFE9D5FF),
              color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE),
            );
            break;
          case 'quote':
          case 'collapse':
            segStyle = segStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: primaryColor,
            );
            break;
          case 'text_link':
          case 'link':
            segStyle = segStyle.copyWith(
              color: primaryColor,
              decoration: TextDecoration.underline,
            );
            break;
        }
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
