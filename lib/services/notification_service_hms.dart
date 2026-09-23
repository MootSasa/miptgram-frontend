import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:huawei_push/huawei_push.dart';

/// Сервис Huawei Push Kit для устройств без Google Play Services.
///
/// Интегрирован с официальным плагином Huawei Push Kit (huawei_push),
/// предоставляя унифицированное API для NotificationService.
class HMSPushService {
  HMSPushService._internal() {
    if (Platform.isAndroid) {
      setupMessageHandlers();
    }
  }
  factory HMSPushService() => _instance;
  static final HMSPushService _instance = HMSPushService._internal();

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
    if (!Platform.isAndroid) return;
    try {
      await Push.setAutoInitEnabled(true);
      await Push.turnOnPush();
      debugPrint('HMSPushService: autoInit enabled, push turned on');
    } catch (e) {
      debugPrint('HMSPushService: permission request failed: $e');
    }
  }

  /// Получить HMS Push токен
  Future<String?> getToken() async {
    if (!Platform.isAndroid) return null;
    try {
      if (_token != null && _token!.isNotEmpty) {
        return _token;
      }

      final completer = Completer<String?>();
      late StreamSubscription sub;
      sub = Push.getTokenStream.listen((token) {
        _token = token;
        _tokenController.add(token);
        if (!completer.isCompleted) {
          completer.complete(token);
        }
      }, onError: (e) {
        debugPrint('HMSPushService: getTokenStream error: $e');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      // Запрос токена от HMS Core (HCM — default scope)
      Push.getToken('');

      // Ожидание токена до 5 секунд
      Future.delayed(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete(_token);
        }
        sub.cancel();
      });

      return await completer.future;
    } catch (e) {
      debugPrint('HMSPushService: getToken failed: $e');
      return null;
    }
  }

  /// Подписаться на тему (HMS Push topic messaging)
  Future<void> subscribeToTopic(String topic) async {
    if (!Platform.isAndroid) return;
    try {
      await Push.subscribe(topic);
      debugPrint('HMSPushService: subscribed to topic $topic');
    } catch (e) {
      debugPrint('HMSPushService: subscribeToTopic failed: $e');
    }
  }

  /// Отписаться от темы
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!Platform.isAndroid) return;
    try {
      await Push.unsubscribe(topic);
      debugPrint('HMSPushService: unsubscribed from topic $topic');
    } catch (e) {
      debugPrint('HMSPushService: unsubscribeFromTopic failed: $e');
    }
  }

  /// Удалить токен (при выходе из аккаунта)
  Future<void> deleteToken() async {
    if (!Platform.isAndroid) return;
    try {
      await Push.deleteToken('');
      _token = null;
      debugPrint('HMSPushService: token deleted');
    } catch (e) {
      debugPrint('HMSPushService: deleteToken failed: $e');
    }
  }

  /// Инициализация обработчиков сообщений
  void setupMessageHandlers() {
    Push.getTokenStream.listen((token) {
      debugPrint('HMSPushService: token received: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      _token = token;
      _tokenController.add(token);
    }, onError: (e) {
      debugPrint('HMSPushService: token error: $e');
    });

    Push.onMessageReceivedStream.listen((RemoteMessage message) {
      debugPrint('HMSPushService: onMessageReceived');
      Map<String, dynamic> data = {};
      if (message.dataOfMap != null && message.dataOfMap!.isNotEmpty) {
        data = Map<String, dynamic>.from(message.dataOfMap!);
      } else if (message.data != null && message.data!.isNotEmpty) {
        try {
          data = Map<String, dynamic>.from(json.decode(message.data!));
        } catch (_) {
          data = {'data': message.data};
        }
      }
      _messageController.add(data);
    }, onError: (e) {
      debugPrint('HMSPushService: message error: $e');
    });

    Push.onNotificationOpenedApp.listen((dynamic event) {
      debugPrint('HMSPushService: onNotificationOpenedApp: $event');
      Map<String, dynamic> data = _extractMap(event);
      if (data.isNotEmpty) {
        _messageOpenedAppController.add(data);
      }
    }, onError: (e) {
      debugPrint('HMSPushService: notification open error: $e');
    });

    // Проверка начального уведомления при холодном старте
    Push.getInitialNotification().then((dynamic event) {
      if (event != null) {
        debugPrint('HMSPushService: getInitialNotification: $event');
        Map<String, dynamic> data = _extractMap(event);
        if (data.isNotEmpty) {
          _messageOpenedAppController.add(data);
        }
      }
    }).catchError((e) {
      debugPrint('HMSPushService: getInitialNotification error: $e');
    });
  }

  Map<String, dynamic> _extractMap(dynamic event) {
    if (event == null) return {};
    if (event is Map) {
      return Map<String, dynamic>.from(event);
    }
    if (event is String && event.isNotEmpty) {
      try {
        final decoded = json.decode(event);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return {'data': event};
      }
    }
    return {};
  }

  /// Освободить ресурсы
  void dispose() {
    _tokenController.close();
    _messageController.close();
    _messageOpenedAppController.close();
  }
}
