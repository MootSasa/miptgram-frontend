import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../utils/emoji_utils.dart';

// --- НАСТРОЙКИ СТИЛЯ ПОЛЯ ВВОДА ---
/// Радиус скругления контейнера поля ввода (в классическом и стеклянном режимах).
const double _kInputFillBorderRadius = 24.0;
/// Внешний горизонтальный отступ всего блока ввода от краев экрана.
const double _kInputHorizontalPadding = 12.0;
/// Внешний вертикальный отступ всего блока ввода от краев экрана.
const double _kInputVerticalPadding = 12.0;

/// Размер круглых кнопок действий (скрепка, микрофон/отправить).
const double _kActionButtonSize = 38.0;
/// Размер иконок внутри кнопок действий.
const double _kActionIconSize = 24.0;

/// Размер кнопки эмодзи.
const double _kEmojiButtonSize = 38.0;
/// Размер иконки эмодзи.
const double _kEmojiIconSize = 26.0;

/// Размер шрифта в поле ввода.
const double _kInputFontSize = 17.0;

/// Максимальная высота поля ввода до появления скролла.
const double _kInputMaxHeight = 250.0;
// ----------------------------------

/// Плавающее овальное поле ввода с Liquid Glass эффектом.
class LiquidGlassInputField extends StatefulWidget {
  final bool enabled;
  final bool isLite;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onEmoji;
  final VoidCallback? onVoice;
  final bool isSending;
  final IconData attachIcon;
  final bool hasAttachments;

  const LiquidGlassInputField({
    Key? key,
    required this.enabled,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.isLite = false,
    this.onChanged,
    this.onSend,
    this.onAttach,
    this.onEmoji,
    this.onVoice,
    this.isSending = false,
    this.attachIcon = Icons.attach_file,
    this.hasAttachments = false,
  }) : super(key: key);

  @override
  State<LiquidGlassInputField> createState() => _LiquidGlassInputFieldState();
}

class _LiquidGlassInputFieldState extends State<LiquidGlassInputField> {
  @override
  void initState() {
    super.initState();
    // Refresh text field when font loads
    EmojiUtils.isFontLoaded.addListener(_handleFontLoaded);
  }

  @override
  void dispose() {
    EmojiUtils.isFontLoaded.removeListener(_handleFontLoaded);
    super.dispose();
  }

  void _handleFontLoaded() {
    if (mounted) {
      // Trigger a rebuild of the controller's spans
      widget.controller.notifyListeners();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return _buildClassicInput(context);
    }
    return _buildGlassInput(context);
  }

