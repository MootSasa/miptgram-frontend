import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;

/// Widget for displaying photo and video message previews.
class MediaMessageWidget extends StatelessWidget {
  final String mediaType; // 'photo' or 'video'
  final String url; // URL to the media file
  final String? thumbnailUrl; // Optional thumbnail URL for videos
  final VoidCallback? onTap; // Callback when the media is tapped

  const MediaMessageWidget({
    Key? key,
    required this.mediaType,
    required this.url,
    this.thumbnailUrl,
    this.onTap,
  }) : super(key: key);

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: iconoir.MediaImage(
                width: 40,
                height: 40,
                color: Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPreview() {
    final String thumbnail = thumbnailUrl ?? url;
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            thumbnail,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: iconoir.MediaVideo(
                    width: 40,
                    height: 40,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
        const iconoir.Play(
          color: Colors.white70,
          width: 50,
          height: 50,
        ),
      ],
    );
  }
}