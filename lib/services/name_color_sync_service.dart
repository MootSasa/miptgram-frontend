import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/name_color_preset.dart';
import 'account_manager.dart';
import 'auth_service.dart';

/// Сервис фоновой синхронизации цвета имени и стиля полоски ответа.
///
/// Мгновенно обновляет настройки локально (SharedPreferences + AccountManager),
/// а затем выполняет фоновую синхронизацию с сервером при наличии соединения.
class NameColorSyncService extends ChangeNotifier {
  static final NameColorSyncService _instance = NameColorSyncService._internal();
  factory NameColorSyncService() => _instance;
  NameColorSyncService._internal();

  final AccountManager _accountManager = AccountManager();

  static String _prefNameColorKey(String uid) => '${uid}_user_name_color_preset_id';
  static String _prefStripStyleKey(String uid) => '${uid}_user_reply_strip_style';

  /// Сохраняет настройки цвета имени и стиля полоски ответа локально
  /// и инициирует фоновую синхронизацию с сервером.
  Future<void> setNameColorAndStyle({
    required NameColorPreset preset,
    required ReplyStripStyle style,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentAccount = _accountManager.currentAccount;
    if (currentAccount != null) {
      final uid = currentAccount.userId;
      await prefs.setString(_prefNameColorKey(uid), preset.id);
      await prefs.setString(_prefStripStyleKey(uid), style.name);
      await _accountManager.updateAccountProfile(
        uid,
      );
    }

    notifyListeners();

    // Запуск асинхронной фоновой синхронизации с сервером
    _syncWithBackend(preset.id, style.name);
  }

  /// Асинхронная отправка на сервер при наличии подключения
  Future<void> _syncWithBackend(String presetId, String stripStyle) async {
    try {
      debugPrint('[NameColorSyncService] Syncing name color to backend: $presetId, $stripStyle');
      final token = await AuthService.getToken();
      if (token == null) return;
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/user/appearance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name_color_preset_id': presetId,
          'reply_strip_style': stripStyle,
        }),
      );
      debugPrint('[NameColorSyncService] sync status: ${response.statusCode}');
    } catch (e) {
      debugPrint('[NameColorSyncService] Failed to sync with backend, will retry later: $e');
    }
  }
}
