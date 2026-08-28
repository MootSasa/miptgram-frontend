import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/haptic_utils.dart';
import '../chat/message_reply_info.dart';
import '../chat/reactions_panel.dart';
import 'message_status_widget.dart';
import 'text_message_widget.dart';

/// Радиус скругления "облачка" сообщения.
const double kMessageBorderRadius = 18.0;

/// Custom layout widget for message bubble layout.
class MessageBubbleLayout extends StatelessWidget {
  final Widget content;
  final Widget metadata;
  final String? text;
  final TextStyle textStyle;
  final bool hasBlockElement;
  final bool isBigEmoji;
  final Widget? replyWidget;

  const MessageBubbleLayout({
    Key? key,
    required this.content,
    required this.metadata,
    this.text,
    required this.textStyle,
    this.hasBlockElement = false,
    this.isBigEmoji = false,
    this.replyWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isBigEmoji) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            bottom: 0,
            right: 0,
            child: metadata,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxContentWidth = constraints.maxWidth;
        const double metadataWidthEstimate = 68.0;
        const double gap = 8.0;

        // Check if text does NOT contain block code (```) or TeX ($) which distort TextPainter
        final bool canEstimateLineMetrics = !hasBlockElement &&
            replyWidget == null &&
            text != null &&
            text!.trim().isNotEmpty &&
            !text!.contains('```') &&
            !text!.contains('\$');

        if (canEstimateLineMetrics) {
          // Strip simple markdown formatting characters for accurate line measurement
          final cleanText = text!
              .replaceAll(RegExp(r'\*|_|`|~|#'), '')
              .trim();

          final TextPainter tp = TextPainter(
            text: TextSpan(text: cleanText, style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxContentWidth);

          final lineMetrics = tp.computeLineMetrics();
          final int lineCount = lineMetrics.length;
          final double lastLineWidth = lineMetrics.isNotEmpty ? lineMetrics.last.width : tp.width;

          // Case A: Single-line text that fits inline with metadata inside a Row
          if (lineCount <= 1 && (tp.width + metadataWidthEstimate + gap <= maxContentWidth)) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: content),
                const SizedBox(width: gap),
                metadata,
              ],
            );
          }

          // Case B: Multi-line text where the last line has enough remaining space for metadata
          final double remainingSpaceOnLastLine = maxContentWidth - lastLineWidth;
          if (lineCount > 1 && remainingSpaceOnLastLine >= (metadataWidthEstimate + gap)) {
            return Stack(
              children: [
                content,
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: metadata,
                ),
              ],
            );
          }
        }

        // Case C: Multi-line text with full last line, reply headers, TeX formulas, code blocks, media, polls:
        // Place metadata in a separate row below content to guarantee no overlap.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            content,
            const SizedBox(height: 3.0),
            metadata,
          ],
        );
      },
    );
  }
}

