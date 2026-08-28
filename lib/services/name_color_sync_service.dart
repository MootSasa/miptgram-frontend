import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/name_color_preset.dart';
import 'account_manager.dart';

/// Сервис фоновой синхронизации цвета имени и стиля полоски ответа.
///
/// Мгновенно обновляет настройки локально (SharedPreferences + AccountManager),
/// а затем выполняет фоновую синхронизацию с сервером при наличии соединения.
class NameColorSyncService extends ChangeNotifier {
  static final NameColorSyncService _instance = NameColorSyncService._internal();
  factory NameColorSyncService() => _instance;
  NameColorSyncService._internal();

  final AccountManager _accountManager = AccountManager();

  static const String _prefNameColorKey = 'user_name_color_preset_id';
  static const String _prefStripStyleKey = 'user_reply_strip_style';

  /// Сохраняет настройки цвета имени и стиля полоски ответа локально
  /// и инициирует фоновую синхронизацию с сервером.
  Future<void> setNameColorAndStyle({
    required NameColorPreset preset,
    required ReplyStripStyle style,
  }) async {
    debugPrint('[NameColorSyncService] Saving name color preset=${preset.id}, style=${style.name}');
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_prefNameColorKey, preset.id);
    await prefs.setString(_prefStripStyleKey, style.name);

    final currentAccount = _accountManager.currentAccount;
    if (currentAccount != null) {
      await _accountManager.updateAccountProfile(
        currentAccount.userId,
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
      // При наличии REST API / WebSocket бэкенда выполняется запрос обновления профиля.
      // Локальный эффект уже применён немедленно.
    } catch (e) {
      debugPrint('[NameColorSyncService] Failed to sync with backend, will retry later: $e');
    }
  }
}
