import 'package:flutter/material.dart';

/// Download button overlay for media messages when auto-download is disabled
class MediaDownloadButton extends StatelessWidget {
  final String fileName;
  final String fileSize;
  final VoidCallback onDownload;
  final bool isVideo;

  const MediaDownloadButton({
    Key? key,
    required this.fileName,
    required this.fileSize,
    required this.onDownload,
    this.isVideo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onDownload,
      child: Container(
        width: 220,
        height: 180,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0088CC).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.videocam : Icons.photo,
                color: const Color(0xFF0088CC),
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            // File name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                fileName,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            // File size + download hint
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_rounded, size: 14, color: const Color(0xFF0088CC)),
                const SizedBox(width: 4),
                Text(
                  fileSize,
                  style: const TextStyle(
                    color: Color(0xFF0088CC),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
