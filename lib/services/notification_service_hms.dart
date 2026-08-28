import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Сервис Huawei Push Kit для устройств без Google Play Services.
///
/// Обёртка над HMS Push Plugin, предоставляющая API,
/// аналогичное FirebaseMessaging для унификации в NotificationService.
class HMSPushService {
  HMSPushService._internal();
  factory HMSPushService() => _instance;
  static final HMSPushService _instance = HMSPushService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.example.miptgram/hms_push');

  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageOpenedAppController =
      StreamController<Map<String, dynamic>>.broadcast();

  String? _token;

  /// Текущий HMS Push токен
  String? get token => _token;

  /// Поток обновлений токена
  Stream<String> get onTokenRefresh => _tokenController.stream;

  /// Поток входящих сообщений (foreground)
  Stream<Map<String, dynamic>> get onMessageReceived =>
      _messageController.stream;

  /// Поток сообщений, открывших приложение
  Stream<Map<String, dynamic>> get onMessageOpenedApp =>
      _messageOpenedAppController.stream;

  /// Запрос разрешений на уведомления (HMS Push)
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod<bool>('requestPermission');
      debugPrint('HMSPushService: permission requested');
    } catch (e) {
      debugPrint('HMSPushService: permission request failed: $e');
    }
  }

  /// Получить HMS Push токен
  Future<String?> getToken() async {
    try {
      _token = await _channel.invokeMethod<String>('getToken');
      debugPrint('HMSPushService: token obtained');
      return _token;
    } catch (e) {
      debugPrint('HMSPushService: getToken failed: $e');
      return null;
    }
  }

  /// Подписаться на тему (HMS Push topic messaging)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _channel.invokeMethod<bool>('subscribeToTopic', {'topic': topic});
      debugPrint('HMSPushService: subscribed to topic $topic');
    } catch (e) {
      debugPrint('HMSPushService: subscribeToTopic failed: $e');
    }
  }

  /// Отписаться от темы
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _channel.invokeMethod<bool>('unsubscribeFromTopic', {'topic': topic});
      debugPrint('HMSPushService: unsubscribed from topic $topic');
    } catch (e) {
      debugPrint('HMSPushService: unsubscribeFromTopic failed: $e');
    }
  }

  /// Удалить токен (при выходе из аккаунта)
  Future<void> deleteToken() async {
    try {
      await _channel.invokeMethod<bool>('deleteToken');
      _token = null;
      debugPrint('HMSPushService: token deleted');
    } catch (e) {
      debugPrint('HMSPushService: deleteToken failed: $e');
    }
  }

  /// Инициализация обработчиков сообщений
  ///
  /// Вызывается автоматически при создании.
  /// Настраивает MethodChannel callback для получения
  /// push-сообщений и обновлений токена от нативного кода.
  void setupMessageHandlers() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTokenRefresh':
          _token = call.arguments as String?;
          if (_token != null) {
            _tokenController.add(_token!);
          }
          break;
        case 'onMessageReceived':
          final data = Map<String, dynamic>.from(call.arguments ?? {});
          _messageController.add(data);
          break;
        case 'onMessageOpenedApp':
          final data = Map<String, dynamic>.from(call.arguments ?? {});
          _messageOpenedAppController.add(data);
          break;
      }
    });
  }

  /// Освободить ресурсы
  void dispose() {
    _tokenController.close();
    _messageController.close();
    _messageOpenedAppController.close();
  }
}
