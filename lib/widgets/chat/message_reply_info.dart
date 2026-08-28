import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../services/profile_theme_provider.dart';
import '../../utils/emoji_utils.dart';
import '../profile/reply_strip_painter.dart';

/// Displays a compact reply/quote preview above a message bubble.
/// Shows the original sender's name and a truncated preview of the content.
/// Tapping scrolls to the original message.
///
/// Handles gracefully the case when the original message was deleted
/// (shows "Сообщение удалено").
class MessageReplyInfo extends StatelessWidget {
  /// The reply info (cached preview data)
  final ReplyInfo? replyInfo;

  /// Whether this is a quote (partial text) rather than a full reply
  final bool isQuote;

  /// The quoted text fragment (for quotes)
  final String? quoteText;

  /// Callback when user taps to scroll to the original message
  final VoidCallback? onTap;

  /// Whether this is the current user's message (affects color)
  final bool isMe;

  /// Optional override for the title (instead of senderName from replyInfo)
  final String? titleOverride;

  /// Optional override for the content (instead of content from replyInfo)
  final String? contentOverride;

  const MessageReplyInfo({
    Key? key,
    this.replyInfo,
    this.isQuote = false,
    this.quoteText,
    this.onTap,
    this.isMe = false,
    this.titleOverride,
    this.contentOverride,
  }) : super(key: key);

  /// Helper to create a forwarded message header
  factory MessageReplyInfo.forwarded({
    required String authorName,
    String? content,
    bool isMe = false,
    VoidCallback? onTap,
  }) {
    return MessageReplyInfo(
      titleOverride: authorName,
      contentOverride: content,
      isMe: isMe,
      onTap: onTap,
    );
  }

  String _truncate(String text, {int maxLen = 50}) {
    final cleaned = _cleanMarkdown(text);
    if (cleaned.length <= maxLen) return cleaned;
    return '${cleaned.substring(0, maxLen)}…';
  }

  String _cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'```[a-zA-Z0-9+#]*'), '') // Remove code block start/lang
        .replaceAll('```', '') // Remove code block end
        .replaceAll(RegExp(r'`'), '') // Remove inline code backticks
        .replaceAll(RegExp(r'[*_~]'), '') // Remove basic markdown formatting
        .replaceAll(RegExp(r'\n+'), ' ') // Replace newlines with spaces for single-line preview
        .trim();
  }

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
      default:
        return Icons.chat_bubble;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If no reply info AND no overrides, show nothing
    if (replyInfo == null && titleOverride == null) return const SizedBox.shrink();

    // Check if original message was deleted.
    final isDeleted = replyInfo == null ? false : replyInfo!.messageId.isEmpty;

    // Retrieve name color preset & strip style from ProfileThemeProvider
    final profileTheme = context.watch<ProfileThemeProvider>();
    final preset = profileTheme.currentNameColorPreset;
    final stripStyle = profileTheme.currentStripStyle;

    // Accent and vibrant opaque background color derived purely from preset via HSL
    final accentColor = preset.primaryColor;
    final bgColor = preset.getOpaqueCardBackgroundColor(isDark);
    const textColor = Color(0xFF1C2530);

    // Determine preview text
    String previewText;
    if (isDeleted) {
      previewText = 'Сообщение удалено';
    } else if (contentOverride != null) {
      previewText = _truncate(contentOverride!);
    } else if (isQuote && quoteText != null && quoteText!.isNotEmpty) {
      previewText = _truncate(quoteText!);
    } else if (replyInfo != null && replyInfo!.messageType != 'text') {
      // Show media type indicator instead of content
      switch (replyInfo!.messageType) {
        case 'image':
          previewText = '📷 Фото';
          break;
        case 'video':
          previewText = '🎥 Видео';
          break;
        case 'audio':
        case 'voice':
          previewText = '🎤 Голосовое сообщение';
          break;
        case 'file':
        case 'document':
          previewText = '📎 Файл';
          break;
        case 'sticker':
          previewText = '🎭 Стикер';
          break;
        default:
          previewText = _truncate(replyInfo!.content);
      }
    } else if (replyInfo != null) {
      previewText = _truncate(replyInfo!.content);
    } else {
      previewText = '';
    }

    String title = titleOverride ?? replyInfo?.senderName ?? '';
    if (title.isEmpty && replyInfo != null) {
      // If it's a reply but sender name is missing, it's likely the current user's message
      // being replied to in a local-first or sync scenario.
      title = isMe ? 'Вы' : 'Сообщение';
    }

    return GestureDetector(
      onTap: isDeleted ? null : onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Accent strip with strip style (solid, dualColor, candyCane, segmented)
              ReplyStripWidget(
                preset: preset,
                style: stripStyle,
                width: 3.5,
                borderRadius: 2,
              ),
              const SizedBox(width: 8),

              // Quoted content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sender name / Title
                    if (!isDeleted && title.isNotEmpty)
                      Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!isDeleted && title.isNotEmpty && previewText.isNotEmpty)
                      const SizedBox(height: 2),
                    // Preview text
                    if (previewText.isNotEmpty)
                      if (isQuote && !isDeleted)
                        RichText(
                          text: EmojiUtils.buildEmojiTextSpan(
                            previewText,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isDeleted && replyInfo != null && replyInfo!.messageType != 'text')
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  _messageTypeIcon(replyInfo!.messageType),
                                  size: 12,
                                  color: textColor,
                                ),
                              ),
                            Flexible(
                              child: RichText(
                                text: EmojiUtils.buildEmojiTextSpan(
                                  previewText,
                                  style: const TextStyle(
                                    color: textColor,
                                    fontSize: 12,
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
    );
  }
}

