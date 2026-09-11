import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/name_color_preset.dart';
import '../../services/profile_theme_provider.dart';
import '../../utils/haptic_utils.dart';
import '../profile/reply_strip_painter.dart';

/// Interactive Collapsible Blockquote Widget.
///
/// Features a stylish accent strip on the left, card background, and an expand/collapse
/// button when the blockquote is marked collapsible or exceeds 3 lines.
class CollapsibleBlockquoteWidget extends StatefulWidget {
  final String text;
  final Widget? child;
  final bool isCollapsible;
  final bool initialExpanded;
  final bool isDark;
  final bool isMe;
  final NameColorPreset? preset;
  final ReplyStripStyle? stripStyle;

  const CollapsibleBlockquoteWidget({
    Key? key,
    required this.text,
    this.child,
    this.isCollapsible = false,
    this.initialExpanded = false,
    required this.isDark,
    required this.isMe,
    this.preset,
    this.stripStyle,
  }) : super(key: key);

  @override
  State<CollapsibleBlockquoteWidget> createState() =>
      _CollapsibleBlockquoteWidgetState();
}

class _CollapsibleBlockquoteWidgetState
    extends State<CollapsibleBlockquoteWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  void _toggleExpand() {
    HapticUtils.tap();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileTheme = context.watch<ProfileThemeProvider>();
    final effectivePreset = widget.preset ?? profileTheme.currentNameColorPreset;
    final effectiveStripStyle = widget.stripStyle ?? profileTheme.currentStripStyle;

    final cardBgColor = effectivePreset.getOpaqueCardBackgroundColor(widget.isDark);
    final primaryColor = effectivePreset.primaryColor;

    final quoteTextStyle = TextStyle(
      fontSize: 14,
      fontStyle: FontStyle.italic,
      color: widget.isDark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF1C2530),
      height: 1.35,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Container has horizontal padding 8+8=16, ReplyStrip 3.5, space 8, quote icon padding 14 -> 41.5 total
        final double maxContentWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth - 41.5).clamp(10.0, double.infinity)
            : double.infinity;

        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: quoteTextStyle),
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: maxContentWidth);

        // Only show toggle button if quote exceeds 3 lines
        final bool showToggle = textPainter.didExceedMaxLines;

        return MetaData(
          metaData: 'block_element',
          child: Container(
            constraints: BoxConstraints(
              maxWidth: constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: iconoir.QuoteSolid(
                  color: primaryColor.withValues(alpha: 0.35),
                  width: 14,
                  height: 14,
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReplyStripWidget(
                      preset: effectivePreset,
                      style: effectiveStripStyle,
                      width: 3.5,
                      borderRadius: 2,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.loose,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOutCubic,
                                alignment: Alignment.topLeft,
                                clipBehavior: Clip.hardEdge,
                                child: widget.child ??
                                    Text(
                                      widget.text,
                                      maxLines: (showToggle && !_isExpanded) ? 3 : null,
                                      overflow: (showToggle && !_isExpanded)
                                          ? TextOverflow.ellipsis
                                          : TextOverflow.clip,
                                      style: quoteTextStyle,
                                    ),
                              ),
                              if (showToggle) ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: _toggleExpand,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isExpanded
                                              ? context.l10n.translate('format_collapsed_state')
                                              : context.l10n.translate('format_expand'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        AnimatedRotation(
                                          turns: _isExpanded ? 0.5 : 0.0,
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeInOutCubic,
                                          child: iconoir.NavArrowDown(
                                            width: 14,
                                            height: 14,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }
}
