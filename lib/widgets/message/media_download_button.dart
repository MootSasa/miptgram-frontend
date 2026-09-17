import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import '../../services/media_cache_manager.dart';

/// Interactive Telegram-style download button for media files.
/// Displays file size pill (e.g. 14.2 MB), animated circular progress,
/// and cancel button during active download.
class MediaDownloadButton extends StatefulWidget {
  final String url;
  final int? fileSize;
  final bool isVideo;
  final VoidCallback? onDownloaded;
  final VoidCallback? onPlayVideo;

  const MediaDownloadButton({
    Key? key,
    required this.url,
    this.fileSize,
    this.isVideo = false,
    this.onDownloaded,
    this.onPlayVideo,
  }) : super(key: key);

  @override
  State<MediaDownloadButton> createState() => _MediaDownloadButtonState();
}

class _MediaDownloadButtonState extends State<MediaDownloadButton>
    with SingleTickerProviderStateMixin {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  ValueNotifier<double>? _notifier;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void didUpdateWidget(covariant MediaDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final cached = await MediaCacheManager.instance.getCachedFile(widget.url);
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
      });
      return;
    }

    final downloading = MediaCacheManager.instance.isDownloading(widget.url);
    _notifier = MediaCacheManager.instance.getProgressNotifier(widget.url);
    _notifier?.removeListener(_onProgressListener);
    _notifier?.addListener(_onProgressListener);

    setState(() {
      _isDownloaded = false;
      _isDownloading = downloading;
      _progress = _notifier?.value ?? 0.0;
    });
  }

  void _onProgressListener() {
    if (!mounted) return;
    final val = _notifier?.value ?? 0.0;
    setState(() {
      _progress = val;
      _isDownloading = val > 0.0 && val < 1.0;
      if (val >= 1.0) {
        _isDownloaded = true;
        widget.onDownloaded?.call();
      }
    });
  }

  @override
  void dispose() {
    _notifier?.removeListener(_onProgressListener);
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.01;
    });

    final file = await MediaCacheManager.instance.downloadMedia(
      widget.url,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _progress = p;
          });
        }
      },
    );

    if (!mounted) return;
    if (file != null) {
      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
      });
      widget.onDownloaded?.call();
    } else {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _cancelDownload() {
    MediaCacheManager.instance.cancelDownload(widget.url);
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloaded && !widget.isVideo) {
      // Photo is downloaded; no button needed over it
      return const SizedBox.shrink();
    }

    final sizeText = widget.fileSize != null && widget.fileSize! > 0
        ? MediaCacheManager.formatBytes(widget.fileSize!)
        : '';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isDownloading) {
              _cancelDownload();
            } else if (_isDownloaded && widget.isVideo) {
              widget.onPlayVideo?.call();
            } else {
              _startDownload();
            }
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isDownloading) ...[
                        CircularProgressIndicator(
                          value: _progress.clamp(0.05, 1.0),
                          strokeWidth: 2.5,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.2),
                        ),
                        const iconoir.Xmark(
                          color: Colors.white,
                          width: 14,
                          height: 14,
                        ),
                      ] else if (_isDownloaded && widget.isVideo) ...[
                        const iconoir.Play(
                          color: Colors.white,
                          width: 18,
                          height: 18,
                        ),
                      ] else ...[
                        const iconoir.ArrowDown(
                          color: Colors.white,
                          width: 18,
                          height: 18,
                        ),
                      ],
                    ],
                  ),
                ),
                if (sizeText.isNotEmpty && !_isDownloaded) ...[
                  const SizedBox(width: 6),
                  Text(
                    sizeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
