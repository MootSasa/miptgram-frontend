import 'package:flutter/material.dart';
import 'glass_mode.dart';
import 'settings_service.dart';

export 'glass_mode.dart';

/// Провайдер для реактивного управления состоянием Liquid Glass дизайна.
/// Позволяет виджетам подписываться на изменения настройки.
///
/// Поддерживает три режима:
/// - [GlassMode.disabled] — классический дизайн без стекла
/// - [GlassMode.lite] — облегчённый стеклянный дизайн (FakeGlass)
/// - [GlassMode.full] — полноценный стеклянный дизайн (LiquidGlass)
///
/// На неподдерживаемых платформах (Linux, Web, Windows) [enabled] всегда
/// возвращает `false`, даже если в хранилище сохранено иное.
class LiquidGlassProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  GlassMode _mode = GlassMode.disabled;

  /// Текущий режим Liquid Glass дизайна.
  /// Всегда [GlassMode.disabled] на неподдерживаемых платформах.
  GlassMode get mode => isSupported ? _mode : GlassMode.disabled;

  /// Включён ли какой-либо стеклянный дизайн (lite или full).
  /// Всегда `false` на неподдерживаемых платформах.
  bool get enabled => isSupported && _mode != GlassMode.disabled;

  /// Включён ли облегчённый режим (FakeGlass).
  bool get isLite => isSupported && _mode == GlassMode.lite;

  /// Включён ли полный режим (LiquidGlass).
  bool get isFull => isSupported && _mode == GlassMode.full;

  /// Доступность Liquid Glass на текущей платформе
  bool get isSupported => SettingsService.isLiquidGlassSupported;

  /// Инициализация из SettingsService
  void init() {
    _mode = _settingsService.glassMode;
    // Если платформа не поддерживается, принудительно сбрасываем
    if (!isSupported && _mode != GlassMode.disabled) {
      _mode = GlassMode.disabled;
      _settingsService.saveGlassMode(GlassMode.disabled);
    }
    notifyListeners();
  }

  /// Установить режим Liquid Glass дизайна
  Future<void> setMode(GlassMode value) async {
    if (!isSupported) return; // Запрещаем включение на неподдерживаемых платформах
    if (_mode == value) return;
    _mode = value;
    await _settingsService.saveGlassMode(value);
    notifyListeners();
  }

  /// Переключить между disabled и последним активным режимом
  Future<void> toggle() async {
    if (_mode == GlassMode.disabled) {
      await setMode(GlassMode.full);
    } else {
      await setMode(GlassMode.disabled);
    }
  }
}
