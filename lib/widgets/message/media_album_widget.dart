import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import '../../config/app_config.dart';
import '../../models/media_album.dart';
import '../../services/database/app_database.dart';
import '../../services/media_cache_manager.dart';
import 'blurred_media_placeholder.dart';
import 'media_album_layout.dart';
import 'media_album_viewer.dart';
import 'media_download_button.dart';

/// Widget rendering a Telegram-style collage bubble for 2–10 media items.
class MediaAlbumWidget extends StatelessWidget {
  final MediaAlbum album;
  final bool isMe;
  final String currentUserId;
  final String? chatType;
  final String? senderName;
  final String Function(String)? formatTime;
  final Function(String url, String name, String type)? onFileTap;

  const MediaAlbumWidget({
    Key? key,
    required this.album,
    required this.isMe,
    required this.currentUserId,
    this.chatType,
    this.senderName,
    this.formatTime,
    this.onFileTap,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaAlbumViewer(
          album: album,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final albumWidth = (screenWidth * 0.76).clamp(240.0, 380.0);
    // Dynamic height based on count
    final albumHeight = album.items.length <= 2
        ? albumWidth * 0.72
        : (album.items.length <= 4 ? albumWidth * 0.88 : albumWidth * 1.05);

    final positions = MediaAlbumLayoutCalculator.computePositions(
      items: album.items,
      totalWidth: albumWidth,
      totalHeight: albumHeight,
      isMe: isMe,
    );

    final theme = Theme.of(context);
    final bubbleColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.secondaryContainer;
    final onBubbleColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      width: albumWidth,
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe && senderName != null && senderName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Text(
                senderName!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // 1. Mosaic Collage Container
          SizedBox(
            width: albumWidth,
            height: albumHeight,
            child: Stack(
              children: [
                for (int i = 0; i < positions.length; i++)
                  _buildTile(context, album.items[i], positions[i], i),

                // Floating time pill if captionless
                if (!album.hasCaption)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getTimeString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 3),
                            _buildStatusIcon(),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Caption Text & Meta (if present)
          if (album.hasCaption)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.caption!,
                    style: TextStyle(
                      color: onBubbleColor,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _getTimeString(),
                        style: TextStyle(
                          color: onBubbleColor.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(color: onBubbleColor),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    MediaAlbumItem item,
    AlbumTilePosition pos,
    int index,
  ) {
    final rawUrl = item.fileUrl ?? '';
    final resolvedUrl = AppConfig.resolveMediaUrl(rawUrl) ?? rawUrl;
    final autoDownload = MediaCacheManager.instance.shouldAutoDownload(
      messageType: item.messageType,
      fileSize: item.fileSize,
    );

    return Positioned(
      left: pos.left,
      top: pos.top,
      width: pos.width,
      height: pos.height,
      child: ClipRRect(
        borderRadius: pos.borderRadius,
        child: GestureDetector(
          onTap: () => _openViewer(context, index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Blurred placeholder
              BlurredMediaPlaceholder(
                thumbBase64: item.thumbBase64,
                aspectRatio: item.aspectRatio,
              ),

              // 2. Full network image (if auto-download or photo)
              if (resolvedUrl.isNotEmpty && (autoDownload || !item.isVideo))
                Image.network(
                  resolvedUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 600,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return BlurredMediaPlaceholder(
                      thumbBase64: item.thumbBase64,
                      aspectRatio: item.aspectRatio,
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),

              // 3. Download button / progress / size pill
              if (resolvedUrl.isNotEmpty)
                MediaDownloadButton(
                  url: resolvedUrl,
                  fileSize: item.fileSize,
                  isVideo: item.isVideo,
                  onPlayVideo: () => _openViewer(context, index),
                ),

              // 4. Video duration badge (top-left)
              if (item.isVideo)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const iconoir.Play(
                          color: Colors.white,
                          width: 10,
                          height: 10,
                        ),
                        if (item.duration != null && item.duration! > 0) ...[
                          const SizedBox(width: 3),
                          Text(
                            _formatDuration(item.duration!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeString() {
    try {
      if (formatTime != null) return formatTime!(album.createdAt);
      final dt = DateTime.parse(album.createdAt);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  Widget _buildStatusIcon({Color color = Colors.white}) {
    if (album.sendStatus == MessageSendStatus.sending.index) {
      return Icon(Icons.access_time, size: 12, color: color);
    }
    if (album.sendStatus == MessageSendStatus.failed.index) {
      return const Icon(Icons.error_outline, size: 12, color: Colors.redAccent);
    }
    if (album.isRead) {
      return Icon(Icons.done_all, size: 13, color: color);
    }
    return Icon(Icons.done, size: 13, color: color);
  }
}
