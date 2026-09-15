import 'package:flutter/material.dart';
import '../theme/liquid_glass_styles.dart';
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
  double _blur = 12.0;

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

  /// Текущая сила размытия под стеклом (0.0 .. 30.0).
  double get blur => _blur;

  /// Доступность Liquid Glass на текущей платформе
  bool get isSupported => SettingsService.isLiquidGlassSupported;

  /// Инициализация из SettingsService
  void init() {
    _mode = _settingsService.glassMode;
    _blur = _settingsService.glassBlur;
    LiquidGlassStyles.defaultBlur = _blur;
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

  /// Установить силу размытия Liquid Glass (0.0 .. 30.0).
  /// Если [save] == true, сохраняет значение в постоянное хранилище.
  Future<void> setBlur(double value, {bool save = true}) async {
    if (_blur == value) return;
    _blur = value;
    LiquidGlassStyles.defaultBlur = value;
    if (save) {
      await _settingsService.saveGlassBlur(value);
    }
    notifyListeners();
  }

  /// Сохранить текущее значение силы размытия в постоянное хранилище
  Future<void> saveBlur() async {
    await _settingsService.saveGlassBlur(_blur);
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
