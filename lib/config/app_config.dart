import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppConfig provides centralized 4-tier dynamic configuration for the application:
/// 1. SharedPreferences runtime override (custom_server_url / custom_api_url)
/// 2. Web Uri.base auto-discovery when running on Flutter Web (kIsWeb)
/// 3. Compile-time --dart-define / String.fromEnvironment constants
/// 4. Built-in default fallback URLs
///
/// Usage:
/// ```dart
/// import 'package:miptgram/config/app_config.dart';
///
/// final url = '${AppConfig.baseUrl}/api/endpoint';
/// ```
class AppConfig {
  AppConfig._();

  // ============================================
  // SharedPreferences Keys
  // ============================================
  static const String prefCustomApiUrlKey = 'custom_api_url';
  static const String prefCustomServerUrlKey = 'custom_server_url';
  static const String prefCustomWsUrlKey = 'custom_ws_url';
  static const String prefCustomStorageUrlKey = 'custom_storage_url';
  static const String prefCustomWebUrlKey = 'custom_web_url';

  // ============================================
  // Tier 3: Compile-Time Environment Constants
  // ============================================
  static const String envApiUrl = String.fromEnvironment('API_BASE_URL');
  static const String envWsUrl = String.fromEnvironment('WS_BASE_URL');
  static const String envStorageUrl = String.fromEnvironment('STORAGE_BASE_URL');
  static const String envWebUrl = String.fromEnvironment('WEB_BASE_URL');
  static const bool envIsProduction = bool.fromEnvironment('IS_PRODUCTION', defaultValue: true);

  // ============================================
  // Tier 4: Built-in Defaults
  // ============================================
  static const String defaultProdApiBaseUrl = 'https://api.miptgram.ru';
  static const String defaultProdStorageBaseUrl = 'https://storage.miptgram.ru';
  static const String defaultProdWsBaseUrl = 'wss://api.miptgram.ru/api/ws';
  static const String defaultProdWebBaseUrl = 'https://miptgram.ru';

  static const String defaultDevApiBaseUrl = 'http://localhost:8080';
  static const String defaultDevStorageBaseUrl = 'http://localhost:9000';
  static const String defaultDevWsBaseUrl = 'ws://localhost:8080/api/ws';
  static const String defaultDevWebBaseUrl = 'http://localhost:3000';

  // Backwards compatibility constants
  static const bool isProduction = envIsProduction;
  static const String devApiBaseUrl = defaultDevApiBaseUrl;
  static const String prodApiBaseUrl = defaultProdApiBaseUrl;
  static const String devStorageBaseUrl = defaultDevStorageBaseUrl;
  static const String prodStorageBaseUrl = defaultProdStorageBaseUrl;

  // ============================================
  // Runtime State (Tier 1 & Tier 2)
  // ============================================
  static String? _customApiUrl;
  static String? _customWsUrl;
  static String? _customStorageUrl;
  static String? _customWebUrl;

  static String? _webDiscoveredApiUrl;
  static String? _webDiscoveredWsUrl;
  static String? _webDiscoveredStorageUrl;
  static String? _webDiscoveredWebUrl;

  static bool _initialized = false;

  /// Whether AppConfig.init() has been executed.
  static bool get isInitialized => _initialized;

  /// Initializes AppConfig by loading SharedPreferences overrides and
  /// auto-discovering Web host configuration if running on Flutter Web.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customApiUrl = _cleanUrl(prefs.getString(prefCustomApiUrlKey) ?? prefs.getString(prefCustomServerUrlKey));
      _customWsUrl = _cleanUrl(prefs.getString(prefCustomWsUrlKey));
      _customStorageUrl = _cleanUrl(prefs.getString(prefCustomStorageUrlKey));
      _customWebUrl = _cleanUrl(prefs.getString(prefCustomWebUrlKey));

      if (kIsWeb) {
        _discoverWebUrls();
      }

      // Automatically load dynamic package info from platform (pubspec.yaml)
      try {
        final info = await PackageInfo.fromPlatform();
        if (info.version.isNotEmpty) {
          _currentVersion = info.version;
        }
        final b = int.tryParse(info.buildNumber);
        if (b != null && b > 0) {
          _currentBuildNumber = b;
        }
      } catch (_) {}

