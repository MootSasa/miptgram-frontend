import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'account_manager.dart';
import 'auth_service.dart';
import 'websocket_service.dart';
import 'desktop_tray_service.dart';
import 'notification_settings_provider.dart';
import 'notification_service_hms.dart';
import 'push_service_detector.dart';
import 'settings_service.dart';
import '../config/app_config.dart';


/// Фоновый обработчик FCM сообщений (должен быть top-level функцией)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Если сообщение содержит notification-payload, Google Play Services уже показал его в шторке
  if (message.notification != null) {
    debugPrint('NotificationService: background notification already displayed by system tray');
    return;
  }

  await Firebase.initializeApp();
  final localNotifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await localNotifications.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );
  if (Platform.isAndroid) {
    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'private_chats',
      'Личные чаты',
      description: 'Уведомления о новых сообщениях в личных чатах',
      importance: Importance.high,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'group_chats',
      'Групповые чаты',
      description: 'Уведомления о новых сообщениях в группах',
      importance: Importance.high,
    ));
  }
  final data = message.data;
  if (data.containsKey('chat_id') && data.containsKey('chat_name')) {
    await _showBackgroundNotification(localNotifications, data);
  }
}

const _firebaseMessagingBackgroundHandler = firebaseMessagingBackgroundHandler;

