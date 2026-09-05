import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import '../../config/app_config.dart';
import '../../services/chat_service.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/haptic_utils.dart';
import '../chat/message_reply_info.dart';
import '../chat/reactions_panel.dart';
import 'message_status_widget.dart';
import 'text_message_widget.dart';
import 'fullscreen_photo_viewer.dart';
import 'inline_video_player.dart';
import 'document_message_widget.dart';
import 'video_message_widget.dart';
import '../../l10n/app_localizations.dart';

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

  bool get _hasMedia {
    final url = message.fileUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  bool _isImageUrl(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.bmp') ||
        clean.endsWith('.heic') ||
        url.startsWith('data:image/');
  }

  bool _isVideoUrl(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.webm');
  }

  bool _isAudioUrl(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.mp3') ||
        clean.endsWith('.wav') ||
        clean.endsWith('.ogg') ||
        clean.endsWith('.m4a') ||
        clean.endsWith('.aac');
  }

  bool get _isImage =>
      _hasMedia &&
      (message.messageType == 'image' ||
          message.messageType == 'photo' ||
          _isImageUrl(message.fileUrl!));

  bool get _isVideo =>
      _hasMedia &&
      (message.messageType == 'video' || _isVideoUrl(message.fileUrl!));

  bool get _isAudio =>
      _hasMedia &&
      (message.messageType == 'audio' ||
          message.messageType == 'voice' ||
          _isAudioUrl(message.fileUrl!));

  bool get _isRoundVideo =>
      _hasMedia && message.messageType == 'round';

  bool get _hasCaption {
    if (!_hasMedia) return false;
    final trimmed = message.content.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == message.fileName) return false;
    if (trimmed == message.fileUrl) return false;
    return true;
  }

  bool get _isSingleEmoji {
    if (_hasMedia || message.messageType != 'text' || message.hasReply) {
      return false;
    }
    final trimmed = message.content.trim();
    if (trimmed.isEmpty) return false;
    final runes = trimmed.runes.toList();
    return runes.length <= 2 && EmojiUtils.emojiRegex.hasMatch(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final String? resolvedFileUrl = AppConfig.resolveMediaUrl(message.fileUrl);
    final bool hasMedia = _hasMedia && resolvedFileUrl != null && resolvedFileUrl.isNotEmpty;
    final bool hasCaption = _hasCaption;
    final bool isBigEmoji = !hasMedia && _isSingleEmoji;
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
        hasMedia;

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
                if (message.isEdited) ...[
                  Text(
                    context.l10n.translate('chat_edited'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
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
                      child: const iconoir.WarningCircle(width: 14, height: 14, color: Colors.redAccent),
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
                if (message.isEdited) ...[
                  Text(
                    context.l10n.translate('chat_edited'),
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: textStyle.color?.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
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
                      child: const iconoir.WarningCircle(width: 14, height: 14, color: Colors.red),
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
    if (hasMedia) {
      final double mediaWidth = math.min(maxBubbleWidth, 340.0);
      final Widget mediaWidget = _buildMediaWidget(context, mediaWidth, resolvedFileUrl);

      Widget innerContent;
      if (hasCaption) {
        final Widget captionWidget = TextMessageWidget(
          text: message.content,
          style: textStyle,
          isMe: isMe,
        );

        innerContent = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            mediaWidget,
            const SizedBox(height: 6.0),
            captionWidget,
            const SizedBox(height: 3.0),
            metadataWidget,
          ],
        );
      } else if (_isImage || _isVideo) {
        innerContent = Stack(
          alignment: Alignment.bottomRight,
          children: [
            mediaWidget,
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildFloatingMetadata(context),
              ),
            ),
          ],
        );
      } else {
        innerContent = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            mediaWidget,
            const SizedBox(height: 3.0),
            metadataWidget,
          ],
        );
      }

      if (replyWidget != null || (!isMe && senderName != null && senderName!.isNotEmpty)) {
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
            if (replyWidget != null) ...[
              SizedBox(width: mediaWidth, child: replyWidget),
              const SizedBox(height: 4.0),
            ],
            innerContent,
          ],
        );
      } else {
        contentWidget = innerContent;
      }
    } else if (replyWidget != null) {
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

    final EdgeInsets bubblePadding = isBigEmoji
        ? EdgeInsets.zero
        : (hasMedia && !hasCaption && replyWidget == null && (senderName == null || senderName!.isEmpty || isMe))
            ? const EdgeInsets.all(4.0)
            : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);

    Widget bubbleCore = Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8.0),
      padding: bubblePadding,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(kMessageBorderRadius),
      ),
      child: (replyWidget != null || hasMedia)
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

  Widget _buildMediaWidget(
    BuildContext context,
    double maxWidth,
    String resolvedUrl,
  ) {
    if (_isRoundVideo) {
      return VideoMessageWidget(videoUrl: resolvedUrl);
    }

    if (_isImage) {
      final heroTag = 'msg_photo_${message.id}_$resolvedUrl';
      return GestureDetector(
        onTap: () {
          FullscreenPhotoViewer.open(context, resolvedUrl, tag: heroTag);
          onFileTap?.call(
            resolvedUrl,
            message.fileName ?? 'image.jpg',
            'image',
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Hero(
            tag: heroTag,
            child: Image.network(
              resolvedUrl,
              width: maxWidth,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: maxWidth,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2.0,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: maxWidth,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconoir.MediaImage(
                        width: 36,
                        height: 36,
                        color: isMe
                            ? Colors.white70
                            : Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer
                                .withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.translate('chat_file_not_found'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe
                              ? Colors.white70
                              : Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                                  .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    if (_isVideo) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: 280,
        ),
        child: InlineVideoPlayer(url: resolvedUrl),
      );
    }

    if (_isAudio) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const iconoir.MusicNote(width: 28, height: 28, color: Color(0xFF0088CC)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.fileName ?? 'Audio',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }

    // Default: Document / File
    return DocumentMessageWidget(
      fileUrl: resolvedUrl,
      fileName: message.fileName ??
          (message.content.trim().isNotEmpty ? message.content.trim() : 'file'),
      fileSize: 0,
    );
  }

  Widget _buildFloatingMetadata(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (message.isEdited) ...[
          Text(
            context.l10n.translate('chat_edited'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          formatTime(message.createdAt),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          if (message.sendStatus == 0)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.0,
                color: Colors.white,
              ),
            )
          else if (message.sendStatus == 2)
            GestureDetector(
              onTap: () => onRetry?.call(message),
              child: const iconoir.WarningCircle(
                color: Colors.redAccent,
                width: 14,
                height: 14,
              ),
            )
          else
            MessageStatusWidget(
              isRead: message.isRead,
              isOutgoing: isMe,
              colorOverride: Colors.white.withValues(alpha: 0.9),
            ),
        ],
      ],
    );
  }
}
