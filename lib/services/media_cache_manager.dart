import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Manager for downloading and caching media files with progress tracking,
/// cancel capability, and auto-download policy checks.
class MediaCacheManager {
  static final MediaCacheManager instance = MediaCacheManager._internal();
  MediaCacheManager._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
  ));

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, ValueNotifier<double>> _progressNotifiers = {};
  final Map<String, String> _localPathCache = {};

  /// Formats byte count into human-readable string (e.g. 14.2 MB)
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Get or create a ValueNotifier for tracking download progress of a URL (0.0 - 1.0)
  ValueNotifier<double> getProgressNotifier(String url) {
    return _progressNotifiers.putIfAbsent(url, () => ValueNotifier<double>(0.0));
  }

  bool isDownloading(String url) {
    return _cancelTokens.containsKey(url);
  }

  /// Cancel an ongoing download
  void cancelDownload(String url) {
    final token = _cancelTokens.remove(url);
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled');
    }
    final notifier = _progressNotifiers[url];
    if (notifier != null) {
      notifier.value = 0.0;
    }
  }

  /// Checks if the file is cached locally on disk and exists
  Future<File?> getCachedFile(String url) async {
    if (url.isEmpty) return null;
    final cachedPath = _localPathCache[url];
    if (cachedPath != null) {
      final f = File(cachedPath);
      if (await f.exists()) return f;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitized = url.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final targetPath = path.join(dir.path, 'miptgram_media', sanitized);
      final f = File(targetPath);
      if (await f.exists() && (await f.length()) > 0) {
        _localPathCache[url] = targetPath;
        return f;
      }
    } catch (_) {}
    return null;
  }

  /// Download a media file to local cache with progress tracking
  Future<File?> downloadMedia(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    if (url.isEmpty) return null;

    final existing = await getCachedFile(url);
    if (existing != null) {
      return existing;
    }

    if (_cancelTokens.containsKey(url)) {
      // Already downloading
      return null;
    }

    final cancelToken = CancelToken();
    _cancelTokens[url] = cancelToken;
    final notifier = getProgressNotifier(url);
    notifier.value = 0.01;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(path.join(dir.path, 'miptgram_media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final sanitized = url.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final targetPath = path.join(mediaDir.path, sanitized);
      final tempPath = '$targetPath.tmp';

      final resolvedUrl = AppConfig.resolveMediaUrl(url) ?? url;
      final token = await AuthService.getToken();

      await _dio.download(
        resolvedUrl,
        tempPath,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            notifier.value = progress;
            onProgress?.call(progress);
          }
        },
      );

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        final finalFile = await tempFile.rename(targetPath);
        _localPathCache[url] = targetPath;
        notifier.value = 1.0;
        return finalFile;
      }
    } catch (e) {
      if (cancelToken.isCancelled) {
        debugPrint('Media download cancelled for: $url');
      } else {
        debugPrint('Media download error for $url: $e');
      }
    } finally {
      _cancelTokens.remove(url);
    }
    return null;
  }

  /// Evaluates whether media should auto-download based on type and size
  bool shouldAutoDownload({
    required String messageType,
    int? fileSize,
    bool isWifi = true,
  }) {
    // Default Telegram rules:
    // Photos: auto-download if <= 10MB
    // Videos: auto-download if <= 15MB on Wi-Fi, 5MB on mobile
    // Documents: manual download by default unless < 1MB
    final size = fileSize ?? 0;
    if (messageType == 'photo' || messageType == 'image') {
      return size <= 10 * 1024 * 1024;
    }
    if (messageType == 'video') {
      return isWifi ? size <= 15 * 1024 * 1024 : size <= 5 * 1024 * 1024;
    }
    return size <= 1024 * 1024;
  }
}
