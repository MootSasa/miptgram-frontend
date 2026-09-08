import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/entity_parser.dart';
import 'rich_text_editing_controller.dart';
export 'rich_text_editing_controller.dart';

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

class _LiquidGlassInputFieldState extends State<LiquidGlassInputField>
    with SingleTickerProviderStateMixin {
  final GlobalKey _fieldKey = GlobalKey();
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    if (widget.focusNode?.hasFocus == true) {
      _blinkController.repeat(reverse: true);
    }
    widget.controller.addListener(_onControllerChanged);
    widget.focusNode?.addListener(_onFocusChanged);
    // Refresh text field when font loads
    EmojiUtils.isFontLoaded.addListener(_handleFontLoaded);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      widget.focusNode?.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.focusNode?.removeListener(_onFocusChanged);
    _blinkController.dispose();
    EmojiUtils.isFontLoaded.removeListener(_handleFontLoaded);
    super.dispose();
  }

  void _onControllerChanged() {
    _blinkController.value = 1.0;
    if (widget.focusNode?.hasFocus == true && !_blinkController.isAnimating) {
      _blinkController.repeat(reverse: true);
    }
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (widget.focusNode?.hasFocus == true) {
      if (!_blinkController.isAnimating) {
        _blinkController.repeat(reverse: true);
      }
    } else {
      if (_blinkController.isAnimating) {
        _blinkController.stop();
      }
      _blinkController.value = 1.0;
    }
    if (mounted) setState(() {});
  }

  void _handleFontLoaded() {
    if (mounted) {
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
    final richCtrl = widget.controller is RichTextEditingController
        ? widget.controller as RichTextEditingController
        : null;
    final isItalic = richCtrl?.isCursorItalic ?? false;
    final isFocused = widget.focusNode?.hasFocus ?? false;
    final hasCollapsedSelection = widget.controller.selection.isValid &&
        widget.controller.selection.isCollapsed;
    final showItalicCursor = isItalic && isFocused && hasCollapsedSelection;

    final cursorColor = theme.colorScheme.primary;

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
                return CustomPaint(
                  foregroundPainter: showItalicCursor
                      ? ItalicCaretPainter(
                          fieldKey: _fieldKey,
                          controller: widget.controller,
                          color: cursorColor,
                          repaint: _blinkController,
                          opacityAnimation: _blinkController,
                        )
                      : null,
                  child: TextField(
                    key: _fieldKey,
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    cursorColor: showItalicCursor ? Colors.transparent : cursorColor,
                    cursorWidth: 2.0,
                    cursorRadius: const Radius.circular(1.0),
                    cursorOpacityAnimates: true,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    contextMenuBuilder: (context, editableTextState) {
                      if (!editableTextState.textEditingValue.selection.isCollapsed) {
                        return ScrollableTextSelectionToolbar(
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: editableTextState.contextMenuButtonItems,
                          controller: widget.controller,
                          onHideToolbar: editableTextState.hideToolbar,
                        );
                      }

                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: editableTextState.contextMenuButtonItems,
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
                  ),
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

/// Custom painter that draws a tilted (italic) caret matching the font slant.
class ItalicCaretPainter extends CustomPainter {
  final GlobalKey fieldKey;
  final TextEditingController controller;
  final Color color;
  final Animation<double> opacityAnimation;

  ItalicCaretPainter({
    required this.fieldKey,
    required this.controller,
    required this.color,
    required Listenable repaint,
    required this.opacityAnimation,
  }) : super(repaint: repaint);

  static RenderEditable? _findRenderEditable(RenderObject? root) {
    if (root == null) return null;
    if (root is RenderEditable) return root;
    RenderEditable? found;
    root.visitChildren((child) {
      if (found != null) return;
      found = _findRenderEditable(child);
    });
    return found;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = opacityAnimation.value;
    if (opacity <= 0.05) return;

    final renderBox = fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final renderEditable = _findRenderEditable(renderBox);
    if (renderEditable == null) return;

    final sel = controller.selection;
    if (!sel.isValid || !sel.isCollapsed) return;

    final rawRect = renderEditable.getLocalRectForCaret(TextPosition(offset: sel.baseOffset));
    final globalTopLeft = renderEditable.localToGlobal(rawRect.topLeft);
    final localTopLeft = renderBox.globalToLocal(globalTopLeft);
    final caretRect = Rect.fromLTWH(
      localTopLeft.dx,
      localTopLeft.dy,
      math.max(rawRect.width, 2.0),
      rawRect.height,
    );

    final height = caretRect.height;
    final tilt = height * 0.23; // ~13 degrees forward tilt
    const width = 2.0;

    final path = Path()
      ..moveTo(caretRect.left + tilt, caretRect.top)
      ..lineTo(caretRect.left + tilt + width, caretRect.top)
      ..lineTo(caretRect.left + width, caretRect.bottom)
      ..lineTo(caretRect.left, caretRect.bottom)
      ..close();

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ItalicCaretPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Floating scrollable text selection context menu for rich text formatting.
class ScrollableTextSelectionToolbar extends StatelessWidget {
  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;
  final TextEditingController controller;
  final VoidCallback onHideToolbar;

  const ScrollableTextSelectionToolbar({
    Key? key,
    required this.anchors,
    required this.buttonItems,
    required this.controller,
    required this.onHideToolbar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.96);
    final iconColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final dividerColor = isDark ? Colors.white24 : Colors.black12;

    return CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: anchors.primaryAnchor,
        anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      ),
      child: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(16.0),
        color: bgColor,
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: 44.0,
          constraints: BoxConstraints(
            maxWidth: math.max(120.0, MediaQuery.of(context).size.width - 32.0),
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Standard actions (Cut, Copy, Paste, etc.)
                for (final item in buttonItems)
                  TextButton(
                    onPressed: item.onPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: iconColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    child: Text(item.label ?? ''),
                  ),

                // 2. Divider if both standard actions and formatting buttons exist
                if (buttonItems.isNotEmpty)
                  Container(
                    width: 1.0,
                    height: 20.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    color: dividerColor,
                  ),

                // 3. Formatting buttons with icons
                _buildFormatButton(
                  icon: iconoir.Bold(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_bold'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'bold');
                    onHideToolbar();
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.Italic(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_italic'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'italic');
                    onHideToolbar();
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.Strikethrough(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_strikethrough'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'strikethrough');
                    onHideToolbar();
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.Underline(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_underline'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'underline');
                    onHideToolbar();
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.EyeClosed(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_spoiler'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'spoiler');
                    onHideToolbar();
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.Code(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_code'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'code');
                    onHideToolbar();
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.Quote(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_quote'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'quote');
                    onHideToolbar();
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.NavArrowDown(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_collapse'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'collapse');
                    onHideToolbar();
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.Link(color: iconColor, width: 18, height: 18),
                  tooltip: 'Ссылка',
                  onTap: () {
                    onHideToolbar();
                    TextFormattingUtils.showLinkDialog(context, controller);
                  },
                ),
                _buildFormatButton(
                  icon: iconoir.Refresh(color: iconColor, width: 18, height: 18),
                  tooltip: context.l10n.translate('format_clear'),
                  onTap: () {
                    TextFormattingUtils.applyFormatting(controller, 'clear');
                    onHideToolbar();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required Widget icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          width: 36.0,
          height: 36.0,
          alignment: Alignment.center,
          child: icon,
        ),
      ),
    );
  }
}

/// Утилиты форматирования выделенного текста для контекстного меню
class TextFormattingUtils {
  static void applyFormatting(TextEditingController controller, String type,
      {String? url}) {
    if (controller is RichTextEditingController) {
      controller.applyFormat(type, url: url);
    } else {
      EntityParser.applyFormatting(
        controller: controller,
        formatType: type,
        url: url,
      );
    }
  }

  static void showLinkDialog(BuildContext context, TextEditingController controller) {
    final textController = TextEditingController(text: 'https://');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.translate('chat_action_link') != 'chat_action_link'
            ? ctx.l10n.translate('chat_action_link')
            : 'Ссылка'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              final url = textController.text.trim();
              Navigator.pop(ctx);
              if (url.isNotEmpty && url != 'https://') {
                applyFormatting(controller, 'link', url: url);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}


