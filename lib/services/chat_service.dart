import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import 'database/app_database.dart';

/// Chat represents a chat conversation.
class Chat {
  final String id;
  final String chatType; // 'private', 'group', 'channel', 'saved'
  final String name;
  final String? avatarUrl;
  final String? lastMessage;
  final String? lastMessageTime;
  final String updatedAt;
  final int unreadCount;
  final bool isOnline; // Online status for private chats
  final String? lastSeen; // Last seen time for private chats
  final bool isPinned; // Whether chat is pinned

  Chat({
    required this.id,
    required this.chatType,
    required this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    required this.updatedAt,
    this.unreadCount = 0,
    this.isOnline = false,
    this.lastSeen,
    this.isPinned = false,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id']?.toString() ?? '',
      chatType: json['chat_type']?.toString() ?? 'private',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageTime: json['last_message_time']?.toString(),
      updatedAt: json['updated_at']?.toString() ?? '',
      unreadCount: json['unread_count'] ?? 0,
      isOnline: json['is_online'] ?? false,
      lastSeen: json['last_seen']?.toString(),
      isPinned: json['is_pinned'] ?? false,
    );
  }

  Chat copyWith({
    String? id,
    String? chatType,
    String? name,
    String? avatarUrl,
    String? lastMessage,
    String? lastMessageTime,
    String? updatedAt,
    int? unreadCount,
    bool? isOnline,
    String? lastSeen,
    bool? isPinned,
  }) {
    return Chat(
      id: id ?? this.id,
      chatType: chatType ?? this.chatType,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

/// ReplyInfo holds cached preview data for the message being replied to.
/// Stored inline with the message for offline-first display without lookup.
class ReplyInfo {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content; // truncated preview text
  final String messageType; // 'text', 'image', etc.
  final String? chatId; // The chat ID where the original message resides

  const ReplyInfo({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.messageType,
    this.chatId,
  });

  factory ReplyInfo.fromJson(Map<String, dynamic> json) {
    return ReplyInfo(
      messageId: json['message_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? 'text',
      chatId: json['chat_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'message_id': messageId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'message_type': messageType,
        if (chatId != null) 'chat_id': chatId,
      };
}

/// MessageEntity represents a formatted range in text (Bold, Italic, Spoiler, Code, Link, etc.).
class MessageEntity {
  final String type; // 'bold', 'italic', 'code', 'spoiler', 'strikethrough', 'underline', 'link', 'mention', 'blockquote'
  final int offset;
  final int length;
  final String? url;

  const MessageEntity({
    required this.type,
    required this.offset,
    required this.length,
    this.url,
  });

  factory MessageEntity.fromJson(Map<String, dynamic> json) {
    return MessageEntity(
      type: json['type']?.toString() ?? 'bold',
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      length: (json['length'] as num?)?.toInt() ?? 0,
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'offset': offset,
        'length': length,
        if (url != null) 'url': url,
      };
}

/// Message represents a message in a chat.
class Message {
  final String id; // serverId или localId если pending
  final String chatId;
  final String senderId;
  final String content;
  final String messageType;
  final bool isEdited;
  final String createdAt;
  final String senderName;
  final String? senderAvatarUrl;
  final String? fileUrl;
  final String? fileName;
  final String? replyToMessageId;
  final bool isRead;
  final String? readAt;

  // Reply / Quote fields
  final bool isQuote; // true = quote (partial text), false = full reply
  final String? quoteText; // выделенный текст цитаты
  final int quoteOffset; // смещение начала цитаты в оригинальном сообщении
  final int quoteLength; // длина цитируемого фрагмента

  // Cached reply preview (for offline-first display without lookup)
  final ReplyInfo? replyInfo;

  final String? localId; // UUID для pending-сообщений
  final int sendStatus; // 0=sending, 1=sent, 2=failed (MessageSendStatus)

  // Forwarding fields
  final bool isForward;
  final String? forwardFromId;
  final String? forwardFromName;

  // Album grouping and text formatting entities
  final String? groupedId;
  final List<MessageEntity> entities;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.messageType,
    required this.isEdited,
    required this.createdAt,
    required this.senderName,
    this.senderAvatarUrl,
    this.fileUrl,
    this.fileName,
    this.replyToMessageId,
    this.isRead = false,
    this.readAt,
    this.isQuote = false,
    this.quoteText,
    this.quoteOffset = 0,
    this.quoteLength = 0,
    this.replyInfo,
    this.localId,
    this.sendStatus = 1, // по умолчанию sent
    this.isForward = false,
    this.forwardFromId,
    this.forwardFromName,
    this.groupedId,
    this.entities = const [],
  });

  /// Whether this message has a reply or quote
  bool get hasReply => replyToMessageId != null && replyToMessageId!.isNotEmpty;

  factory Message.fromJson(Map<String, dynamic> json) {
    // Parse replyInfo from nested object or flat fields
    ReplyInfo? replyInfo;
    if (json['reply_info'] != null && json['reply_info'] is Map) {
      replyInfo =
          ReplyInfo.fromJson(json['reply_info'] as Map<String, dynamic>);
    } else if (json['reply_to_message_id'] != null) {
      // Fallback: build ReplyInfo from flat fields
      replyInfo = ReplyInfo(
        messageId: json['reply_to_message_id']?.toString() ?? '',
        senderId: json['reply_to_sender_id']?.toString() ?? '',
        senderName: json['reply_to_sender_name']?.toString() ?? '',
        content: json['reply_to_content']?.toString() ?? '',
        messageType: json['reply_to_message_type']?.toString() ?? 'text',
      );
    }

    return Message(
      id: json['id']?.toString() ?? '',
      chatId: json['chat_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? 'text',
      isEdited: json['is_edited'] ?? false,
      createdAt: json['created_at']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Unknown',
      senderAvatarUrl: json['sender_avatar_url']?.toString(),
      fileUrl: json['file_url']?.toString(),
      fileName: json['file_name']?.toString(),
      replyToMessageId: json['reply_to_message_id']?.toString(),
      isRead: json['is_read'] ?? false,
      readAt: json['read_at']?.toString(),
      isQuote: json['is_quote'] ?? false,
      quoteText: json['quote_text']?.toString(),
      quoteOffset: json['quote_offset'] as int? ?? 0,
      quoteLength: json['quote_length'] as int? ?? 0,
      replyInfo: replyInfo,
      localId: json['local_id']?.toString(),
      sendStatus: json['send_status'] ?? 1,
      isForward: json['is_forward'] ?? false,
      forwardFromId: json['forward_from_id']?.toString(),
      forwardFromName: json['forward_from_name']?.toString(),
      groupedId: json['grouped_id']?.toString(),
      entities: (json['entities'] as List?)
              ?.map((e) => MessageEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Создать Message из Drift DbMessage
  factory Message.fromDbMessage(DbMessage model) {
    // Build ReplyInfo from cached fields
    ReplyInfo? replyInfo;
    if (model.replyToMessageId != null) {
      replyInfo = ReplyInfo(
        messageId: model.replyToMessageId!,
        senderId: model.replyToSenderId ?? '',
        senderName: model.replyToSenderName ?? '',
        content: model.replyToContent ?? '',
        messageType: model.replyToMessageType,
      );
    }

    List<MessageEntity> parsedEntities = [];
    if (model.entities != null && model.entities!.isNotEmpty) {
      try {
        final decoded = jsonDecode(model.entities!) as List;
        parsedEntities = decoded
            .map((e) => MessageEntity.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return Message(
      id: model.serverId ?? model.localId,
      chatId: model.chatId,
      senderId: model.senderId,
      content: model.content,
      messageType: model.messageType,
      isEdited: model.isEdited,
      createdAt: model.createdAt,
      senderName: model.senderName ?? '',
      senderAvatarUrl: model.senderAvatarUrl,
      fileUrl: model.fileUrl,
      fileName: model.fileName,
      replyToMessageId: model.replyToMessageId,
      isRead: model.isRead,
      isQuote: model.isQuote,
      quoteText: model.quoteText,
      quoteOffset: model.quoteOffset,
      quoteLength: model.quoteLength,
      replyInfo: replyInfo,
      localId: model.localId,
      sendStatus: model.sendStatus,
      isForward: model.isForward,
      forwardFromId: model.forwardFromId,
      forwardFromName: model.forwardFromName,
      groupedId: model.groupedId,
      entities: parsedEntities,
    );
  }

  /// Copy with method for updating message state
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    String? messageType,
    bool? isEdited,
    String? createdAt,
    String? senderName,
    String? senderAvatarUrl,
    String? fileUrl,
    String? fileName,
    String? replyToMessageId,
    bool? isRead,
    String? readAt,
    bool? isQuote,
    String? quoteText,
    int? quoteOffset,
    int? quoteLength,
    ReplyInfo? replyInfo,
    String? localId,
    int? sendStatus,
    bool? isForward,
    String? forwardFromId,
    String? forwardFromName,
    String? groupedId,
    List<MessageEntity>? entities,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isQuote: isQuote ?? this.isQuote,
      quoteText: quoteText ?? this.quoteText,
      quoteOffset: quoteOffset ?? this.quoteOffset,
      quoteLength: quoteLength ?? this.quoteLength,
      replyInfo: replyInfo ?? this.replyInfo,
      localId: localId ?? this.localId,
      sendStatus: sendStatus ?? this.sendStatus,
      isForward: isForward ?? this.isForward,
      forwardFromId: forwardFromId ?? this.forwardFromId,
      forwardFromName: forwardFromName ?? this.forwardFromName,
      groupedId: groupedId ?? this.groupedId,
      entities: entities ?? this.entities,
    );
  }
}

/// ChatDetails represents detailed information about a chat.
class ChatDetails {
  final String id;
  final String chatType;
  final String name;
  final String? avatarUrl;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final List<ChatParticipant> participants;

  ChatDetails({
    required this.id,
    required this.chatType,
    required this.name,
    this.avatarUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
  });

  factory ChatDetails.fromJson(Map<String, dynamic> json) {
    var participantsList = <ChatParticipant>[];
    if (json['participants'] != null && json['participants'] is List) {
      for (var p in json['participants']) {
        participantsList.add(ChatParticipant.fromJson(p));
      }
    }
    return ChatDetails(
      id: json['id']?.toString() ?? '',
      chatType: json['chat_type']?.toString() ?? 'private',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      participants: participantsList,
    );
  }
}

/// ChatParticipant represents a participant in a chat.
class ChatParticipant {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String role;

  ChatParticipant({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.role,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString() ?? 'member',
    );
  }
}

/// ChatService handles all chat-related API operations.
class ChatService {
  /// Creates a new chat.
  ///
  /// [chatType] - Type of chat: 'private', 'group', or 'channel'
  /// [name] - Name for group/channel (optional for private)
  /// [participantIds] - List of user IDs to add as participants
  static Future<Map<String, dynamic>> createChat({
    required String chatType,
    String? name,
    required List<String> participantIds,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'chat_type': chatType,
          'name': name,
          'participant_ids': participantIds,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'chat': Chat.fromJson(data['chat']),
          'message': data['message'] ?? 'Chat created successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create chat',
        };
      }
    } catch (e) {
      debugPrint('Create chat error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Gets the list of chats for the current user.
  static Future<Map<String, dynamic>> getChats() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'chats': <Chat>[]
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/chats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        List<Chat> chats = [];
        if (data['chats'] != null && data['chats'] is List) {
          for (var chat in data['chats']) {
            chats.add(Chat.fromJson(chat));
          }
        }
        return {'success': true, 'chats': chats};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get chats',
          'chats': <Chat>[],
        };
      }
    } catch (e) {
      debugPrint('Get chats error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'chats': <Chat>[]
      };
    }
  }

  /// Gets detailed information about a specific chat.
  static Future<Map<String, dynamic>> getChat(String chatId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'chat': ChatDetails.fromJson(data['chat']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get chat',
        };
      }
    } catch (e) {
      debugPrint('Get chat error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Gets messages for a specific chat.
  ///
  /// [chatId] - The ID of the chat
  /// [limit] - Maximum number of messages to return (default: 50)
  /// [offset] - Number of messages to skip (for pagination, legacy)
  /// [beforeMessageId] - Cursor-based pagination: load messages older than this ID
  static Future<Map<String, dynamic>> getMessages({
    required String chatId,
    int limit = 50,
    int offset = 0,
    String? beforeMessageId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'messages': <Message>[]
        };
      }

      var url = '${AppConfig.baseUrl}/api/chats/$chatId/messages?limit=$limit';
      if (beforeMessageId != null) {
        url += '&before_message_id=$beforeMessageId';
      } else if (offset > 0) {
        url += '&offset=$offset';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        List<Message> messages = [];
        if (data['messages'] != null && data['messages'] is List) {
          for (var msg in data['messages']) {
            messages.add(Message.fromJson(msg));
          }
        }
        return {
          'success': true,
          'messages': messages,
          'has_more': data['has_more'] ?? false,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get messages',
          'messages': <Message>[],
        };
      }
    } catch (e) {
      debugPrint('Get messages error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'messages': <Message>[]
      };
    }
  }

  /// Delta Sync: получить обновления с сервера после указанного USN
  ///
  /// [sinceUsn] - Last known Update Sequence Number
  /// [limit] - Maximum number of events to return (default: 100)
  static Future<Map<String, dynamic>> getUpdates({
    required int sinceUsn,
    int limit = 100,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse(
            '${AppConfig.baseUrl}/api/updates?since_usn=$sinceUsn&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'events': data['events'] ?? [],
          'max_usn': data['max_usn'] ?? sinceUsn,
          'has_more': data['has_more'] ?? false,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get updates',
        };
      }
    } catch (e) {
      debugPrint('Get updates error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Sends a message to a chat.
  ///
  /// [chatId] - The ID of the chat
  /// [content] - The message content
  /// [messageType] - Type of message: 'text', 'image', 'video', 'file', 'audio', etc.
  /// [fileUrl] - URL of the file (for media messages)
  /// [fileName] - Name of the file (for file messages)
  /// [replyToMessageId] - ID of the message being replied to (optional)
  /// [localId] - Local message ID for offline-first tracking (optional)
  /// [isQuote] - Whether this is a quote (partial text) reply (optional)
  /// [quoteText] - The quoted text fragment (optional)
  /// [quoteOffset] - Offset of the quote in the original message (optional)
  /// [quoteLength] - Length of the quoted fragment (optional)
  static Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
    String? replyToMessageId,
    String? localId,
    bool isQuote = false,
    String? quoteText,
    int quoteOffset = 0,
    int quoteLength = 0,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = <String, dynamic>{
        'content': content,
        'message_type': messageType,
      };
      if (fileUrl != null) body['file_url'] = fileUrl;
      if (fileName != null) body['file_name'] = fileName;
      if (replyToMessageId != null) {
        body['reply_to_message_id'] = replyToMessageId;
        if (isQuote) {
          body['is_quote'] = true;
          if (quoteText != null) body['quote_text'] = quoteText;
          if (quoteOffset > 0) body['quote_offset'] = quoteOffset;
          if (quoteLength > 0) body['quote_length'] = quoteLength;
        }
      }
      if (localId != null) body['local_id'] = localId;

      if (AppConfig.enableDebugLogging) {
        debugPrint(
            'SendMessage: POST ${AppConfig.baseUrl}/api/chats/$chatId/messages');
        debugPrint('SendMessage: body = $body');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (AppConfig.enableDebugLogging) {
        debugPrint(
            'SendMessage: Response ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': Message.fromJson(data['message']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send message',
        };
      }
    } catch (e) {
      debugPrint('Send message error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Marks all messages in a chat as read.
  ///
  /// [chatId] - The ID of the chat
  static Future<Map<String, dynamic>> markMessagesAsRead({
    required String chatId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/messages/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'marked_count': data['marked_count'] ?? 0,
          'unread_count': data['unread_count'] ?? 0,
          'message': data['message'] ?? 'Messages marked as read',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to mark messages as read',
        };
      }
    } catch (e) {
      debugPrint('Mark messages as read error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Clears the chat history for a specific chat.
  ///
  /// [chatId] - The ID of the chat to clear
  static Future<Map<String, dynamic>> clearChatHistory({
    required String chatId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Chat history cleared',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to clear chat history',
        };
      }
    } catch (e) {
      debugPrint('Clear chat history error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Blocks a user.
  ///
  /// [userId] - The ID of the user to block
  static Future<Map<String, dynamic>> blockUser({
    required String userId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/users/$userId/block'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'User blocked successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to block user',
        };
      }
    } catch (e) {
      debugPrint('Block user error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Sets mute status for chat notifications.
  ///
  /// [chatId] - The ID of the chat
  /// [muted] - Whether to mute or unmute notifications
  static Future<Map<String, dynamic>> setMuteNotifications({
    required String chatId,
    required bool muted,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'muted': muted}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'muted': data['muted'] ?? muted,
          'message': data['message'] ?? 'Notification settings updated',
        };
      } else {
        return {
          'success': false,
          'message':
              data['message'] ?? 'Failed to update notification settings',
        };
      }
    } catch (e) {
      debugPrint('Set mute notifications error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Marks all messages up to a specific message as read.
  /// Used for progressive read tracking as user scrolls through messages.
  ///
  /// [chatId] - The ID of the chat
  /// [messageId] - The ID of the message up to which all messages should be marked as read
  static Future<Map<String, dynamic>> markMessagesReadUpTo({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/messages/read-up-to'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message_id': messageId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'marked_count': data['marked_count'] ?? 0,
          'unread_count': data['unread_count'] ?? 0,
          'message': data['message'] ?? 'Messages marked as read',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to mark messages as read',
        };
      }
    } catch (e) {
      debugPrint('Mark messages read up to error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Gets information about unread messages in a chat.
  /// Returns the ID of the first unread message and total unread count.
  ///
  /// [chatId] - The ID of the chat
  static Future<Map<String, dynamic>> getUnreadInfo({
    required String chatId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/unread-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'unread_count': data['unread_count'] ?? 0,
          'first_unread_message_id': data['first_unread_message_id'],
          'first_unread_message_created_at':
              data['first_unread_message_created_at'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get unread info',
        };
      }
    } catch (e) {
      debugPrint('Get unread info error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Pins a chat to the top of the chat list.
  ///
  /// [chatId] - The ID of the chat to pin
  static Future<Map<String, dynamic>> pinChat({
    required String chatId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/pin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'is_pinned': data['is_pinned'] ?? true,
          'message': data['message'] ?? 'Chat pinned successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to pin chat',
        };
      }
    } catch (e) {
      debugPrint('Pin chat error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Unpins a chat from the top of the chat list.
  ///
  /// [chatId] - The ID of the chat to unpin
  static Future<Map<String, dynamic>> unpinChat({
    required String chatId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/unpin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'is_pinned': data['is_pinned'] ?? false,
          'message': data['message'] ?? 'Chat unpinned successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to unpin chat',
        };
      }
    } catch (e) {
      debugPrint('Unpin chat error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Gets or creates the "Saved Messages" / "Favorites" chat for the current user.
  /// This is a special chat with the user themselves.
  static Future<Map<String, dynamic>> getOrCreateSavedChat() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/chats/saved'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'chat': Chat.fromJson(data['chat']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get saved chat',
        };
      }
    } catch (e) {
      debugPrint('Get saved chat error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Delete or leave a chat.
  /// - Private: removes the user from the chat
  /// - Group: if owner, deletes the entire chat; otherwise leaves
  /// - Channel: unsubscribes
  static Future<Map<String, dynamic>> deleteChat(String chatId) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete chat',
        };
      }
    } catch (e) {
      debugPrint('Delete chat error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Toggle reaction on a message (add or remove)
  static Future<Map<String, dynamic>> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/messages/$messageId/reactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'emoji': emoji}),
      );

      final data = jsonDecode(response.body);
      return {'success': data['success'] ?? false, 'active': data['active'] ?? false};
    } catch (e) {
      debugPrint('Toggle reaction error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get reactions for a message
  static Future<Map<String, dynamic>> getReactions({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/chats/$chatId/messages/$messageId/reactions'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      debugPrint('Get reactions error: $e');
      return {'success': false, 'reactions': []};
    }
  }
}
