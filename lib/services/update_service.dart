import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Модель данных о доступном обновлении
class AppUpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final int latestBuild;
  final int minSupportedBuild;
  final bool forceUpdate;
  final String downloadUrl;
  final int apkSizeBytes;
  final String sha256;
  final String releaseNotes;
  final String architecture;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.latestBuild,
    required this.minSupportedBuild,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.apkSizeBytes,
    required this.sha256,
    required this.releaseNotes,
    this.architecture = 'universal',
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final hasUpdateRaw = json['has_update'] as bool? ?? false;
    final forceUpdateRaw = json['force_update'] as bool? ?? false;
    return AppUpdateInfo(
      hasUpdate: hasUpdateRaw || forceUpdateRaw,
      latestVersion: json['latest_version'] as String? ?? '',
      latestBuild: (json['latest_build'] as num?)?.toInt() ?? 0,
      minSupportedBuild: (json['min_supported_build'] as num?)?.toInt() ?? 1,
      forceUpdate: forceUpdateRaw,
      downloadUrl: json['download_url'] as String? ?? '',
      apkSizeBytes: (json['apk_size_bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      architecture: json['architecture'] as String? ?? 'universal',
    );
  }

  factory AppUpdateInfo.noUpdate() {
    return const AppUpdateInfo(
      hasUpdate: false,
      latestVersion: '',
      latestBuild: 0,
      minSupportedBuild: 1,
      forceUpdate: false,
      downloadUrl: '',
      apkSizeBytes: 0,
      sha256: '',
      releaseNotes: '',
      architecture: 'universal',
    );
  }

  String get formattedSize {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Сервис проверки, загрузки и запуска установки обновлений
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String prefAutoCheckKey = 'auto_check_updates';
  static const String prefIgnoredBuildKey = 'ignored_update_build';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  /// Включена ли авто-проверка обновлений
  Future<bool> isAutoCheckEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefAutoCheckKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Сохранить настройку авто-проверки
  Future<void> setAutoCheckEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefAutoCheckKey, enabled);
    } catch (e) {
      debugPrint('[AppUpdateService] Error saving auto check: $e');
    }
  }

  /// Текущий номер сборки приложения
  Future<int> getCurrentBuildNumber() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? AppConfig.appBuildNumber;
    } catch (_) {
      return AppConfig.appBuildNumber;
    }
  }

  /// Текущая версия приложения (например, 1.0.0)
  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.isNotEmpty ? info.version : AppConfig.appVersion;
    } catch (_) {
      return AppConfig.appVersion;
    }
  }

  /// Текущая платформа для запроса обновлений
  String getPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return defaultTargetPlatform.name.toLowerCase();
  }

  /// Определение аппаратной архитектуры процессора устройства
  Future<String> getArchitecture() async {
    if (kIsWeb) return 'universal';

    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final abis = androidInfo.supportedAbis;
        if (abis.isNotEmpty) {
          final primary = abis.first.toLowerCase();
          if (primary.contains('arm64') || primary.contains('aarch64') || primary.contains('v8a')) {
            return 'arm64-v8a';
          } else if (primary.contains('armeabi-v7a') || primary.contains('armv7')) {
            return 'armeabi-v7a';
          } else if (primary.contains('x86_64') || primary.contains('amd64')) {
            return 'x86_64';
          } else if (primary.contains('x86')) {
            return 'x86';
          }
          return primary;
        }
      } else if (Platform.isWindows) {
        final archEnv = Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ?? '';
        final archW6432 = Platform.environment['PROCESSOR_ARCHITEW6432']?.toLowerCase() ?? '';
        if (archEnv.contains('arm64') || archW6432.contains('arm64')) {
          return 'arm64';
        }
        if (archEnv.contains('amd64') || archEnv.contains('x64') || archW6432.contains('amd64')) {
          return 'x64';
        }
        if (archEnv.contains('x86')) {
          return 'x86';
        }
      } else if (Platform.isMacOS) {
        final v = Platform.version.toLowerCase();
        if (v.contains('arm64') || v.contains('aarch64')) return 'arm64';
        if (v.contains('x64') || v.contains('x86_64')) return 'x86_64';
      } else if (Platform.isLinux) {
        final v = Platform.version.toLowerCase();
        if (v.contains('arm64') || v.contains('aarch64')) return 'arm64';
        if (v.contains('x64') || v.contains('x86_64') || v.contains('amd64')) return 'x86_64';
        if (v.contains('arm')) return 'armv7l';
      } else if (Platform.isIOS) {
        return 'arm64';
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to detect architecture: $e');
    }

    // Fallback based on Platform.version
    try {
      final v = Platform.version.toLowerCase();
      if (v.contains('arm64') || v.contains('aarch64')) return 'arm64';
      if (v.contains('x64') || v.contains('x86_64') || v.contains('amd64')) return 'x86_64';
    } catch (_) {}

    return 'universal';
  }

  /// Запросить информацию о наличии обновления на сервере
  Future<AppUpdateInfo> checkForUpdate({bool silent = false}) async {
    try {
      final platform = getPlatform();
      final arch = await getArchitecture();
      final currentBuild = await getCurrentBuildNumber();
      final currentVer = await getCurrentVersion();

      final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final url = '$baseUrl/api/app/check-update';

      final response = await _dio.get(
        url,
        queryParameters: {
          'platform': platform,
          'arch': arch,
          'build_number': currentBuild,
          'version': currentVer,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final updateInfo = AppUpdateInfo.fromJson(data);

        // Если это тихая проверка при запуске, проверяем не скрыл ли пользователь этот билд
        if (silent && !updateInfo.forceUpdate) {
          final prefs = await SharedPreferences.getInstance();
          final ignoredBuild = prefs.getInt(prefIgnoredBuildKey) ?? 0;
          if (ignoredBuild >= updateInfo.latestBuild) {
            return AppUpdateInfo.noUpdate();
          }
        }

        return updateInfo;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Check for update failed: $e');
    }

    return AppUpdateInfo.noUpdate();
  }

  /// Пропустить / игнорировать этот номер сборки при авто-проверках
  Future<void> ignoreBuild(int buildNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefIgnoredBuildKey, buildNumber);
    } catch (_) {}
  }

  /// Скачать файл APK во временную директорию
  Future<File?> downloadApk({
    required String downloadUrl,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/miptgram_update.apk';
      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] APK download failed: $e');
      rethrow;
    }
    return null;
  }

  /// Запустить установщик пакета через Android Intent
  Future<OpenResult> installApk(String filePath) async {
    return await OpenFile.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
  }
}
