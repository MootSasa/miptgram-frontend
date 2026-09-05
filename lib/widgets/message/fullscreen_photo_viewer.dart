import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:photo_view/photo_view.dart';

/// Full-screen photo viewer with pinch-to-zoom and swipe-to-dismiss
class FullscreenPhotoViewer extends StatelessWidget {
  final String url;
  final String? tag;

  const FullscreenPhotoViewer({
    Key? key,
    required this.url,
    this.tag,
  }) : super(key: key);

  /// Open the viewer as a full-screen dialog
  static Future<void> open(BuildContext context, String url, {String? tag}) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenPhotoViewer(url: url, tag: tag),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: const iconoir.Xmark(color: Colors.white, width: 24, height: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Swipe down to dismiss
          if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
            Navigator.pop(context);
          }
        },
        child: PhotoView(
          imageProvider: _imageProvider(),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          heroAttributes: tag != null ? PhotoViewHeroAttributes(tag: tag!) : null,
          loadingBuilder: (context, event) => Center(
            child: CircularProgressIndicator(
              value: event?.cumulativeBytesLoaded != null &&
                      event?.expectedTotalBytes != null
                  ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          ),
          errorBuilder: (context, error, stackTrace) => const Center(
            child: iconoir.MediaImage(color: Colors.white54, width: 64, height: 64),
          ),
        ),
      ),
    );
  }

  ImageProvider _imageProvider() {
    // Support data: URLs (base64)
    if (url.startsWith('data:')) {
      try {
        final commaIndex = url.indexOf(',');
        final base64Str = url.substring(commaIndex + 1);
        final bytes = Uri.parse('data:;base64,$base64Str')
            .data!
            .contentAsBytes();
        return MemoryImage(bytes);
      } catch (_) {
        return NetworkImage(url);
      }
    }
    if (url.startsWith('file://')) {
      return FileImage(File(url.replaceFirst('file://', '')));
    }
    if (url.startsWith('/') && !url.startsWith('//')) {
      return FileImage(File(url));
    }
    return NetworkImage(url);
  }
}