/// Unified Message Bubble Widget.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String currentUserId;
  final String? senderName;
  final String? chatType;
  final bool isHighlighted;
  final Map<String, int>? reactions;
  final String? myReaction;
  final Function(String emoji)? onReactionTap;
  final Function(Message message)? onRetry;
  final Function(String replyToId, String? chatId)? onReplyTap;
  final Function(String url, String name, String type)? onFileTap;
  final String Function(String timestamp) formatTime;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.senderName,
    this.chatType,
    this.isHighlighted = false,
    this.reactions,
    this.myReaction,
    this.onReactionTap,
    this.onRetry,
    this.onReplyTap,
    this.onFileTap,
    required this.formatTime,
  }) : super(key: key);

  bool get _isSingleEmoji {
    if (message.messageType != 'text' || message.fileUrl != null || message.hasReply) {
      return false;
    }
    final trimmed = message.content.trim();
    if (trimmed.isEmpty) return false;
    final runes = trimmed.runes.toList();
    return runes.length <= 2 && EmojiUtils.emojiRegex.hasMatch(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final bool isBigEmoji = _isSingleEmoji;
    final Alignment alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;

    final Color backgroundColor = isBigEmoji
        ? Colors.transparent
        : (isMe
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondaryContainer);

    final TextStyle textStyle = TextStyle(
      fontSize: 16.0,
      color: isBigEmoji
          ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
          : (isMe
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSecondaryContainer),
    );

    final bool hasHeaderBlock = message.hasReply ||
        (chatType == 'saved' && (message.forwardFromName?.isNotEmpty ?? false || message.senderName.isNotEmpty));

    final bool endsWithBlock = hasHeaderBlock ||
        message.content.trim().endsWith('```') ||
        message.content.trim().endsWith('\$\$') ||
        (message.messageType != 'text' && message.fileUrl != null);

    // Build Metadata Widget
    final Widget metadataWidget = isBigEmoji
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTime(message.createdAt),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  if (message.sendStatus == 0)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.0, color: Colors.white),
                    )
                  else if (message.sendStatus == 2)
                    GestureDetector(
                      onTap: () => onRetry?.call(message),
                      child: const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                    )
                  else
                    MessageStatusWidget(
                      isRead: message.isRead,
                      isOutgoing: isMe,
                      colorOverride: Colors.white.withValues(alpha: 0.9),
                    ),
                ],
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(left: 6.0, top: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: textStyle.color?.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  if (message.sendStatus == 0)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.2),
                    )
                  else if (message.sendStatus == 2)
                    GestureDetector(
                      onTap: () => onRetry?.call(message),
                      child: const Icon(Icons.error_outline, size: 14, color: Colors.red),
                    )
                  else
                    MessageStatusWidget(
                      isRead: message.isRead,
                      isOutgoing: isMe,
                    ),
                ],
              ],
            ),
          );

    final double maxBubbleWidth = MediaQuery.of(context).size.width * 0.76 - 24.0; // 24 = horizontal padding
    const double metadataWidthEstimate = 68.0;
    const double gap = 8.0;

    // Prepare Reply Widget if present
    Widget? replyWidget;
    double replyWidthEstimate = 0.0;

    if (message.hasReply) {
      replyWidget = MessageReplyInfo(
        replyInfo: message.replyInfo,
        isQuote: message.isQuote,
        quoteText: message.quoteText,
        isMe: isMe,
        onTap: () => onReplyTap?.call(
          message.replyToMessageId!,
          message.replyInfo?.chatId,
        ),
        titleOverride: message.replyInfo?.senderId == currentUserId ? 'Вы' : null,
      );

      final String replyText = message.quoteText ?? message.replyInfo?.content ?? '';
      final String senderTitle = (message.replyInfo?.senderId == currentUserId ? 'Вы' : message.replyInfo?.senderName) ?? 'Сообщение';
      
      final TextPainter replyTitleTp = TextPainter(
        text: TextSpan(text: senderTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxBubbleWidth);

      final TextPainter replyBodyTp = TextPainter(
        text: TextSpan(text: replyText.replaceAll(RegExp(r'\n+'), ' '), style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxBubbleWidth);

      replyWidthEstimate = math.max(replyTitleTp.width, replyBodyTp.width) + 28.0; // 28 = accent bar + padding
    } else if (chatType == 'saved' && (message.forwardFromName?.isNotEmpty ?? false || message.senderName.isNotEmpty)) {
      replyWidget = MessageReplyInfo.forwarded(
        authorName: message.forwardFromName ?? message.senderName,
        isMe: isMe,
      );
      replyWidthEstimate = 120.0;
    }

    // Estimate Main Text Width & Lines
    final TextPainter mainTextTp = TextPainter(
      text: TextSpan(text: message.content.replaceAll(RegExp(r'\*|_|`|~|#'), '').trim(), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxBubbleWidth);

    final double mainTextWidthEstimate = mainTextTp.width;
    final lineMetrics = mainTextTp.computeLineMetrics();
    final int lineCount = lineMetrics.length;
    final double lastLineWidth = lineMetrics.isNotEmpty ? lineMetrics.last.width : mainTextTp.width;

    bool fitsInline = false;
    double requiredInlineWidth = mainTextWidthEstimate;

    if (!message.content.contains('```') && !message.content.contains('\$')) {
      if (lineCount <= 1 && (mainTextWidthEstimate + metadataWidthEstimate + gap <= maxBubbleWidth)) {
        fitsInline = true;
        requiredInlineWidth = mainTextWidthEstimate + metadataWidthEstimate + gap;
      } else if (lineCount > 1 && (maxBubbleWidth - lastLineWidth >= metadataWidthEstimate + gap)) {
        fitsInline = true;
        requiredInlineWidth = mainTextWidthEstimate;
      }
    }

    // Adaptive bubble content width = max(replyWidth, textWidth / requiredInlineWidth)
    double targetContentWidth = math.max(replyWidthEstimate, fitsInline ? requiredInlineWidth : mainTextWidthEstimate);
    targetContentWidth = math.min(targetContentWidth, maxBubbleWidth);

    Widget contentWidget;
    if (replyWidget != null) {
      Widget textBodyWidget;
      if (isBigEmoji) {
        textBodyWidget = Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: GestureDetector(
            onTap: () => HapticUtils.tap(),
            child: EmojiUtils.appleEmoji(
              message.content,
              size: 64.0,
              fallbackStyle: textStyle,
            ),
          ),
        );
      } else {
        textBodyWidget = TextMessageWidget(
          text: message.content,
          style: textStyle,
          isMe: isMe,
        );
      }

      Widget bottomRowWidget;
      if (fitsInline) {
        if (lineCount <= 1) {
          bottomRowWidget = SizedBox(
            width: targetContentWidth,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                textBodyWidget,
                const Spacer(),
                metadataWidget,
              ],
            ),
          );
        } else {
          bottomRowWidget = SizedBox(
            width: targetContentWidth,
            child: Stack(
              children: [
                textBodyWidget,
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: metadataWidget,
                ),
              ],
            ),
          );
        }
      } else {
        bottomRowWidget = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: targetContentWidth,
              child: textBodyWidget,
            ),
            const SizedBox(height: 3.0),
            metadataWidget,
          ],
        );
      }

      contentWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: targetContentWidth,
            child: replyWidget,
          ),
          const SizedBox(height: 4.0),
          bottomRowWidget,
        ],
      );
    } else {
      contentWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && senderName != null && senderName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                senderName!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          if (isBigEmoji)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: GestureDetector(
                onTap: () => HapticUtils.tap(),
                child: EmojiUtils.appleEmoji(
                  message.content,
                  size: 64.0,
                  fallbackStyle: textStyle,
                ),
              ),
            )
          else
            TextMessageWidget(
              text: message.content,
              style: textStyle,
              isMe: isMe,
            ),
        ],
      );
    }

    Widget bubbleCore = Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8.0),
      padding: isBigEmoji ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(kMessageBorderRadius),
      ),
      child: replyWidget != null
          ? contentWidget
          : MessageBubbleLayout(
              content: contentWidget,
              metadata: metadataWidget,
              text: message.content,
              textStyle: textStyle,
              hasBlockElement: endsWithBlock,
              isBigEmoji: isBigEmoji,
              replyWidget: replyWidget,
            ),
    );

    Widget result = Align(
      alignment: alignment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        color: isHighlighted
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
            : Colors.transparent,
        child: bubbleCore,
      ),
    );

    // Reactions row below message bubble if present
    if (reactions != null && reactions!.isNotEmpty) {
      result = Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          result,
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 12, right: 12),
            child: MessageReactionsRow(
              reactions: reactions!,
              myReaction: myReaction,
              onTap: onReactionTap,
            ),
          ),
        ],
      );
    }

    return result;
  }
}
