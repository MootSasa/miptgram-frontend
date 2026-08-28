import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'avatar_sync_service.dart';
import 'chat_service.dart';
import 'websocket_service.dart';
import 'database/app_database.dart';

/// Сервис синхронизации данных между сервером и локальной БД (Drift/SQLite)
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final AppDatabase _db = AppDatabase();
  // ignore: unused_field — будет использоваться для real-time sync через WebSocket
  final WebSocketService _ws = WebSocketService();
  final _uuid = const Uuid();

  /// Инициализация: открыть БД, запустить первичную синхронизацию
  Future<void> initialize() async {
    await _db.initialize();
    await syncFromServer();
  }

  /// Delta Sync: получить обновления с сервера и применить к локальной БД
  Future<void> syncFromServer() async {
    final userId = await AuthService.getUserId();
    if (userId == null) return;

    // Запуск отложенной синхронизации аватарок
    AvatarSyncService().syncPendingAvatar(userId);

    final lastUsn = await _db.getLastKnownUsn(userId);
    debugPrint('SyncService: Starting delta sync from USN $lastUsn');

    try {
      final result = await ChatService.getUpdates(sinceUsn: lastUsn);
      if (result['success'] != true) {
        debugPrint('SyncService: Delta sync failed: ${result['message']}');
        return;
      }

      final events = result['events'] as List<dynamic>? ?? [];
      final maxUsn = result['max_usn'] as int? ?? lastUsn;
      final hasMore = result['has_more'] as bool? ?? false;

      for (final event in events) {
        await _applyEvent(event as Map<String, dynamic>);
      }

      // Обновить USN
      await _db.setLastKnownUsn(userId, maxUsn);
      debugPrint(
          'SyncService: Applied ${events.length} events, new USN=$maxUsn, hasMore=$hasMore');

      // Если есть ещё события — продолжить синхронизацию
      if (hasMore) {
        await syncFromServer();
      }
    } catch (e) {
      debugPrint('SyncService: Error during delta sync: $e');
    }
  }

  /// Применить одно событие обновления к локальной БД
  Future<void> _applyEvent(Map<String, dynamic> event) async {
    final eventType = event['event_type'] as String?;
    final payload = event['payload'] as Map<String, dynamic>? ?? {};
    final chatId = event['chat_id']?.toString();

    switch (eventType) {
      case 'new_message':
        await _applyNewMessage(payload);
        break;
      case 'edit_message':
        await _applyEditMessage(payload);
        break;
      case 'delete_message':
        await _applyDeleteMessage(payload);
        break;
      case 'read_status':
        await _applyReadStatus(payload);
        break;
      case 'new_chat':
        await _applyNewChat(payload);
        break;
      case 'chat_update':
        await _applyChatUpdate(payload);
        break;
      case 'delete_chat':
        if (chatId != null) {
          await _db.deleteChat(chatId);
          await _db.deleteMessagesForChat(chatId);
        }
        break;
      default:
        debugPrint('SyncService: Unknown event type: $eventType');
    }
  }

  Future<void> _applyNewMessage(Map<String, dynamic> payload) async {
    final serverId = payload['message_id']?.toString();
    final chatId = payload['chat_id']?.toString();
    if (serverId == null || chatId == null) return;

    // Проверить, есть ли уже это сообщение (по serverId)
    final existing = await _db.getMessageByServerId(serverId);
    if (existing != null) return; // Уже есть — пропускаем

    await _db.saveMessage(MessagesCompanion(
      serverId: Value(serverId),
      localId: Value(_uuid.v4()),
      chatId: Value(chatId),
      senderId: Value(payload['sender_id']?.toString() ?? ''),
      content: Value(payload['content']?.toString() ?? ''),
      messageType: Value(payload['message_type']?.toString() ?? 'text'),
      fileUrl: Value(payload['file_url']?.toString()),
      fileName: Value(payload['file_name']?.toString()),
      replyToMessageId: Value(payload['reply_to_message_id']?.toString()),
      isQuote: Value(payload['is_quote'] as bool? ?? false),
      quoteText: Value(payload['quote_text']?.toString()),
      quoteOffset: Value(payload['quote_offset'] as int? ?? 0),
      quoteLength: Value(payload['quote_length'] as int? ?? 0),
      replyToSenderId: Value(payload['reply_to_sender_id']?.toString()),
      replyToSenderName: Value(payload['reply_to_sender_name']?.toString()),
      replyToContent: Value(payload['reply_to_content']?.toString()),
      replyToMessageType:
          Value(payload['reply_to_message_type']?.toString() ?? 'text'),
      isRead: const Value(false),
      isEdited: const Value(false),
      sendStatus: Value(MessageSendStatus.sent.index),
      senderName: Value(payload['sender_name']?.toString()),
      senderAvatarUrl: Value(payload['sender_avatar_url']?.toString()),
      createdAt: Value(payload['created_at']?.toString() ??
          DateTime.now().toIso8601String()),
    ));
  }

  Future<void> _applyEditMessage(Map<String, dynamic> payload) async {
    final serverId = payload['message_id']?.toString();
    if (serverId == null) return;

    await _db.updateMessageContent(
        serverId, payload['content']?.toString() ?? '');
  }

  Future<void> _applyDeleteMessage(Map<String, dynamic> payload) async {
    final serverId = payload['message_id']?.toString();
    if (serverId == null) return;
    await _db.deleteMessage(serverId);
  }

  Future<void> _applyReadStatus(Map<String, dynamic> payload) async {
    final chatId = payload['chat_id']?.toString();
    final unreadCount = payload['unread_count'] as int? ?? 0;
    if (chatId == null) return;

    await _db.updateUnreadCount(chatId, unreadCount);
  }

  Future<void> _applyNewChat(Map<String, dynamic> payload) async {
    final chatId = payload['chat_id']?.toString();
    if (chatId == null) return;

    final existing = await _db.getChat(chatId);
    if (existing != null) return;

    await _db.saveChat(ChatsCompanion(
      chatId: Value(chatId),
      chatType: Value(payload['chat_type']?.toString() ?? 'private'),
      name: Value(payload['name']?.toString() ?? ''),
      avatarUrl: Value(payload['avatar_url']?.toString()),
      updatedAt: Value(payload['updated_at']?.toString() ??
          DateTime.now().toIso8601String()),
      unreadCount: const Value(0),
      isOnline: const Value(false),
      isPinned: const Value(false),
    ));
  }

  Future<void> _applyChatUpdate(Map<String, dynamic> payload) async {
    final chatId = payload['chat_id']?.toString();
    if (chatId == null) return;

    final chat = await _db.getChat(chatId);
    if (chat == null) return;

    // Build companion with only updated fields
    final companion = ChatsCompanion(
      chatId: Value(chatId),
      name: payload.containsKey('name')
          ? Value(payload['name'].toString())
          : Value(chat.name),
      avatarUrl: payload.containsKey('avatar_url')
          ? Value(payload['avatar_url']?.toString())
          : Value(chat.avatarUrl),
      unreadCount: payload.containsKey('unread_count')
          ? Value(payload['unread_count'] as int? ?? chat.unreadCount)
          : Value(chat.unreadCount),
      isPinned: payload.containsKey('is_pinned')
          ? Value(payload['is_pinned'] as bool? ?? chat.isPinned)
          : Value(chat.isPinned),
      updatedAt: payload.containsKey('updated_at')
          ? Value(payload['updated_at'].toString())
          : Value(chat.updatedAt),
    );

    await _db.saveChat(companion);
  }

  /// Создать локальное pending-сообщение (оптимистичный UI)
  Future<DbMessage> createPendingMessage({
    required String chatId,
    required String senderId,
    required String content,
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
    String? replyToMessageId,
    bool isQuote = false,
    String? quoteText,
    int quoteOffset = 0,
    int quoteLength = 0,
    String? replyToSenderId,
    String? replyToSenderName,
    String? replyToContent,
    String replyToMessageType = 'text',
  }) async {
    final localId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.saveMessage(MessagesCompanion(
      serverId: const Value.absent(), // Нет серверного ID пока
      localId: Value(localId),
      chatId: Value(chatId),
      senderId: Value(senderId),
      content: Value(content),
      messageType: Value(messageType),
      fileUrl: Value(fileUrl),
      fileName: Value(fileName),
      replyToMessageId: Value(replyToMessageId),
      isQuote: Value(isQuote),
      quoteText: Value(quoteText),
      quoteOffset: Value(quoteOffset),
      quoteLength: Value(quoteLength),
      replyToSenderId: Value(replyToSenderId),
      replyToSenderName: Value(replyToSenderName),
      replyToContent: Value(replyToContent),
      replyToMessageType: Value(replyToMessageType),
      isRead: const Value(true), // Свои сообщения всегда "прочитаны"
      isEdited: const Value(false),
      sendStatus: Value(MessageSendStatus.sending.index),
      createdAt: Value(now),
    ));

    // Return the saved message as DbMessage
    return DbMessage(
      serverId: null,
      localId: localId,
      chatId: chatId,
      senderId: senderId,
      content: content,
      messageType: messageType,
      fileUrl: fileUrl,
      fileName: fileName,
      replyToMessageId: replyToMessageId,
      isQuote: isQuote,
      quoteText: quoteText,
      quoteOffset: quoteOffset,
      quoteLength: quoteLength,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      replyToMessageType: replyToMessageType,
      isRead: true,
      isEdited: false,
      sendStatus: MessageSendStatus.sending.index,
      senderName: null,
      senderAvatarUrl: null,
      createdAt: now,
      isForward: false,
      forwardFromId: null,
      forwardFromName: null,
    );
  }

  /// Подтвердить отправку — заменить localId на serverId
  Future<void> confirmMessageSent(String localId, String serverId) async {
    await _db.updateMessageSendStatus(
        localId, serverId, MessageSendStatus.sent.index);
  }

  /// Пометить сообщение как failed
  Future<void> markMessageFailed(String localId) async {
    await _db.updateMessageStatus(localId, MessageSendStatus.failed.index);
  }

  /// Повторить отправку failed-сообщения
  Future<void> retryFailedMessage(String localId) async {
    final msg = await _db.getMessageByLocalId(localId);
    if (msg == null || msg.sendStatus != MessageSendStatus.failed.index) return;

    await _db.updateMessageStatus(localId, MessageSendStatus.sending.index);

    try {
      final result = await ChatService.sendMessage(
        chatId: msg.chatId,
        content: msg.content,
        messageType: msg.messageType,
        localId: msg.localId,
        fileUrl: msg.fileUrl,
        fileName: msg.fileName,
      );

      if (result['success'] == true) {
        // result['message'] is a Message object, not a Map
        final sentMessage = result['message'];
        final serverId = sentMessage is Message ? sentMessage.id : null;
        if (serverId != null && serverId.isNotEmpty) {
          await confirmMessageSent(localId, serverId);
        }
      } else {
        await markMessageFailed(localId);
      }
    } catch (e) {
      debugPrint('SyncService: Retry failed: $e');
      await markMessageFailed(localId);
    }
  }
}
