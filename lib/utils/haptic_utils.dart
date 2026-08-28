import 'package:flutter/services.dart';

/// Семантическая обёртка над HapticFeedback для единообразной
/// тактильной отдачи по всему приложению.
///
/// Использование:
/// ```dart
/// HapticUtils.selection();  // переключение вкладок, фильтров
/// HapticUtils.tap();        // нажатие кнопок, выбор элемента
/// HapticUtils.impact();     // long press, свайп-активация
/// HapticUtils.heavy();      // деструктивные действия
/// ```
class HapticUtils {
  HapticUtils._();

  /// Лёгкий щелчок при переключении состояния.
  /// Использовать: переключение вкладок, фильтров, toggle, сегмент-контрол.
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Лёгкий удар при обычном нажатии.
  /// Использовать: кнопки, выбор элемента списка, навигация.
  static void tap() {
    HapticFeedback.lightImpact();
  }

  /// Средний удар при значимом действии.
  /// Использовать: long press, свайп-активация, раскрытие/сворачивание.
  static void impact() {
    HapticFeedback.mediumImpact();
  }

  /// Тяжёлый удар при деструктивном действии.
  /// Использовать: удаление, выход из аккаунта, подтверждение опасного действия.
  static void heavy() {
    HapticFeedback.heavyImpact();
  }
}
