import 'package:flutter/material.dart';
import 'settings_service.dart';

/// Provider для управления настройками уведомлений.
/// Синхронизирует глобальные и per-chat настройки с SettingsService.
class NotificationSettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  GlobalNotificationSettings _globalSettings = GlobalNotificationSettings.defaults();
  Map<String, ChatNotificationSettings> _chatSettings = {};

  GlobalNotificationSettings get globalSettings => _globalSettings;
  Map<String, ChatNotificationSettings> get chatSettings => _chatSettings;

  /// Инициализация: загрузка из SettingsService
  Future<void> init() async {
    _globalSettings = _settingsService.notificationSettings;
    _chatSettings = _settingsService.allChatNotificationSettings;
    notifyListeners();
  }

  // ============ Глобальные настройки ============

  /// Сохранить глобальные настройки уведомлений
  Future<void> saveGlobalSettings(GlobalNotificationSettings settings) async {
    _globalSettings = settings;
    await _settingsService.saveNotificationSettings(settings);
    notifyListeners();
  }

  /// Обновить отдельные поля глобальных настроек
  Future<void> updateGlobalSettings({
    bool? notificationsEnabled,
    bool? privateChatNotifications,
    bool? privateChatPreview,
    bool? privateChatSound,
    String? privateChatSoundUri,
    VibrationPattern? privateChatVibration,
    bool? groupChatNotifications,
    bool? groupChatPreview,
    bool? groupChatSound,
    String? groupChatSoundUri,
    VibrationPattern? groupChatVibration,
    bool? channelNotifications,
    bool? channelPreview,
    bool? channelSound,
    String? channelSoundUri,
    VibrationPattern? channelVibration,
    bool? callNotifications,
    bool? callSound,
    bool? callVibration,
    bool? mentionsNotifications,
    bool? keywordsNotifications,
    bool? badgeEnabled,
    bool? popupEnabled,
    bool? contentPreview,
    bool? includeMutedChats,
    bool? accountNotifications,
  }) async {
    final updated = _globalSettings.copyWith(
      notificationsEnabled: notificationsEnabled,
      privateChatNotifications: privateChatNotifications,
      privateChatPreview: privateChatPreview,
      privateChatSound: privateChatSound,
      privateChatSoundUri: privateChatSoundUri,
      privateChatVibration: privateChatVibration,
      groupChatNotifications: groupChatNotifications,
      groupChatPreview: groupChatPreview,
      groupChatSound: groupChatSound,
      groupChatSoundUri: groupChatSoundUri,
      groupChatVibration: groupChatVibration,
      channelNotifications: channelNotifications,
      channelPreview: channelPreview,
      channelSound: channelSound,
      channelSoundUri: channelSoundUri,
      channelVibration: channelVibration,
      callNotifications: callNotifications,
      callSound: callSound,
      callVibration: callVibration,
      mentionsNotifications: mentionsNotifications,
      keywordsNotifications: keywordsNotifications,
      badgeEnabled: badgeEnabled,
      popupEnabled: popupEnabled,
      contentPreview: contentPreview,
      includeMutedChats: includeMutedChats,
      accountNotifications: accountNotifications,
    );
    await saveGlobalSettings(updated);
  }

  // ============ Per-chat настройки ============

  /// Получить per-chat настройки
  ChatNotificationSettings? getChatSettings(String chatId) {
    return _chatSettings[chatId];
  }

  /// Получить эффективные настройки для чата (per-chat или глобальные)
  EffectiveChatSettings getEffectiveSettings(String chatId) {
    return _settingsService.getEffectiveChatSettings(chatId);
  }

  /// Сохранить per-chat настройки
  Future<void> saveChatSettings(String chatId, ChatNotificationSettings settings) async {
    _chatSettings[chatId] = settings;
    await _settingsService.saveChatNotificationSettings(chatId, settings);
    notifyListeners();
  }

  /// Установить mute для чата
  Future<void> setMuteState(String chatId, MuteState state, {DateTime? until}) async {
    final existing = _chatSettings[chatId];
    final updated = (existing ?? ChatNotificationSettings(chatId: chatId)).copyWith(
      muteState: state,
      muteUntil: until,
    );
    await saveChatSettings(chatId, updated);
  }

  /// Установить mentions-only для чата
  Future<void> setMentionsOnly(String chatId, bool mentionsOnly) async {
    final existing = _chatSettings[chatId];
    final updated = (existing ?? ChatNotificationSettings(chatId: chatId)).copyWith(
      mentionsOnly: mentionsOnly,
    );
    await saveChatSettings(chatId, updated);
  }

  /// Установить ключевые слова для чата
  Future<void> setKeywords(String chatId, List<String> keywords) async {
    final existing = _chatSettings[chatId];
    final updated = (existing ?? ChatNotificationSettings(chatId: chatId)).copyWith(
      keywords: keywords,
    );
    await saveChatSettings(chatId, updated);
  }

  /// Удалить per-chat настройки (вернуть к глобальным)
  Future<void> removeChatSettings(String chatId) async {
    _chatSettings.remove(chatId);
    await _settingsService.removeChatNotificationSettings(chatId);
    notifyListeners();
  }

  /// Сбросить все per-chat настройки
  Future<void> resetAllChatSettings() async {
    _chatSettings = {};
    await _settingsService.resetAllChatNotificationSettings();
    notifyListeners();
  }

  /// Проверить, нужно ли показывать уведомление для чата
  bool shouldShowNotification(String chatId, {bool isMention = false}) {
    if (!_globalSettings.notificationsEnabled) return false;

    final effective = getEffectiveSettings(chatId);

    if (effective.isMuted) return false;
    if (effective.mentionsOnly && !isMention) return false;

    return true;
  }
}