  Widget _buildClassicInput(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final glassSettings = LiquidGlassSettings(
      blur: 15,
      refractiveIndex: 1.0,
      thickness: 10,
      glassColor: isDark
          ? Colors.black.withValues(alpha: 0.65)
          : Colors.white.withValues(alpha: 0.65),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInputHorizontalPadding, vertical: _kInputVerticalPadding),
      child: LiquidGlassLayer(
        settings: glassSettings,
        child: FakeGlass(
          settings: glassSettings,
          shape: const LiquidRoundedSuperellipse(borderRadius: _kInputFillBorderRadius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kInputFillBorderRadius),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
            ),
            child: _buildInputRow(context),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassInput(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final glassSettings = LiquidGlassSettings(
      refractiveIndex: 1.15,
      thickness: 20,
      blur: 8,
      saturation: 1.5,
      lightIntensity: isDark ? 0.7 : 1.0,
      ambientStrength: isDark ? 0.2 : 0.5,
      lightAngle: math.pi / 2,
      glassColor: isDark
          ? const Color.fromARGB(40, 30, 30, 40)
          : const Color.fromARGB(50, 255, 255, 255),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInputHorizontalPadding, vertical: _kInputVerticalPadding),
      child: widget.isLite
          ? FakeGlass(
              settings: glassSettings,
              shape: const LiquidRoundedSuperellipse(borderRadius: _kInputFillBorderRadius),
              child: GlassGlow(child: _buildInputRow(context)),
            )
          : LiquidGlass.withOwnLayer(
              settings: glassSettings,
              shape: const LiquidRoundedSuperellipse(borderRadius: _kInputFillBorderRadius),
              child: GlassGlow(child: _buildInputRow(context)),
            ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    final theme = Theme.of(context);
    const rightButtonBg = Color(0xFF0088CC);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6, top: 6),
          child: widget.onEmoji != null
              ? GestureDetector(
                  onTap: widget.onEmoji,
                  child: Container(
                    width: _kEmojiButtonSize,
                    height: _kEmojiButtonSize,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.emoji_emotions_outlined,
                      size: _kEmojiIconSize,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (widget.onEmoji != null) const SizedBox(width: 4),
        Expanded(
          child: _buildTextField(context),
        ),
        if (widget.onAttach != null) const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: widget.onAttach != null
              ? GestureDetector(
                  onTap: widget.onAttach,
                  child: Container(
                    width: _kActionButtonSize,
                    height: _kActionButtonSize,
                    alignment: Alignment.center,
                    child: Icon(
                      widget.hasAttachments ? Icons.add_circle : widget.attachIcon,
                      size: _kActionIconSize,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 2),
        Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: _buildSendButton(rightButtonBg),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: _kInputMaxHeight,
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            reverse: true, // Всегда показывать последнюю строку
            child: ValueListenableBuilder<bool>(
              valueListenable: EmojiUtils.isFontLoaded,
              builder: (context, isLoaded, child) {
                return TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  contextMenuBuilder: (context, editableTextState) {
                    final List<ContextMenuButtonItem> buttonItems =
                        editableTextState.contextMenuButtonItems;

                    if (!editableTextState
                        .textEditingValue.selection.isCollapsed) {
                      buttonItems.addAll([
                        ContextMenuButtonItem(
                          label: 'B (Жирный)',
                          onPressed: () {
                            TextFormattingUtils.applyFormatting(
                                widget.controller, 'bold');
                            editableTextState.hideToolbar();
                          },
                        ),
                        ContextMenuButtonItem(
                          label: 'I (Курсив)',
                          onPressed: () {
                            TextFormattingUtils.applyFormatting(
                                widget.controller, 'italic');
                            editableTextState.hideToolbar();
                          },
                        ),
                        ContextMenuButtonItem(
                          label: 'Mono (Код)',
                          onPressed: () {
                            TextFormattingUtils.applyFormatting(
                                widget.controller, 'code');
                            editableTextState.hideToolbar();
                          },
                        ),
                        ContextMenuButtonItem(
                          label: 'Спойлер',
                          onPressed: () {
                            TextFormattingUtils.applyFormatting(
                                widget.controller, 'spoiler');
                            editableTextState.hideToolbar();
                          },
                        ),
                        ContextMenuButtonItem(
                          label: 'Зачёркнутый',
                          onPressed: () {
                            TextFormattingUtils.applyFormatting(
                                widget.controller, 'strikethrough');
                            editableTextState.hideToolbar();
                          },
                        ),
                        ContextMenuButtonItem(
                          label: 'Ссылка',
                          onPressed: () {
                            TextFormattingUtils.applyFormatting(
                                widget.controller, 'link');
                            editableTextState.hideToolbar();
                          },
                        ),
                        ContextMenuButtonItem(
                          label: 'Цитата',
                          onPressed: () {
                            TextFormattingUtils.applyFormatting(
                                widget.controller, 'quote');
                            editableTextState.hideToolbar();
                          },
                        ),
                        ContextMenuButtonItem(
                          label: 'Сброс стиля',
                          onPressed: () {
                            TextFormattingUtils.applyFormatting(
                                widget.controller, 'clear');
                            editableTextState.hideToolbar();
                          },
                        ),
                      ]);
                    }

                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: buttonItems,
                    );
                  },
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: _kInputFontSize,
                    height: 1.2,
                  ),
                  onChanged: (text) {
                    widget.onChanged?.call(text);
                  },
                  textAlignVertical: TextAlignVertical.center,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(Color rightButtonBg) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final hasText = value.text.isNotEmpty;
        return FakeGlass.inLayer(
          shape: const LiquidOval(),
          child: GestureDetector(
            onTap: widget.isSending ? null : (hasText ? widget.onSend : widget.onVoice),
            child: Container(
              width: _kActionButtonSize,
              height: _kActionButtonSize,
              decoration: BoxDecoration(color: widget.isSending ? Colors.grey : rightButtonBg),
              alignment: Alignment.center,
              child: widget.isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(hasText ? Icons.send : Icons.mic, size: 22, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

/// Утилиты форматирования выделенного текста для контекстного меню
class TextFormattingUtils {
  static void applyFormatting(TextEditingController controller, String type,
      {String? url}) {
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = controller.text;
    final start = selection.start;
    final end = selection.end;
    final selectedText = text.substring(start, end);

    String prefix = '';
    String suffix = '';

    switch (type) {
      case 'bold':
        prefix = '**';
        suffix = '**';
        break;
      case 'italic':
        prefix = '*';
        suffix = '*';
        break;
      case 'code':
        prefix = '`';
        suffix = '`';
        break;
      case 'spoiler':
        prefix = '||';
        suffix = '||';
        break;
      case 'strikethrough':
        prefix = '~~';
        suffix = '~~';
        break;
      case 'underline':
        prefix = '<u>';
        suffix = '</u>';
        break;
      case 'quote':
        prefix = '> ';
        suffix = '';
        break;
      case 'link':
        final linkUrl = url ?? 'https://';
        prefix = '[';
        suffix = ']($linkUrl)';
        break;
      case 'clear':
        final cleaned = selectedText
            .replaceAll(RegExp(r'^\*\*|\*\*$'), '')
            .replaceAll(RegExp(r'^\*|\*$'), '')
            .replaceAll(RegExp(r'^`|`$'), '')
            .replaceAll(RegExp(r'^\|\||\|\|$'), '')
            .replaceAll(RegExp(r'^~~|~~$'), '')
            .replaceAll(RegExp(r'^<u>|</u>$'), '')
            .replaceAll(RegExp(r'^> '), '');
        final newText = text.replaceRange(start, end, cleaned);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: start,
            extentOffset: start + cleaned.length,
          ),
        );
        return;
    }

    final formatted = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, formatted);
    final newSelectionStart = start + prefix.length;
    final newSelectionEnd = newSelectionStart + selectedText.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: newSelectionStart,
        extentOffset: newSelectionEnd,
      ),
    );
  }
}

/// Фильтр для ввода (заглушка)
class _EmDashFilter extends TextInputFormatter {
  const _EmDashFilter();
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue;
}

/// Контроллер с подсветкой Markdown, Spoiler и Apple Emoji
class MarkdownTextEditingController extends TextEditingController {
  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final text = this.text;
    final isFontLoaded = EmojiUtils.isFontLoaded.value;

    if (!value.isComposingRangeValid || !withComposing) {
      if (isFontLoaded && EmojiUtils.emojiRegex.hasMatch(text)) {
        return _buildEmojiSpan(text, style);
      }
      return TextSpan(text: text, style: style);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markerStyle =
        TextStyle(color: isDark ? Colors.white24 : Colors.black26);
    final List<InlineSpan> children = [];

    final pattern = RegExp(
      r'(```[\s\S]*?(?:```|$))|' // 1: Code block
      r'(\$\$[\s\S]*?(?:\$\$|$))|' // 2: Math block
      r'(\*\*[\s\S]*?(?:\*\*|$))|' // 3: Bold **
      r'(__[\s\S]*?(?:__|$))|' // 4: Bold __
      r'(\*[\s\S]*?(?:\*|$))|' // 5: Italic *
      r'(_[\s\S]*?(?:_|$))|' // 6: Italic _
      r'(~~[\s\S]*?(?:~~|$))|' // 7: Strikethrough
      r'(`[\s\S]*?(?:`|$))|' // 8: Inline code
      r'(\|\|[\s\S]*?(?:\|\||$))|' // 9: Spoiler ||
      r'(\[\ \] |\[x\] )|' // 10: Checkbox
      r'((?:\u00a9|\u00ae|[\u2600-\u27bf]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff]))', // 11: EMOJI
      multiLine: true,
      unicode: false,
    );

    int lastIndex = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        children.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      final matchText = match.group(0)!;

      if (match.group(1) != null) {
        _addCode(children, matchText, '```', markerStyle);
      } else if (match.group(3) != null || match.group(4) != null) {
        _addStyled(children, matchText, match.group(3) != null ? '**' : '__',
            const TextStyle(fontWeight: FontWeight.bold), markerStyle);
      } else if (match.group(5) != null || match.group(6) != null) {
        _addStyled(children, matchText, match.group(5) != null ? '*' : '_',
            const TextStyle(fontStyle: FontStyle.italic), markerStyle);
      } else if (match.group(7) != null) {
        _addStyled(
            children,
            matchText,
            '~~',
            const TextStyle(decoration: TextDecoration.lineThrough),
            markerStyle);
      } else if (match.group(8) != null) {
        _addStyled(
            children,
            matchText,
            '`',
            const TextStyle(
                fontFamily: 'monospace', backgroundColor: Colors.black12),
            markerStyle);
      } else if (match.group(9) != null) {
        _addStyled(
            children,
            matchText,
            '||',
            TextStyle(
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                color: isDark ? Colors.white70 : Colors.black87),
            markerStyle);
      } else if (match.group(11) != null && isFontLoaded) {
        children.add(TextSpan(
          text: matchText,
          style: style?.copyWith(
            fontFamily: 'AppleEmoji',
            fontSize: (style.fontSize ?? _kInputFontSize),
          ),
        ));
      } else {
        children.add(TextSpan(text: matchText));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      children.add(TextSpan(text: text.substring(lastIndex)));
    }
    return TextSpan(style: style, children: children);
  }

  TextSpan _buildEmojiSpan(String text, TextStyle? style) {
    final List<InlineSpan> children = [];
    text.splitMapJoin(
      EmojiUtils.emojiRegex,
      onMatch: (match) {
        children.add(TextSpan(
          text: match.group(0),
          style: style?.copyWith(
            fontFamily: 'AppleEmoji',
            fontSize: (style.fontSize ?? _kInputFontSize),
          ),
        ));
        return '';
      },
      onNonMatch: (nonMatch) {
        children.add(TextSpan(text: nonMatch));
        return '';
      },
    );
    return TextSpan(style: style, children: children);
  }

  void _addStyled(List<InlineSpan> children, String match, String marker,
      TextStyle style, TextStyle mStyle) {
    if (match.length < marker.length) {
      children.add(TextSpan(text: match));
      return;
    }
    children.add(TextSpan(text: marker, style: mStyle));
    final hasEnd = match.endsWith(marker) && match.length >= marker.length * 2;
    final content = match.substring(
        marker.length, match.length - (hasEnd ? marker.length : 0));
    children.add(TextSpan(text: content, style: style));
    if (hasEnd) children.add(TextSpan(text: marker, style: mStyle));
  }

  void _addCode(List<InlineSpan> children, String match, String marker,
      TextStyle mStyle) {
    if (match.length < marker.length) {
      children.add(TextSpan(text: match));
      return;
    }
    children.add(TextSpan(text: marker, style: mStyle));
    final hasEnd = match.endsWith(marker) && match.length >= marker.length * 2;
    final content = match.substring(
        marker.length, match.length - (hasEnd ? marker.length : 0));
    children.add(TextSpan(
        text: content,
        style: const TextStyle(
            fontFamily: 'monospace', backgroundColor: Colors.black12)));
    if (hasEnd) children.add(TextSpan(text: marker, style: mStyle));
  }
}
