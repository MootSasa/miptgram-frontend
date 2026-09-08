import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
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

  const CollapsibleBlockquoteWidget({
    Key? key,
    required this.text,
    this.child,
    this.isCollapsible = false,
    this.initialExpanded = false,
    required this.isDark,
    required this.isMe,
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
    final preset = profileTheme.currentNameColorPreset;
    final stripStyle = profileTheme.currentStripStyle;

    final cardBgColor = preset.getOpaqueCardBackgroundColor(widget.isDark);
    final theme = Theme.of(context);
    final primaryColor = preset.primaryColor;

    final isActuallyLong = widget.text.contains('\n') || widget.text.length > 100;
    final showToggle = widget.isCollapsible || isActuallyLong;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReplyStripWidget(
              preset: preset,
              style: stripStyle,
              width: 3.5,
              borderRadius: 2,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: widget.child ??
                        Text(
                          widget.text,
                          maxLines: (showToggle && !_isExpanded) ? 3 : null,
                          overflow: (showToggle && !_isExpanded)
                              ? TextOverflow.ellipsis
                              : TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: widget.isDark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF1C2530),
                            height: 1.35,
                          ),
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
                              duration: const Duration(milliseconds: 200),
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
          ],
        ),
      ),
    );
  }
}