Future<void> _showBackgroundNotification(
  FlutterLocalNotificationsPlugin localNotifications,
  Map<String, dynamic> data,
) async {
  const androidDetails = AndroidNotificationDetails(
    'private_chats',
    'Личные чаты',
    channelDescription: 'Уведомления о новых сообщениях в личных чатах',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
  final chatId = data['chat_id'] ?? '';
  final chatName = data['chat_name'] ?? 'Theaver';
  final senderName = data['sender_name'] ?? '';
  final messageText = data['message_text'] ?? '';
  await localNotifications.show(
    chatId.hashCode,
    chatName,
    senderName.isNotEmpty ? '$senderName: $messageText' : messageText,
    details,
    payload: chatId,
  );
}

/// Центральный сервис управления уведомлениями.
///
/// Поддерживает дуальный push: FCM (Google) + HMS Push Kit (Huawei).
/// Автоматически определяет доступный сервис через PushServiceDetector.
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  HMSPushService? _hmsPushService;
  final PushServiceDetector _detector = PushServiceDetector();

  NotificationSettingsProvider? _settingsProvider;
  String? _pushToken;
  bool _initialized = false;

  InAppNotificationData? _currentBanner;
  final StreamController<InAppNotificationData?> _bannerController =
      StreamController<InAppNotificationData?>.broadcast();

  Stream<InAppNotificationData?> get bannerStream => _bannerController.stream;
  InAppNotificationData? get currentBanner => _currentBanner;
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  String? get pushToken => _pushToken;
  bool get isInitialized => _initialized;
  PushServiceType get pushServiceType => _detector.serviceType;

  /// ID чата, открытого прямо сейчас на экране пользователя (для подавления уведомлений)
  String? currentActiveChatId;
  String? _lastActiveChatId;

  /// Устанавливает текущий открытый чат на этом устройстве,
  /// синхронизирует его с бэкендом через WebSocket для подавления push-уведомлений,
  /// и удаляет уже висящие уведомления для этого чата из шторки.
  void setActiveChat(String? chatId) {
    currentActiveChatId = (chatId != null && chatId.isNotEmpty) ? chatId : null;
    _lastActiveChatId = null;

    if (currentActiveChatId != null) {
      cancelChatNotifications(currentActiveChatId!);
    }
    WebSocketService().sendActiveChat(currentActiveChatId);
  }

  /// Вызывается при сворачивании приложения в фон:
  /// пользователь больше не смотрит в экран чата, поэтому сервер должен слать push-уведомления.
  void onAppPause() {
    _lastActiveChatId = currentActiveChatId;
    currentActiveChatId = null;
    WebSocketService().sendActiveChat(null);
  }

  /// Вызывается при возврате приложения на передний план:
  /// если пользователь оставался на экране чата, восстанавливаем активный статус и очищаем уведомления.
  void onAppResume() {
    if (_lastActiveChatId != null) {
      currentActiveChatId = _lastActiveChatId;
      _lastActiveChatId = null;
      WebSocketService().sendActiveChat(currentActiveChatId);
      if (currentActiveChatId != null) {
        cancelChatNotifications(currentActiveChatId!);
      }
    }
  }

  /// Кэш недавно показанных уведомлений для защиты от дублирования (WebSocket + FCM)
  final Map<String, DateTime> _recentlyShownNotifications = {};

  bool _isDuplicateNotification(String chatId, String messageText) {
    final now = DateTime.now();
    _recentlyShownNotifications.removeWhere((_, time) => now.difference(time).inSeconds > 10);
    final key = '$chatId:$messageText';
    if (_recentlyShownNotifications.containsKey(key)) {
      return true;
    }
    _recentlyShownNotifications[key] = now;
    return false;
  }

  StreamSubscription? _wsSubscription;

  /// Полная инициализация: детектирование + Firebase/HMS + Local Notifications + Desktop
  Future<void> init(NotificationSettingsProvider settingsProvider) async {
    if (_initialized) return;
    _settingsProvider = settingsProvider;

    try {
      // 1. Детектирование push-сервиса
      await _detector.detect();
      debugPrint('NotificationService: detected push service = ${_detector.serviceType}');

      // 2. Инициализация для конкретной платформы
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _initDesktopNotifications();
      } else {
        // Локальные уведомления на Android / iOS
        await _initLocalNotifications();
        await _createNotificationChannels();

        // Инициализация push-сервиса в зависимости от детекта
        switch (_detector.serviceType) {
          case PushServiceType.gms:
            await _initFCM();
            break;
          case PushServiceType.hms:
            await _initHMS();
            break;
          case PushServiceType.none:
            debugPrint('NotificationService: no push service, local notifications only');
            break;
        }
      }

      // 3. Подписка на входящие WebSocket сообщения
      _subscribeWebSocketMessages();

      _initialized = true;
      debugPrint('NotificationService: fully initialized (${_detector.serviceType})');
    } catch (e) {
      debugPrint('NotificationService: initialization error: $e');
      _initialized = true;
    }
  }

  Future<void> _initDesktopNotifications() async {
    try {
      await DesktopTrayService().init();
      await localNotifier.setup(
        appName: 'Theaver',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      debugPrint('NotificationService: desktop local_notifier initialized');
    } catch (e) {
      debugPrint('NotificationService: desktop notification init error: $e');
    }
  }

  void _subscribeWebSocketMessages() {
    _wsSubscription?.cancel();
    _wsSubscription = WebSocketService().eventStream.listen((event) async {
      if (event.type == WebSocketEventType.newMessage) {
        final data = event.data;
        final chatId = data['chat_id']?.toString() ?? '';
        final senderId = data['sender_id']?.toString() ?? '';
        final currentUserId = await AuthService.getUserId();
        if (senderId.isNotEmpty && currentUserId != null && senderId == currentUserId) {
          return;
        }

        if (chatId.isEmpty) return;
        if (!shouldShowNotification(chatId)) return;

        final chatName = data['chat_name']?.toString() ?? data['sender_name']?.toString() ?? 'Theaver';
        final senderName = data['sender_name']?.toString() ?? '';
        final messageText = data['content']?.toString() ?? 'Новое сообщение';
        final isGroup = data['is_group'] == true || data['is_group'] == 'true';

        if (_isDuplicateNotification(chatId, messageText)) return;

        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          bool isFocused = false;
          try {
            isFocused = await windowManager.isFocused();
          } catch (_) {}

          if (!isFocused) {
            await showMessageNotification(
              chatId: chatId,
              chatName: chatName,
              senderName: senderName,
              messageText: messageText,
              isGroup: isGroup,
            );
          } else {
            showInAppBanner(
              chatId: chatId,
              chatName: chatName,
              senderName: senderName,
              messageText: messageText,
              isGroup: isGroup,
            );
          }
        } else {
          // Мобильные платформы (Android / iOS): показать баннер и шторку
          showInAppBanner(
            chatId: chatId,
            chatName: chatName,
            senderName: senderName,
            messageText: messageText,
            isGroup: isGroup,
          );
          await showMessageNotification(
            chatId: chatId,
            chatName: chatName,
            senderName: senderName,
            messageText: messageText,
            isGroup: isGroup,
          );
        }
      }
    });
  }

  // ============ FCM Initialization ============

  Future<void> _initFCM() async {
    _firebaseMessaging = FirebaseMessaging.instance;

    // Запрос разрешений
    final settings = await _firebaseMessaging!.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('NotificationService: FCM permission = ${settings.authorizationStatus}');

    // Получение токена
    _pushToken = await _firebaseMessaging!.getToken();
    debugPrint('NotificationService: FCM token=${_pushToken?.substring(0, 20)}...');

    if (_pushToken != null) {
      await _registerPushTokenOnServer(_pushToken!, 'fcm');
    }

    // Слушатель обновления токена
    _firebaseMessaging!.onTokenRefresh.listen((token) {
      _pushToken = token;
      _registerPushTokenOnServer(token, 'fcm');
    });

    // Обработчики
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    _checkInitialMessage();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // ============ HMS Push Initialization ============

  Future<void> _initHMS() async {
    _hmsPushService = HMSPushService();

    // Запрос разрешений
    await _hmsPushService!.requestPermission();

    // Получение токена
    _pushToken = await _hmsPushService!.getToken();
    final logToken = _pushToken != null
        ? (_pushToken!.length > 20 ? '${_pushToken!.substring(0, 20)}...' : _pushToken!)
        : 'null';
    debugPrint('NotificationService: HMS push token=$logToken');

    if (_pushToken != null && _pushToken!.isNotEmpty) {
      await _registerPushTokenOnServer(_pushToken!, 'hms');
    }

    // Слушатель обновления токена
    _hmsPushService!.onTokenRefresh.listen((token) {
      _pushToken = token;
      _registerPushTokenOnServer(token, 'hms');
    });

    // Обработчики
    _hmsPushService!.onMessageReceived.listen(_onHMSForegroundMessage);
    _hmsPushService!.onMessageOpenedApp.listen(_onHMSMessageOpenedApp);
  }

  // ============ Local Notifications ============

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'private_chats', 'Личные чаты',
      description: 'Уведомления о новых сообщениях в личных чатах',
      importance: Importance.high,
    ));
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'group_chats', 'Групповые чаты',
      description: 'Уведомления о новых сообщениях в группах',
      importance: Importance.high,
    ));
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'channels', 'Каналы',
      description: 'Уведомления о новых постах в каналах',
      importance: Importance.defaultImportance,
    ));
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'calls', 'Звонки',
      description: 'Уведомления о входящих звонках',
      importance: Importance.max,
    ));
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'mentions', 'Упоминания',
      description: 'Уведомления об @упоминаниях',
      importance: Importance.high,
    ));
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'silent', 'Беззвучные',
      description: 'Тихие уведомления — только бейдж',
      importance: Importance.low,
    ));
  }

  // ============ Token Registration ============

  Future<void> _registerPushTokenOnServer(String token, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = AccountManager().currentDeviceId ??
          prefs.getString('current_device_id') ??
          prefs.getString('device_id') ??
          'unknown';
      final authToken = await AuthService.getToken();

      final payload = {
        'token': token,
        'push_token': token,
        'fcm_token': token,
        'service_type': type,
        'type': type,
        'device_id': deviceId,
      };

      final options = Options(
        headers: {
          if (authToken != null) 'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      try {
        await Dio().put(
          '${AppConfig.baseUrl}/api/sessions/push-token',
          data: payload,
          options: options,
        );
      } catch (_) {
        await Dio().post(
          '${AppConfig.baseUrl}/api/notifications/push-token',
          data: payload,
          options: options,
        );
      }
      debugPrint('NotificationService: $type push token registered on server');
    } catch (e) {
      debugPrint('NotificationService: failed to register $type token: $e');
    }
  }

  Future<void> registerCurrentToken() async {
    if (_pushToken != null && _pushToken!.isNotEmpty) {
      final type = _detector.serviceType == PushServiceType.hms ? 'hms' : 'fcm';
      await _registerPushTokenOnServer(_pushToken!, type);
    }
  }

  Future<void> unregisterPushToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = AccountManager().currentDeviceId ??
          prefs.getString('current_device_id') ??
          prefs.getString('device_id') ??
          'unknown';
      final authToken = await AuthService.getToken();

      final options = Options(
        headers: {
          if (authToken != null) 'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      try {
        await Dio().delete(
          '${AppConfig.baseUrl}/api/sessions/push-token',
          data: {'device_id': deviceId},
          options: options,
        );
      } catch (_) {
        await Dio().delete(
          '${AppConfig.baseUrl}/api/notifications/push-token',
          data: {'device_id': deviceId},
          options: options,
        );
      }
      debugPrint('NotificationService: push token unregistered');
    } catch (e) {
      debugPrint('NotificationService: failed to unregister token: $e');
    }
  }

  // ============ FCM Handlers ============

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    debugPrint('NotificationService: FCM foreground: $data');
    _handlePushData(data);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _navigateFromNotificationData(message.data);
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await _firebaseMessaging?.getInitialMessage();
    if (initialMessage != null) {
      _navigateFromNotificationData(initialMessage.data);
    }
  }

  // ============ HMS Handlers ============

  void _onHMSForegroundMessage(Map<String, dynamic> data) {
    debugPrint('NotificationService: HMS foreground: $data');
    _handlePushData(data);
  }

  void _onHMSMessageOpenedApp(Map<String, dynamic> data) {
    _navigateFromNotificationData(data);
  }

  // ============ Common Push Data Handler ============

  void _handlePushData(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    switch (type) {
      case 'sync_required':
        if (data.containsKey('chat_id') && data.containsKey('chat_name')) {
          showInAppBanner(
            chatId: data['chat_id']!,
            chatName: data['chat_name']!,
            senderName: data['sender_name'] ?? '',
            messageText: data['message_text'] ?? '',
            isGroup: data['is_group'] == 'true',
          );
        }
        break;
      case 'new_message':
        if (data.containsKey('chat_id')) {
          final chatId = data['chat_id']!.toString();
          final senderName = data['sender_name']?.toString() ?? '';
          final chatName = (data['chat_name']?.toString().isNotEmpty == true)
              ? data['chat_name']!.toString()
              : (senderName.isNotEmpty ? senderName : 'Theaver');
          final messageText = (data['message_text']?.toString().isNotEmpty == true)
              ? data['message_text']!.toString()
              : (data['content']?.toString() ?? 'Новое сообщение');
          final isGroup = data['is_group'] == 'true' || data['is_group'] == true;

          if (shouldShowNotification(chatId) && !_isDuplicateNotification(chatId, messageText)) {
            showInAppBanner(
              chatId: chatId,
              chatName: chatName,
              senderName: senderName,
              messageText: messageText,
              isGroup: isGroup,
            );
            showMessageNotification(
              chatId: chatId,
              chatName: chatName,
              senderName: senderName,
              messageText: messageText,
              isGroup: isGroup,
            );
          }
        }
        break;
      case 'read_status_updated':
        debugPrint('NotificationService: read status updated for chat ${data['chat_id']}');
        break;
      case 'incoming_call':
        _handleIncomingCall(data);
        break;
    }
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    showCallNotification(
      callId: data['call_id'] ?? '',
      callerName: data['caller_name'] ?? '',
      isVideo: data['is_video'] == 'true',
    );
  }

  void _navigateFromNotificationData(Map<String, dynamic> data) {
    final chatId = data['chat_id'];
    if (chatId != null) {
      debugPrint('NotificationService: should navigate to chat $chatId');
    }
  }

  // ============ Local Notifications ============

  Future<void> showMessageNotification({
    required String chatId,
    required String chatName,
    required String senderName,
    required String messageText,
    String? avatarPath,
    bool isGroup = false,
  }) async {
    if (!shouldShowNotification(chatId)) return;

    final effective = _settingsProvider?.getEffectiveSettings(chatId);
    final showPreview = effective?.previewEnabled ?? true;
    final displayChatName = chatName.isNotEmpty ? chatName : (senderName.isNotEmpty ? senderName : 'Theaver');
    final displayText = messageText.isNotEmpty ? messageText : 'Новое сообщение';
    final title = showPreview ? (isGroup ? '$displayChatName ($senderName)' : displayChatName) : 'Theaver';
    final body = showPreview
        ? (isGroup ? (senderName.isNotEmpty ? '$senderName: $displayText' : displayText) : displayText)
        : 'Новое сообщение';

    // Desktop (Windows, Linux, macOS)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final notification = LocalNotification(
          identifier: 'chat_$chatId',
          title: title,
          body: body,
          silent: !(effective?.soundEnabled ?? true),
        );
        notification.onClick = () async {
          await DesktopTrayService().showAndFocusWindow();
          _navigateFromNotificationData({'chat_id': chatId, 'type': 'new_message'});
        };
        await notification.show();
      } catch (e) {
        debugPrint('NotificationService: desktop local_notifier show error: $e');
      }
      return;
    }

    // Android / iOS
    final channelId = _getChannelId(chatId, isGroup, effective);
    final androidDetails = AndroidNotificationDetails(
      channelId, _channelLabel(channelId),
      channelDescription: _channelDescription(channelId),
      importance: _getImportance(effective),
      priority: _getPriority(effective),
      enableVibration: effective?.vibration != VibrationPattern.none,
      vibrationPattern: _getVibrationPattern(effective?.vibration),
      playSound: effective?.soundEnabled ?? true,
      groupKey: 'chat_$chatId',
      setAsGroupSummary: false,
      autoCancel: true,
      styleInformation: MessagingStyleInformation(
        Person(name: chatName),
        conversationTitle: isGroup ? chatName : null,
        groupConversation: isGroup,
        messages: [Message(messageText, DateTime.now(), Person(name: senderName))],
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true, presentBanner: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _localNotifications.show(chatId.hashCode, title, body, details, payload: chatId);
  }

  Future<void> showCallNotification({
    required String callId,
    required String callerName,
    bool isVideo = false,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'calls', 'Звонки',
      channelDescription: 'Уведомления о входящих звонках',
      importance: Importance.max, priority: Priority.max,
      autoCancel: false, ongoing: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _localNotifications.show(
      callId.hashCode, isVideo ? 'Видеозвонок' : 'Звонок', callerName, details,
      payload: 'call_$callId',
    );
  }

  void updateUnreadCount(int count) {
    _unreadCount = count;
    if (Platform.isAndroid && count > 0) {
      _showBadgeSummary(count);
    } else if (Platform.isAndroid && count == 0) {
      _localNotifications.cancel(-1);
    }
  }

  Future<void> _showBadgeSummary(int count) async {
    const androidDetails = AndroidNotificationDetails(
      'silent', 'Беззвучные',
      channelDescription: 'Счётчик непрочитанных',
      importance: Importance.low, priority: Priority.low,
      playSound: false, enableVibration: false,
      setAsGroupSummary: true, groupKey: 'theaver_summary', autoCancel: false,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(-1, 'Theaver', '$count непрочитанных', details);
  }

  Future<void> cancelChatNotifications(String chatId) async {
    await _localNotifications.cancel(chatId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ============ Logic ============

  bool shouldShowNotification(String chatId, {bool isMention = false}) {
    if (chatId.isNotEmpty && currentActiveChatId == chatId) {
      return false;
    }
    if (_settingsProvider == null) return true;
    return _settingsProvider!.shouldShowNotification(chatId, isMention: isMention);
  }

  void showInAppBanner({
    required String chatId,
    required String chatName,
    required String senderName,
    required String messageText,
    String? avatarUrl,
    bool isGroup = false,
  }) {
    if (!shouldShowNotification(chatId)) return;
    final data = InAppNotificationData(
      chatId: chatId, chatName: chatName, senderName: senderName,
      messageText: messageText, avatarUrl: avatarUrl, isGroup: isGroup,
      timestamp: DateTime.now(),
    );
    _currentBanner = data;
    _bannerController.add(data);
  }

  void dismissBanner() {
    _currentBanner = null;
    _bannerController.add(null);
  }

  // ============ Local Notification Tap ============

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    if (payload.startsWith('call_')) {
      debugPrint('NotificationService: call notification tapped');
    } else {
      _navigateFromNotificationData({'chat_id': payload, 'type': 'new_message'});
    }
  }

  // ============ Helpers ============

  String _getChannelId(String chatId, bool isGroup, EffectiveChatSettings? effective) {
    if (effective?.isMuted == true) return 'silent';
    if (effective?.mentionsOnly == true) return 'mentions';
    if (isGroup) return 'group_chats';
    return 'private_chats';
  }

  String _channelLabel(String id) => {
    'private_chats': 'Личные чаты', 'group_chats': 'Групповые чаты',
    'channels': 'Каналы', 'calls': 'Звонки', 'mentions': 'Упоминания',
    'silent': 'Беззвучные',
  }[id] ?? 'Уведомления';

  String _channelDescription(String id) => {
    'private_chats': 'Уведомления о новых сообщениях в личных чатах',
    'group_chats': 'Уведомления о новых сообщениях в группах',
    'channels': 'Уведомления о новых постах в каналах',
    'calls': 'Уведомления о входящих звонках',
    'mentions': 'Уведомления об @упоминаниях',
    'silent': 'Тихие уведомления — только бейдж',
  }[id] ?? 'Уведомления Theaver';

  Importance _getImportance(EffectiveChatSettings? e) =>
      e?.isMuted == true ? Importance.low : Importance.high;
  Priority _getPriority(EffectiveChatSettings? e) =>
      e?.isMuted == true ? Priority.low : Priority.high;

  Int64List? _getVibrationPattern(VibrationPattern? p) => switch (p) {
    VibrationPattern.none => null,
    VibrationPattern.short => Int64List.fromList([0, 100]),
    VibrationPattern.long => Int64List.fromList([0, 400]),
    VibrationPattern.doubleShort => Int64List.fromList([0, 100, 100, 100]),
    VibrationPattern.tripleShort => Int64List.fromList([0, 100, 100, 100, 100, 100]),
    _ => null,
  };

  /// Отправляет тестовое уведомление:
  /// 1. Немедленно показывает локальное уведомление в системной шторке
  /// 2. Отображает in-app баннер в приложении
  /// 3. Вызывает серверный эндпоинт POST /api/notifications/test для проверки реального push-канала
  Future<Map<String, dynamic>> sendTestNotification() async {
    // 1. Показываем локальное уведомление в системе
    try {
      const androidDetails = AndroidNotificationDetails(
        'private_chats',
        'Личные чаты',
        channelDescription: 'Уведомления о новых сообщениях в личных чатах',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _localNotifications.show(
        99999,
        'Theaver',
        'Тестовое уведомление доставлено успешно!',
        details,
        payload: 'test',
      );
    } catch (e) {
      debugPrint('NotificationService: local test notification error: $e');
    }

    // 2. In-app баннер
    showInAppBanner(
      chatId: '0',
      chatName: 'Theaver',
      senderName: 'Тест',
      messageText: 'Локальное уведомление создано!',
      isGroup: false,
    );

    // 3. Отправляем запрос на сервер
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': true,
          'message': 'Локальное уведомление показано (на сервере вход не выполнен)',
        };
      }

      final response = await Dio().post(
        '${AppConfig.baseUrl}/api/notifications/test',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final success = data['success'] == true;
        final msg = data['message'] ?? (success ? 'Push отправлен сервером' : 'Ошибка отправки');
        final deviceCount = data['device_count'] ?? 0;
        return {
          'success': success,
          'message': '$msg (устройств: $deviceCount)',
          'device_count': deviceCount,
        };
      }
      return {
        'success': false,
        'message': 'Сервер ответил со статусом ${response.statusCode}',
      };
    } catch (e) {
      debugPrint('NotificationService: server test notification error: $e');
      return {
        'success': true,
        'message': 'Локальное уведомление показано. Ответ сервера: $e',
      };
    }
  }

  void dispose() { _bannerController.close(); }
}

/// Модель данных для in-app баннера
class InAppNotificationData {
  final String chatId;
  final String chatName;
  final String senderName;
  final String messageText;
  final String? avatarUrl;
  final bool isGroup;
  final DateTime timestamp;

  const InAppNotificationData({
    required this.chatId, required this.chatName, required this.senderName,
    required this.messageText, this.avatarUrl, this.isGroup = false,
    required this.timestamp,
  });
}
