import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import '../../config/app_config.dart';
import 'blurred_media_placeholder.dart';
import 'media_download_button.dart';

/// Widget for displaying photo and video message previews with blurred
/// preview placeholder, managed progressive download, and size pill.
class MediaMessageWidget extends StatelessWidget {
  final String mediaType; // 'photo' or 'video'
  final String url; // URL to the media file
  final String? thumbnailUrl; // Optional thumbnail URL for videos
  final String? thumbBase64;
  final int? fileSize;
  final int? duration;
  final double? aspectRatio;
  final VoidCallback? onTap; // Callback when the media is tapped

  const MediaMessageWidget({
    Key? key,
    required this.mediaType,
    required this.url,
    this.thumbnailUrl,
    this.thumbBase64,
    this.fileSize,
    this.duration,
    this.aspectRatio,
    this.onTap,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _buildMediaPreview(),
    );
  }

  Widget _buildMediaPreview() {
    switch (mediaType) {
      case 'photo':
        return _buildImagePreview();
      case 'video':
        return _buildVideoPreview();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImagePreview() {
    final resolvedUrl = AppConfig.resolveMediaUrl(url) ?? url;
    final ratio = aspectRatio ?? 1.33;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Blurred preview placeholder
            BlurredMediaPlaceholder(
              thumbBase64: thumbBase64,
              aspectRatio: ratio,
            ),

            // 2. Full network image
            if (resolvedUrl.isNotEmpty)
              Image.network(
                resolvedUrl,
                cacheWidth: 800,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return BlurredMediaPlaceholder(
                    thumbBase64: thumbBase64,
                    aspectRatio: ratio,
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: iconoir.MediaImage(
                        width: 40,
                        height: 40,
                        color: Colors.white60,
                      ),
                    ),
                  );
                },
              ),

            // 3. Download button with size pill if needed
            if (resolvedUrl.isNotEmpty)
              MediaDownloadButton(
                url: resolvedUrl,
                fileSize: fileSize,
                isVideo: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    final String targetUrl = thumbnailUrl ?? url;
    final resolvedUrl = AppConfig.resolveMediaUrl(targetUrl) ?? targetUrl;
    final ratio = aspectRatio ?? 1.33;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Blurred preview placeholder
            BlurredMediaPlaceholder(
              thumbBase64: thumbBase64,
              aspectRatio: ratio,
            ),

            // 2. Video thumbnail
            if (resolvedUrl.isNotEmpty)
              Image.network(
                resolvedUrl,
                cacheWidth: 800,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return BlurredMediaPlaceholder(
                    thumbBase64: thumbBase64,
                    aspectRatio: ratio,
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: iconoir.MediaVideo(
                        width: 40,
                        height: 40,
                        color: Colors.white60,
                      ),
                    ),
                  );
                },
              ),

            // 3. Download button with size pill & play button
            if (resolvedUrl.isNotEmpty)
              MediaDownloadButton(
                url: resolvedUrl,
                fileSize: fileSize,
                isVideo: true,
                onPlayVideo: onTap,
              ),

            // 4. Video duration pill in top-left
            if (duration != null && duration! > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const iconoir.Play(
                        color: Colors.white,
                        width: 10,
                        height: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(duration!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}