import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:video_player/video_player.dart';
import '../../config/app_config.dart';
import '../../models/media_album.dart';
import 'blurred_media_placeholder.dart';

/// Fullscreen multi-media viewer for albums with swipe navigation,
/// video streaming playback, and bottom thumbnail strip.
class MediaAlbumViewer extends StatefulWidget {
  final MediaAlbum album;
  final int initialIndex;

  const MediaAlbumViewer({
    Key? key,
    required this.album,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MediaAlbumViewer> createState() => _MediaAlbumViewerState();
}

class _MediaAlbumViewerState extends State<MediaAlbumViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.album.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _initVideoIfNeeded(_currentIndex);
  }

  void _initVideoIfNeeded(int index) {
    if (index < 0 || index >= widget.album.items.length) return;
    final item = widget.album.items[index];
    if (item.isVideo && !_videoControllers.containsKey(index)) {
      final rawUrl = item.fileUrl ?? '';
      final resolvedUrl = AppConfig.resolveMediaUrl(rawUrl) ?? rawUrl;
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(resolvedUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoControllers[index] = controller;
      controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
          controller.play();
        }
      });
    }
  }

  void _onPageChanged(int index) {
    // Pause previous video if any
    final prev = _videoControllers[_currentIndex];
    if (prev != null && prev.value.isPlaying) {
      prev.pause();
    }

    setState(() {
      _currentIndex = index;
    });

    _initVideoIfNeeded(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.album.items;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Page view for media items
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isVideo) {
                return _buildVideoItem(item, index);
              } else {
                return _buildPhotoItem(item);
              }
            },
          ),

          // 2. Top app bar with back button and counter
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const iconoir.ArrowLeft(
                        color: Colors.white,
                        width: 24,
                        height: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_currentIndex + 1} / ${items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),

          // 3. Bottom thumbnail navigation strip and caption
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.album.hasCaption) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          widget.album.caption!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    SizedBox(
                      height: 54,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected = index == _currentIndex;
                          final rawUrl = item.fileUrl ?? '';
                          final resolvedUrl =
                              AppConfig.resolveMediaUrl(rawUrl) ?? rawUrl;

                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    BlurredMediaPlaceholder(
                                      thumbBase64: item.thumbBase64,
                                    ),
                                    if (resolvedUrl.isNotEmpty)
                                      Image.network(
                                        resolvedUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    if (item.isVideo)
                                      const Center(
                                        child: iconoir.Play(
                                          color: Colors.white,
                                          width: 14,
                                          height: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoItem(MediaAlbumItem item) {
    final rawUrl = item.fileUrl ?? '';
    final resolvedUrl = AppConfig.resolveMediaUrl(rawUrl) ?? rawUrl;

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 3.5,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            BlurredMediaPlaceholder(
              thumbBase64: item.thumbBase64,
              aspectRatio: item.aspectRatio,
            ),
            if (resolvedUrl.isNotEmpty)
              Image.network(
                resolvedUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return BlurredMediaPlaceholder(
                    thumbBase64: item.thumbBase64,
                    aspectRatio: item.aspectRatio,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoItem(MediaAlbumItem item, int index) {
    final controller = _videoControllers[index];
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            BlurredMediaPlaceholder(
              thumbBase64: item.thumbBase64,
              aspectRatio: item.aspectRatio,
            ),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            GestureDetector(
              onTap: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: iconoir.Play(
                      color: Colors.white,
                      width: 32,
                      height: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
