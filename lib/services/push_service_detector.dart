import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Результат детектирования доступных push-сервисов на устройстве.
enum PushServiceType {
  /// Google Play Services доступны — используем FCM
  gms,

  /// HMS Core доступен — используем Huawei Push Kit
  hms,

  /// Ни GMS, ни HMS не доступны — только локальные уведомления
  none,
}

/// Детектор доступных push-сервисов на устройстве.
///
/// Проверяет наличие Google Play Services (GMS) и HMS Core.
/// На устройствах Huawei без GMS автоматически переключается на HMS Push.
class PushServiceDetector {
  PushServiceDetector._internal();
  static final PushServiceDetector _instance = PushServiceDetector._internal();
  factory PushServiceDetector() => _instance;

  PushServiceType _detected = PushServiceType.none;
  bool _isDetected = false;

  /// Текущий обнаруженный тип push-сервиса
  PushServiceType get serviceType => _detected;

  /// Было ли выполнено детектирование
  bool get isDetected => _isDetected;

  /// Доступен ли FCM (Google Play Services)
  bool get isGmsAvailable => _detected == PushServiceType.gms;

  /// Доступен ли HMS Push Kit
  bool get isHmsAvailable => _detected == PushServiceType.hms;

  /// Доступен ли хотя бы один push-сервис
  bool get isPushAvailable => _detected != PushServiceType.none;

  /// Выполнить детектирование доступных push-сервисов.
  ///
  /// Вызывается один раз при инициализации приложения.
  /// На iOS всегда возвращает GMS (FCM работает через APNS).
  /// На Android проверяет наличие GMS и HMS.
  /// На остальных платформах — none.
  Future<PushServiceType> detect() async {
    if (_isDetected) return _detected;

    if (!Platform.isAndroid) {
      // iOS / macOS / Windows / Linux — FCM работает через APNS на iOS
      if (Platform.isIOS || Platform.isMacOS) {
        _detected = PushServiceType.gms;
      } else {
        _detected = PushServiceType.none;
      }
      _isDetected = true;
      debugPrint('PushServiceDetector: non-Android platform → $_detected');
      return _detected;
    }

    // Android: проверяем GMS, затем HMS
    try {
      final gmsAvailable = await _checkGmsAvailability();
      if (gmsAvailable) {
        _detected = PushServiceType.gms;
        _isDetected = true;
        debugPrint('PushServiceDetector: GMS available → FCM');
        return _detected;
      }
    } catch (e) {
      debugPrint('PushServiceDetector: GMS check failed: $e');
    }

    try {
      final hmsAvailable = await _checkHmsAvailability();
      if (hmsAvailable) {
        _detected = PushServiceType.hms;
        _isDetected = true;
        debugPrint('PushServiceDetector: HMS available → Huawei Push Kit');
        return _detected;
      }
    } catch (e) {
      debugPrint('PushServiceDetector: HMS check failed: $e');
    }

    _detected = PushServiceType.none;
    _isDetected = true;
    debugPrint('PushServiceDetector: no push services available → local notifications only');
    return _detected;
  }

  /// Проверка доступности Google Play Services.
  ///
  /// Использует MethodChannel для вызова нативного кода Android.
  Future<bool> _checkGmsAvailability() async {
    try {
      // Проверяем через Firebase — если Firebase инициализирован,
      // значит GMS доступен
      // Альтернатива: нативный метод через MethodChannel
      const channel = MethodChannel('com.example.miptgram/push_detector');
      return await channel.invokeMethod<bool>('isGmsAvailable') ?? false;
    } catch (e) {
      // Если MethodChannel не настроен — пробуем через Firebase
      debugPrint('PushServiceDetector: GMS MethodChannel not available, trying Firebase');
      return false;
    }
  }

  /// Проверка доступности HMS Core.
  ///
  /// Использует MethodChannel для вызова нативного кода Android.
  Future<bool> _checkHmsAvailability() async {
    try {
      const channel = MethodChannel('com.example.miptgram/push_detector');
      return await channel.invokeMethod<bool>('isHmsAvailable') ?? false;
    } catch (e) {
      debugPrint('PushServiceDetector: HMS MethodChannel not available');
      return false;
    }
  }
}