      _initialized = true;
      debugPrint('[AppConfig] Initialized - API: $baseUrl, WS: $wsUrl, Storage: $storageUrl, Web: $webBaseUrl, Version: $_currentVersion (#$_currentBuildNumber)');
    } catch (e) {
      debugPrint('[AppConfig] Initialization error: $e');
    }
  }

  /// Sets or clears a custom server/API override at runtime and saves to SharedPreferences.
  static Future<void> setCustomServerUrl(String? customUrl) async {
    final cleaned = _cleanUrl(customUrl);
    _customApiUrl = cleaned;
    _customWsUrl = cleaned != null ? deriveWsUrl(cleaned) : null;
    _customStorageUrl = cleaned != null ? deriveStorageUrl(cleaned) : null;

    final prefs = await SharedPreferences.getInstance();
    if (cleaned != null && cleaned.isNotEmpty) {
      await prefs.setString(prefCustomApiUrlKey, cleaned);
      await prefs.setString(prefCustomServerUrlKey, cleaned);
      await prefs.setString(prefCustomWsUrlKey, _customWsUrl!);
      await prefs.setString(prefCustomStorageUrlKey, _customStorageUrl!);
    } else {
      await prefs.remove(prefCustomApiUrlKey);
      await prefs.remove(prefCustomServerUrlKey);
      await prefs.remove(prefCustomWsUrlKey);
      await prefs.remove(prefCustomStorageUrlKey);
      await prefs.remove(prefCustomWebUrlKey);
      _customWsUrl = null;
      _customStorageUrl = null;
      _customWebUrl = null;
    }
  }

  /// Resets all custom server overrides back to defaults.
  static Future<void> resetToDefaults() async {
    await setCustomServerUrl(null);
  }

  // ============================================
  // URL Getters (4-Tier Precedence)
  // ============================================

  /// Active API Base URL (e.g. `https://api.miptgram.ru` or `http://192.168.1.50:8080`)
  static String get baseUrl {
    if (_customApiUrl != null && _customApiUrl!.isNotEmpty) {
      return _customApiUrl!;
    }
    if (kIsWeb && _webDiscoveredApiUrl != null && _webDiscoveredApiUrl!.isNotEmpty) {
      return _webDiscoveredApiUrl!;
    }
    if (envApiUrl.isNotEmpty) {
      return _cleanUrl(envApiUrl)!;
    }
    return isProduction ? defaultProdApiBaseUrl : defaultDevApiBaseUrl;
  }

  /// Active WebSocket URL (e.g. `wss://api.miptgram.ru/api/ws` or `ws://192.168.1.50:8080/api/ws`)
  static String get wsUrl {
    if (_customWsUrl != null && _customWsUrl!.isNotEmpty) {
      return _customWsUrl!;
    }
    if (_customApiUrl != null && _customApiUrl!.isNotEmpty) {
      return deriveWsUrl(_customApiUrl!);
    }
    if (kIsWeb && _webDiscoveredWsUrl != null && _webDiscoveredWsUrl!.isNotEmpty) {
      return _webDiscoveredWsUrl!;
    }
    if (envWsUrl.isNotEmpty) {
      return _cleanUrl(envWsUrl)!;
    }
    if (envApiUrl.isNotEmpty) {
      return deriveWsUrl(envApiUrl);
    }
    return isProduction ? defaultProdWsBaseUrl : defaultDevWsBaseUrl;
  }

  /// Active Storage Base URL (e.g. `https://storage.miptgram.ru` or `http://192.168.1.50:9000`)
  static String get storageUrl {
    if (_customStorageUrl != null && _customStorageUrl!.isNotEmpty) {
      return _customStorageUrl!;
    }
    if (_customApiUrl != null && _customApiUrl!.isNotEmpty) {
      return deriveStorageUrl(_customApiUrl!);
    }
    if (kIsWeb && _webDiscoveredStorageUrl != null && _webDiscoveredStorageUrl!.isNotEmpty) {
      return _webDiscoveredStorageUrl!;
    }
    if (envStorageUrl.isNotEmpty) {
      return _cleanUrl(envStorageUrl)!;
    }
    if (envApiUrl.isNotEmpty) {
      return deriveStorageUrl(envApiUrl);
    }
    return isProduction ? defaultProdStorageBaseUrl : defaultDevStorageBaseUrl;
  }

  /// Active Web Base URL (e.g. `https://miptgram.ru` or `http://192.168.1.50:3000`)
  static String get webBaseUrl {
    if (_customWebUrl != null && _customWebUrl!.isNotEmpty) {
      return _customWebUrl!;
    }
    if (kIsWeb && _webDiscoveredWebUrl != null && _webDiscoveredWebUrl!.isNotEmpty) {
      return _webDiscoveredWebUrl!;
    }
    if (envWebUrl.isNotEmpty) {
      return _cleanUrl(envWebUrl)!;
    }
    return isProduction ? defaultProdWebBaseUrl : defaultDevWebBaseUrl;
  }

  // ============================================
  // Helper Methods
  // ============================================

  /// Derives the WebSocket URL from an API base URL.
  /// Converts `http://` -> `ws://.../api/ws`, `https://` -> `wss://.../api/ws`.
  static String deriveWsUrl(String apiBaseUrl) {
    final trimmed = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return defaultDevWsBaseUrl;

    String wsScheme;
    String hostAndPath;

    if (trimmed.startsWith('https://')) {
      wsScheme = 'wss://';
      hostAndPath = trimmed.substring('https://'.length);
    } else if (trimmed.startsWith('http://')) {
      wsScheme = 'ws://';
      hostAndPath = trimmed.substring('http://'.length);
    } else if (trimmed.startsWith('wss://') || trimmed.startsWith('ws://')) {
      return trimmed.endsWith('/api/ws') ? trimmed : '$trimmed/api/ws';
    } else {
      wsScheme = 'ws://';
      hostAndPath = trimmed;
    }

    if (hostAndPath.endsWith('/api/ws')) {
      return '$wsScheme$hostAndPath';
    }
    if (hostAndPath.endsWith('/api')) {
      return '$wsScheme$hostAndPath/ws';
    }
    return '$wsScheme$hostAndPath/api/ws';
  }

  /// Derives the Storage URL (MinIO/S3) from an API base URL.
  static String deriveStorageUrl(String apiBaseUrl) {
    final trimmed = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return defaultDevStorageBaseUrl;

    try {
      final uri = Uri.parse(trimmed.contains('://') ? trimmed : 'http://$trimmed');
      
      // Check for production domain pattern: api.miptgram.ru -> storage.miptgram.ru
      if (uri.host == 'api.miptgram.ru') {
        return '${uri.scheme}://storage.miptgram.ru';
      }
      if (uri.host.startsWith('api.')) {
        final domain = uri.host.substring(4);
        return '${uri.scheme}://storage.$domain';
      }

      // Check if port 8080 -> standard MinIO port 9000
      if (uri.hasPort && uri.port == 8080) {
        return '${uri.scheme}://${uri.host}:9000';
      }

      // For standard localhost / LAN IPs without port or with standard ports
      if (uri.host == 'localhost' || uri.host == '127.0.0.1' || RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(uri.host)) {
        return '${uri.scheme}://${uri.host}:9000';
      }

      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    } catch (_) {
      return trimmed;
    }
  }

  /// Generates a full profile deep link URL for a given user ID.
  static String getProfileUrl(String userId) {
    return '$webBaseUrl/u/$userId';
  }

  /// Generates a full group/channel invite deep link URL for a given invite code.
  static String getInviteUrl(String inviteCode) {
    return '$webBaseUrl/join/$inviteCode';
  }

  /// Resolves relative or absolute media / storage URLs.
  /// Returns full URL with storageUrl prepended if relative path.
  static String? resolveMediaUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:') ||
        trimmed.startsWith('file://')) {
      return trimmed;
    }

    final base = storageUrl.replaceAll(RegExp(r'/+$'), '');
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$path';
  }

  // ============================================
  // Private Helper Methods
  // ============================================

  static String? _cleanUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  static void _discoverWebUrls() {
    try {
      final baseUri = Uri.base;
      final scheme = baseUri.scheme.isNotEmpty ? baseUri.scheme : 'http';
      final host = baseUri.host.isNotEmpty ? baseUri.host : 'localhost';
      final port = baseUri.hasPort ? baseUri.port : (scheme == 'https' ? 443 : 80);
      final isStandardPort = (scheme == 'https' && port == 443) || (scheme == 'http' && port == 80);

      _webDiscoveredWebUrl = '$scheme://$host${isStandardPort ? '' : ':$port'}';

      if (host == 'miptgram.ru' || host == 'app.miptgram.ru') {
        _webDiscoveredApiUrl = defaultProdApiBaseUrl;
        _webDiscoveredWsUrl = defaultProdWsBaseUrl;
        _webDiscoveredStorageUrl = defaultProdStorageBaseUrl;
        _webDiscoveredWebUrl = defaultProdWebBaseUrl;
      } else {
        // LAN IP or localhost
        final wsScheme = scheme == 'https' ? 'wss' : 'ws';
        _webDiscoveredApiUrl = '$scheme://$host:8080';
        _webDiscoveredWsUrl = '$wsScheme://$host:8080/api/ws';
        _webDiscoveredStorageUrl = '$scheme://$host:9000';
      }
    } catch (e) {
      debugPrint('[AppConfig] Error discovering web URLs: $e');
    }
  }

  // ============================================
  // Feature Flags
  // ============================================

  /// Enable debug logging
  static const bool enableDebugLogging = true;

  /// Enable mock data when backend is unavailable
  static const bool enableMockData = false;

  // ============================================
  // Timeouts
  // ============================================

  /// API request timeout in seconds
  static const int apiTimeoutSeconds = 30;

  /// WebSocket connection timeout in seconds
  static const int wsTimeoutSeconds = 10;

  // ============================================
  // App Information
  // ============================================

  /// Application name
  static const String appName = 'Miptgram';

  /// Compile-time / default application version
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// Compile-time / default application build number
  static const int appBuildNumber = int.fromEnvironment('APP_BUILD_NUMBER', defaultValue: 1);

  /// Compile-time / default build date
  static const String _defaultBuildDate = '08.08.2026';
  static const String _envBuildDate = String.fromEnvironment('BUILD_DATE');

  /// Build date (from --dart-define=BUILD_DATE or default)
  static String get buildDate => _envBuildDate.isNotEmpty ? _envBuildDate : _defaultBuildDate;

  // Runtime values loaded dynamically from PackageInfo (pubspec.yaml / platform)
  static String _currentVersion = appVersion;
  static int _currentBuildNumber = appBuildNumber;

  /// Dynamic application version (from PackageInfo if available, otherwise appVersion)
  static String get currentVersion => _currentVersion;

  /// Dynamic application build number (from PackageInfo if available, otherwise appBuildNumber)
  static int get currentBuildNumber => _currentBuildNumber;
}
