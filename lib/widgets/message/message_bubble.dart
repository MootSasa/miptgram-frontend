import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Role of a child inside [BubbleLayoutWidget].
enum BubbleChildRole {
  senderName,
  reply,
  content,
  metadata,
}

/// Parent data for children of [RenderBubbleLayout].
class BubbleParentData extends ContainerBoxParentData<RenderBox> {
  BubbleChildRole? role;
}

/// Wrapper widget to attach [BubbleChildRole] to children of [BubbleLayoutWidget].
class BubbleChild extends ParentDataWidget<BubbleParentData> {
  final BubbleChildRole role;

  const BubbleChild({
    Key? key,
    required this.role,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData as BubbleParentData;
    if (parentData.role != role) {
      parentData.role = role;
      final targetParent = renderObject.parent;
      if (targetParent is RenderObject) {
        targetParent.markNeedsLayout();
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => BubbleLayoutWidget;
}

/// Metrics extracted from inspecting the rendered content tree.
class _BubbleContentMetrics {
  final bool hasText;
  final bool isSingleLine;
  final double lastCharRight;
  final double lastCharBottom;
  final double lastLineHeight;

  const _BubbleContentMetrics({
    required this.hasText,
    required this.isSingleLine,
    required this.lastCharRight,
    required this.lastCharBottom,
    required this.lastLineHeight,
  });
}

/// Multi-child render object widget that performs dynamic layout for message bubbles.
class BubbleLayoutWidget extends MultiChildRenderObjectWidget {
  final double replyWidth;
  final double senderNameWidth;
  final double? metadataWidth;
  final bool hasBlockElement;

  BubbleLayoutWidget({
    Key? key,
    Widget? senderNameWidget,
    Widget? replyWidget,
    required Widget content,
    required Widget metadata,
    this.replyWidth = 0.0,
    this.senderNameWidth = 0.0,
    this.metadataWidth,
    this.hasBlockElement = false,
  }) : super(
          key: key,
          children: [
            if (senderNameWidget != null)
              BubbleChild(role: BubbleChildRole.senderName, child: senderNameWidget),
            if (replyWidget != null)
              BubbleChild(role: BubbleChildRole.reply, child: replyWidget),
            BubbleChild(role: BubbleChildRole.content, child: content),
            BubbleChild(role: BubbleChildRole.metadata, child: metadata),
          ],
        );

  @override
  RenderBubbleLayout createRenderObject(BuildContext context) {
    return RenderBubbleLayout(
      replyWidth: replyWidth,
      senderNameWidth: senderNameWidth,
      metadataWidth: metadataWidth,
      hasBlockElement: hasBlockElement,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderBubbleLayout renderObject) {
    renderObject
      ..replyWidth = replyWidth
      ..senderNameWidth = senderNameWidth
      ..metadataWidth = metadataWidth
      ..hasBlockElement = hasBlockElement;
  }
}

/// Custom RenderBox for pixel-perfect message bubble layout.
///
/// Gives [content] loose constraints so text wraps naturally across the full available
/// width without premature wrapping. Then inspects the actual rendered paragraph
/// boxes to position metadata inline on the last line whenever physical space permits,
/// or on a separate row below if the last line is full, without bloating bubble width.
class RenderBubbleLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, BubbleParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, BubbleParentData> {
  double _replyWidth;
  double _senderNameWidth;
  double? _metadataWidth;
  bool _hasBlockElement;

  RenderBubbleLayout({
    double replyWidth = 0.0,
    double senderNameWidth = 0.0,
    double? metadataWidth,
    bool hasBlockElement = false,
    List<RenderBox>? children,
  })  : _replyWidth = replyWidth,
        _senderNameWidth = senderNameWidth,
        _metadataWidth = metadataWidth,
        _hasBlockElement = hasBlockElement {
    addAll(children);
  }

  double get replyWidth => _replyWidth;
  set replyWidth(double value) {
    if (_replyWidth != value) {
      _replyWidth = value;
      markNeedsLayout();
    }
  }

  double get senderNameWidth => _senderNameWidth;
  set senderNameWidth(double value) {
    if (_senderNameWidth != value) {
      _senderNameWidth = value;
      markNeedsLayout();
    }
  }

  double? get metadataWidth => _metadataWidth;
  set metadataWidth(double? value) {
    if (_metadataWidth != value) {
      _metadataWidth = value;
      markNeedsLayout();
    }
  }

  bool get hasBlockElement => _hasBlockElement;
  set hasBlockElement(bool value) {
    if (_hasBlockElement != value) {
      _hasBlockElement = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BubbleParentData) {
      child.parentData = BubbleParentData();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double width = 0.0;
    while (child != null) {
      final childParentData = child.parentData as BubbleParentData;
      width = math.max(width, child.getMinIntrinsicWidth(height));
      child = childParentData.nextSibling;
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double width = 0.0;
    while (child != null) {
      final childParentData = child.parentData as BubbleParentData;
      width = math.max(width, child.getMaxIntrinsicWidth(height));
      child = childParentData.nextSibling;
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    RenderBox? child = firstChild;
    double height = 0.0;
    while (child != null) {
      final childParentData = child.parentData as BubbleParentData;
      height += child.getMinIntrinsicHeight(width);
      child = childParentData.nextSibling;
    }
    return height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    RenderBox? child = firstChild;
    double height = 0.0;
    while (child != null) {
      final childParentData = child.parentData as BubbleParentData;
      height += child.getMaxIntrinsicHeight(width);
      child = childParentData.nextSibling;
    }
    return height;
  }

  _BubbleContentMetrics _inspectContent(RenderBox root) {
    if (_hasBlockElement) {
      return const _BubbleContentMetrics(
        hasText: false,
        isSingleLine: false,
        lastCharRight: 0.0,
        lastCharBottom: 0.0,
        lastLineHeight: 0.0,
      );
    }

    RenderParagraph? firstParagraph;
    RenderParagraph? lastParagraph;
    int paragraphCount = 0;

    void visitor(RenderObject child) {
      if (child is RenderParagraph) {
        final text = child.text.toPlainText();
        if (text.trim().isNotEmpty) {
          firstParagraph ??= child;
          lastParagraph = child;
          paragraphCount++;
        }
      }
      child.visitChildren(visitor);
    }

    visitor(root);

    final targetParagraph = lastParagraph;
    if (targetParagraph == null) {
      return const _BubbleContentMetrics(
        hasText: false,
        isSingleLine: false,
        lastCharRight: 0.0,
        lastCharBottom: 0.0,
        lastLineHeight: 0.0,
      );
    }

    // Calculate offset of targetParagraph within root by walking up BoxParentData
    Offset offsetInRoot = Offset.zero;
    RenderObject current = targetParagraph;
    while (current != root && current.parent != null) {
      if (current.parentData is BoxParentData) {
        offsetInRoot += (current.parentData as BoxParentData).offset;
      }
      current = current.parent!;
    }

    final plainText = targetParagraph.text.toPlainText();
    final trimmed = plainText.trimRight();
    final int targetIndex = trimmed.isNotEmpty ? trimmed.length - 1 : plainText.length - 1;

    final boxes = targetParagraph.getBoxesForSelection(
      TextSelection(baseOffset: targetIndex, extentOffset: targetIndex + 1),
    );

    if (boxes.isEmpty) {
      return const _BubbleContentMetrics(
        hasText: false,
        isSingleLine: false,
        lastCharRight: 0.0,
        lastCharBottom: 0.0,
        lastLineHeight: 0.0,
      );
    }

    final lastBox = boxes.last;
    final double lastCharRight = offsetInRoot.dx + lastBox.right;
    final double lastCharBottom = offsetInRoot.dy + lastBox.bottom;
    final double lastLineHeight = lastBox.bottom - lastBox.top;

    bool isSingleLine = false;
    if (paragraphCount == 1 && offsetInRoot.dy < 2.0) {
      final firstBoxes = targetParagraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      if (firstBoxes.isNotEmpty) {
        final firstBox = firstBoxes.first;
        if ((lastBox.top - firstBox.top).abs() < 2.0) {
          isSingleLine = true;
        }
      } else {
        isSingleLine = true;
      }
    }

    return _BubbleContentMetrics(
      hasText: true,
      isSingleLine: isSingleLine,
      lastCharRight: lastCharRight,
      lastCharBottom: lastCharBottom,
      lastLineHeight: lastLineHeight,
    );
  }

  @override
  void performLayout() {
    RenderBox? senderName;
    RenderBox? reply;
    RenderBox? content;
    RenderBox? metadata;

    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as BubbleParentData;
      switch (childParentData.role) {
        case BubbleChildRole.senderName:
          senderName = child;
          break;
        case BubbleChildRole.reply:
          reply = child;
          break;
        case BubbleChildRole.content:
          content = child;
          break;
        case BubbleChildRole.metadata:
          metadata = child;
          break;
        case null:
          break;
      }
      child = childParentData.nextSibling;
    }

    if (content == null || metadata == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    const double gap = 4.0;
    const double senderSpacing = 2.0;
    const double replySpacing = 4.0;
    const double rowGap = 2.0;

    // 1. Measure senderName if present
    double senderNameHeight = 0.0;
    double measuredSenderWidth = 0.0;
    if (senderName != null) {
      senderName.layout(BoxConstraints(maxWidth: constraints.maxWidth), parentUsesSize: true);
      senderNameHeight = senderName.size.height + senderSpacing;
      measuredSenderWidth = senderName.size.width;
    }

    // 2. Measure content with loose constraints (unconstricted natural width up to maxWidth)
    content.layout(constraints.loosen(), parentUsesSize: true);
    final double contentWidth = content.size.width;
    final double contentHeight = content.size.height;

    // 3. Measure metadata unconstrained
    metadata.layout(const BoxConstraints(), parentUsesSize: true);
    final double metaWidth = math.max(metadata.size.width, _metadataWidth ?? 0.0);
    final double metaHeight = metadata.size.height;

    // 4. Header width baseline
    final double effectiveReplyWidth = replyWidth > 0.0
        ? replyWidth
        : (reply != null ? reply.getMinIntrinsicWidth(double.infinity) : 0.0);
    final double effectiveHeaderWidth = math.max(
      effectiveReplyWidth,
      senderName != null ? math.max(senderNameWidth, measuredSenderWidth) : 0.0,
    );

    // 5. Inspect content geometry
    final metrics = _inspectContent(content);

    double bubbleWidth;
    double bubbleHeight;
    double contentX = 0.0;
    double contentY = 0.0;
    double metaX = 0.0;
    double metaY = 0.0;

    if (metrics.hasText && metrics.isSingleLine) {
      // Case 1: Single line text
      final double neededWidth = metrics.lastCharRight + gap + metaWidth;
      if (neededWidth <= constraints.maxWidth) {
        // Fits inline with metadata
        bubbleWidth = math.min(
          constraints.maxWidth,
          math.max(effectiveHeaderWidth, math.max(contentWidth, neededWidth)),
        );
        final double lineContentHeight = math.max(contentHeight, metaHeight);
        contentX = 0.0;
        metaX = bubbleWidth - metaWidth;
        contentY = lineContentHeight - contentHeight;
        metaY = lineContentHeight - metaHeight;
        bubbleHeight = lineContentHeight;
      } else {
        // Single line too long to fit metadata inline -> row below
        bubbleWidth = math.min(
          constraints.maxWidth,
          math.max(effectiveHeaderWidth, math.max(contentWidth, metaWidth)),
        );
        contentX = 0.0;
        contentY = 0.0;
        metaX = bubbleWidth - metaWidth;
        metaY = contentHeight + rowGap;
        bubbleHeight = contentHeight + rowGap + metaHeight;
      }
    } else if (metrics.hasText) {
      // Case 2: Multi-line text
      final double lineHeight = metrics.lastLineHeight > 0 ? metrics.lastLineHeight : 20.0;
      final bool isAtBottom = (contentHeight - metrics.lastCharBottom) <= (lineHeight * 1.5 + 4.0);
      final bool canFitOnLastLine = isAtBottom && (metrics.lastCharRight + gap + metaWidth <= constraints.maxWidth);

      if (canFitOnLastLine) {
        final double neededWidth = metrics.lastCharRight + gap + metaWidth;
        bubbleWidth = math.min(
          constraints.maxWidth,
          math.max(effectiveHeaderWidth, math.max(contentWidth, neededWidth)),
        );
        contentX = 0.0;
        contentY = 0.0;
        metaX = bubbleWidth - metaWidth;
        metaY = math.min(contentHeight - metaHeight, math.max(0.0, metrics.lastCharBottom - metaHeight));
        bubbleHeight = contentHeight;
      } else {
        // Case 3: Does not fit on last line -> separate row below
        bubbleWidth = math.min(
          constraints.maxWidth,
          math.max(effectiveHeaderWidth, math.max(contentWidth, metaWidth)),
        );
        contentX = 0.0;
        contentY = 0.0;
        metaX = bubbleWidth - metaWidth;
        metaY = contentHeight + rowGap;
        bubbleHeight = contentHeight + rowGap + metaHeight;
      }
    } else {
      // Fallback: Non-text, block element, TeX, etc. -> separate row below
      bubbleWidth = math.min(
        constraints.maxWidth,
        math.max(effectiveHeaderWidth, math.max(contentWidth, metaWidth)),
      );
      contentX = 0.0;
      contentY = 0.0;
      metaX = bubbleWidth - metaWidth;
      metaY = contentHeight + rowGap;
      bubbleHeight = contentHeight + rowGap + metaHeight;
    }

    // 6. Layout reply with exact bubble width if present
    double replyHeight = 0.0;
    if (reply != null) {
      reply.layout(BoxConstraints.tightFor(width: bubbleWidth), parentUsesSize: true);
      replyHeight = reply.size.height + replySpacing;
    }

    final double headerHeight = senderNameHeight + replyHeight;
    bubbleHeight += headerHeight;
    contentY += headerHeight;
    metaY += headerHeight;

    size = constraints.constrain(Size(bubbleWidth, bubbleHeight));

    // 7. Assign child offsets
    if (senderName != null) {
      (senderName.parentData as BubbleParentData).offset = Offset.zero;
    }
    if (reply != null) {
      (reply.parentData as BubbleParentData).offset = Offset(0.0, senderNameHeight);
    }
    (content.parentData as BubbleParentData).offset = Offset(contentX, contentY);
    (metadata.parentData as BubbleParentData).offset = Offset(metaX, metaY);
  }
}

/// Custom layout widget for message bubble layout.
class MessageBubbleLayout extends StatelessWidget {
  final Widget content;
  final Widget metadata;
  final String? text;
  final TextStyle textStyle;
  final bool hasBlockElement;
  final bool isBigEmoji;
  final Widget? replyWidget;
  final double replyWidth;
  final Widget? senderNameWidget;
  final double senderNameWidth;
  final double? metadataWidth;

  const MessageBubbleLayout({
    Key? key,
    required this.content,
    required this.metadata,
    this.text,
    required this.textStyle,
    this.hasBlockElement = false,
    this.isBigEmoji = false,
    this.replyWidget,
    this.replyWidth = 0.0,
    this.senderNameWidget,
    this.senderNameWidth = 0.0,
    this.metadataWidth,
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

    return BubbleLayoutWidget(
      senderNameWidget: senderNameWidget,
      replyWidget: replyWidget,
      content: content,
      metadata: metadata,
      replyWidth: replyWidth,
      senderNameWidth: senderNameWidth,
      metadataWidth: metadataWidth,
      hasBlockElement: hasBlockElement,
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
  final Set<String>? myReactions;
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
    this.myReactions,
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
      height: 1.4,
      color: isBigEmoji
          ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
          : (isMe
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSecondaryContainer),
    );

    final bool endsWithBlock =
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
            padding: const EdgeInsets.only(top: 1.0),
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
    final double metadataWidthEstimate = _calculateMetadataWidth(context);

    // Prepare Reply Widget if present
    Widget? replyWidget;
    double replyWidthEstimate = 0.0;

    if (message.hasReply) {
      replyWidget = MessageReplyInfo(
        replyInfo: message.replyInfo,
        isQuote: message.isQuote,
        quoteText: message.quoteText,
        isMe: isMe,
        currentUserId: currentUserId,
        onTap: () => onReplyTap?.call(
          message.replyToMessageId!,
          message.replyInfo?.chatId,
        ),
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

    Widget? senderNameWidget;
    double senderNameWidthEstimate = 0.0;
    if (!isMe && senderName != null && senderName!.isNotEmpty) {
      final style = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      );
      final TextPainter senderNameTp = TextPainter(
        text: TextSpan(text: senderName!, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxBubbleWidth);
      senderNameWidthEstimate = senderNameTp.width;

      senderNameWidget = Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          senderName!,
          style: style,
        ),
      );
    }

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

    Widget? mediaContentWidget;
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
        mediaContentWidget = Column(
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
        mediaContentWidget = innerContent;
      }
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
      child: hasMedia
          ? mediaContentWidget!
          : MessageBubbleLayout(
              content: textBodyWidget,
              metadata: metadataWidget,
              text: message.content,
              textStyle: textStyle,
              hasBlockElement: endsWithBlock,
              isBigEmoji: isBigEmoji,
              replyWidget: replyWidget,
              replyWidth: replyWidthEstimate,
              senderNameWidget: senderNameWidget,
              senderNameWidth: senderNameWidthEstimate,
              metadataWidth: metadataWidthEstimate,
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
    final effectiveReactions = reactions ?? (message.reactions.isNotEmpty ? message.reactions : null);
    if (effectiveReactions != null && effectiveReactions.isNotEmpty) {
      final effectiveMyReactions = myReactions ?? (myReaction != null && myReaction!.isNotEmpty ? {myReaction!} : message.myReactions);
      result = Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          result,
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 12, right: 12),
            child: MessageReactionsRow(
              reactions: effectiveReactions,
              myReactions: effectiveMyReactions,
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

  double _calculateMetadataWidth(BuildContext context) {
    double width = 0.0;
    if (message.isEdited) {
      final editedText = context.l10n.translate('chat_edited');
      final tp = TextPainter(
        text: TextSpan(
          text: editedText,
          style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      width += tp.width + 4.0;
    }

    final timeStr = formatTime(message.createdAt);
    final timeTp = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    width += timeTp.width;

    if (isMe) {
      width += 4.0;
      if (message.sendStatus == 0) {
        width += 10.0;
      } else if (message.sendStatus == 2) {
        width += 14.0;
      } else {
        width += 15.0; // iconoir Check or DoubleCheck width
      }
    }

    return width.ceilToDouble();
  }
}

