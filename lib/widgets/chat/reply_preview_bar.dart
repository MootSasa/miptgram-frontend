import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../services/profile_theme_provider.dart';
import '../../utils/emoji_utils.dart';
import '../profile/reply_strip_painter.dart';

/// A floating bubble shown above the message input field when the user
/// is composing a reply or quote.
class ReplyPreviewBar extends StatelessWidget {
  final Message replyToMessage;
  final bool isQuote;
  final String? quoteText;
  final VoidCallback onClose;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isLite;

  const ReplyPreviewBar({
    Key? key,
    required this.replyToMessage,
    this.isQuote = false,
    this.quoteText,
    required this.onClose,
    this.onTap,
    this.enabled = false,
    this.isLite = false,
  }) : super(key: key);

  /// Truncate text for preview
  String _truncate(String text, {int maxLen = 60}) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}…';
  }

  /// Get icon for message type
  IconData _messageTypeIcon(String messageType) {
    switch (messageType) {
      case 'image':
        return Icons.photo;
      case 'video':
        return Icons.videocam;
      case 'audio':
      case 'voice':
        return Icons.mic;
      case 'file':
      case 'document':
        return Icons.insert_drive_file;
      case 'sticker':
        return Icons.emoji_emotions;
      case 'poll':
        return Icons.poll;
      default:
        return Icons.chat_bubble;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _buildClassicBar(context);
    }
    return _buildGlassBar(context);
  }

  Widget _buildClassicBar(BuildContext context) {
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: LiquidGlassLayer(
        settings: glassSettings,
        child: FakeGlass(
          settings: glassSettings,
          shape: const LiquidRoundedSuperellipse(borderRadius: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
            ),
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBar(BuildContext context) {
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: isLite
          ? FakeGlass(
              settings: glassSettings,
              shape: const LiquidRoundedSuperellipse(borderRadius: 16),
              child: GlassGlow(child: _buildContent(context)),
            )
          : LiquidGlass.withOwnLayer(
              settings: glassSettings,
              shape: const LiquidRoundedSuperellipse(borderRadius: 16),
              child: GlassGlow(child: _buildContent(context)),
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final profileTheme = context.watch<ProfileThemeProvider>();
    final accentColor = profileTheme.activeNameColor;

    // Determine preview text
    String previewText;
    if (isQuote && quoteText != null && quoteText!.isNotEmpty) {
      previewText = _truncate(quoteText!);
    } else {
      previewText = _truncate(replyToMessage.content);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Content
          Flexible(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Vertical accent bar with custom strip style
                  ReplyStripWidget(
                    preset: profileTheme.currentNameColorPreset,
                    style: profileTheme.currentStripStyle,
                    width: 3.5,
                    height: 32,
                    borderRadius: 2,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header: Reply/Quote label + sender name
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isQuote ? Icons.format_quote : Icons.reply,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isQuote ? 'Цитата' : 'Ответ',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                replyToMessage.senderName,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Preview text or media indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (replyToMessage.messageType != 'text')
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  _messageTypeIcon(replyToMessage.messageType),
                                  size: 14,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            Flexible(
                              child: RichText(
                                text: EmojiUtils.buildEmojiTextSpan(
                                  replyToMessage.messageType == 'text' || isQuote
                                      ? previewText
                                      : replyToMessage.messageType == 'image'
                                          ? 'Фото'
                                          : replyToMessage.messageType == 'video'
                                              ? 'Видео'
                                              : replyToMessage.messageType == 'audio'
                                                  ? 'Голосовое сообщение'
                                                  : 'Файл',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Close button
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }
}
