import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'notification_settings_provider.dart';
import 'notification_service_hms.dart';
import 'push_service_detector.dart';
import 'settings_service.dart';
import '../config/app_config.dart';

/// Фоновый обработчик FCM сообщений (должен быть top-level функцией)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final localNotifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await localNotifications.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );
  final data = message.data;
  if (data.containsKey('chat_id') && data.containsKey('chat_name')) {
    await _showBackgroundNotification(localNotifications, data);
  }
}

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
  final chatName = data['chat_name'] ?? 'Miptgram';
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
  FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  HMSPushService? _hmsPushService;
  PushServiceDetector _detector = PushServiceDetector();

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

  /// Полная инициализация: детектирование + Firebase/HMS + Local Notifications
  Future<void> init(NotificationSettingsProvider settingsProvider) async {
    if (_initialized) return;
    _settingsProvider = settingsProvider;

    try {
      // 1. Детектирование push-сервиса
      await _detector.detect();
      debugPrint('NotificationService: detected push service = ${_detector.serviceType}');

      // 2. Инициализация локальных уведомлений
      await _initLocalNotifications();

      // 3. Создание Android notification channels
      await _createNotificationChannels();

      // 4. Инициализация push-сервиса в зависимости от детекта
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

      _initialized = true;
      debugPrint('NotificationService: fully initialized (${_detector.serviceType})');
    } catch (e) {
      debugPrint('NotificationService: initialization error: $e');
      _initialized = true;
    }
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
    debugPrint('NotificationService: HMS push token=${_pushToken?.substring(0, 20)}...');

    if (_pushToken != null) {
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
      final deviceId = prefs.getString('device_id') ?? 'unknown';
      await Dio().post(
        '${AppConfig.baseUrl}/api/notifications/push-token',
        data: {'token': token, 'type': type, 'device_id': deviceId},
      );
      debugPrint('NotificationService: $type push token registered on server');
    } catch (e) {
      debugPrint('NotificationService: failed to register $type token: $e');
    }
  }

  Future<void> unregisterPushToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown';
      await Dio().delete(
        '${AppConfig.baseUrl}/api/notifications/push-token',
        data: {'device_id': deviceId},
      );
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
          final chatId = data['chat_id']!;
          if (shouldShowNotification(chatId)) {
            showInAppBanner(
              chatId: chatId,
              chatName: data['chat_name'] ?? '',
              senderName: data['sender_name'] ?? '',
              messageText: data['message_text'] ?? '',
              isGroup: data['is_group'] == 'true',
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
    final showPreview = effective?.previewEnabled ?? true;
    final title = showPreview ? chatName : 'Miptgram';
    final body = showPreview
        ? (isGroup ? '$senderName: $messageText' : messageText)
        : 'Новое сообщение';

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
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
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
      setAsGroupSummary: true, groupKey: 'miptgram_summary', autoCancel: false,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(-1, 'Miptgram', '$count непрочитанных', details);
  }

  Future<void> cancelChatNotifications(String chatId) async {
    await _localNotifications.cancel(chatId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ============ Logic ============

  bool shouldShowNotification(String chatId, {bool isMention = false}) {
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
  }[id] ?? 'Уведомления Miptgram';

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
