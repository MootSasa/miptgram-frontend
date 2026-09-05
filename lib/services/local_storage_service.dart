import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_service.dart';
import 'auth_service.dart';

/// LocalStorageService handles local caching of chats and messages
/// for offline access and faster loading.
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // Key prefixes for storage
  static const String _chatsKeyPrefix = 'chats_';
  static const String _messagesKeyPrefix = 'messages_';
  static const String _lastSyncKeyPrefix = 'last_sync_';

  /// Convert Chat to JSON map
  Map<String, dynamic> _chatToJson(Chat c) {
    return {
      'id': c.id,
      'chat_type': c.chatType,
      'name': c.name,
      'avatar_url': c.avatarUrl,
      'last_message': c.lastMessage,
      'last_message_time': c.lastMessageTime,
      'updated_at': c.updatedAt,
      'unread_count': c.unreadCount,
      'is_online': c.isOnline,
      'last_seen': c.lastSeen,
      'is_pinned': c.isPinned,
      'other_user_id': c.otherUserId,
    };
  }

  /// Convert Message to JSON map
  Map<String, dynamic> _messageToJson(Message m) {
    return {
      'id': m.id,
      'chat_id': m.chatId,
      'sender_id': m.senderId,
      'content': m.content,
      'message_type': m.messageType,
      'is_edited': m.isEdited,
      'created_at': m.createdAt,
      'sender_name': m.senderName,
      'sender_avatar_url': m.senderAvatarUrl,
      'file_url': m.fileUrl,
      'file_name': m.fileName,
      'reply_to_message_id': m.replyToMessageId,
      'is_read': m.isRead,
      'read_at': m.readAt,
      // Reply / Quote fields
      'is_quote': m.isQuote,
      'quote_text': m.quoteText,
      'quote_offset': m.quoteOffset,
      'quote_length': m.quoteLength,
      // Cached reply preview
      'reply_info': m.replyInfo?.toJson(),
    };
  }

  /// Save chats to local storage
  Future<void> saveChats(List<Chat> chats) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final key = '$_chatsKeyPrefix$userId';
      
      final chatsJson = jsonEncode(chats.map(_chatToJson).toList());

      await prefs.setString(key, chatsJson);
      await prefs.setString('$_lastSyncKeyPrefix$userId', DateTime.now().toIso8601String());
      
      debugPrint('LocalStorage: Saved ${chats.length} chats for user $userId');
    } catch (e) {
      debugPrint('LocalStorage: Error saving chats: $e');
    }
  }

  /// Load chats from local storage
  Future<List<Chat>> loadChats() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final key = '$_chatsKeyPrefix$userId';
      
      final chatsJson = prefs.getString(key);
      if (chatsJson == null) return [];

      final List<dynamic> chatsList = jsonDecode(chatsJson);
      final chats = chatsList.map((c) => Chat.fromJson(c as Map<String, dynamic>)).toList();
      
      debugPrint('LocalStorage: Loaded ${chats.length} chats for user $userId');
      return chats;
    } catch (e) {
      debugPrint('LocalStorage: Error loading chats: $e');
      return [];
    }
  }

  /// Save messages for a specific chat
  Future<void> saveMessages(String chatId, List<Message> messages) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final key = '$_messagesKeyPrefix${userId}_$chatId';
      
      final messagesJson = jsonEncode(messages.map(_messageToJson).toList());

      await prefs.setString(key, messagesJson);
      debugPrint('LocalStorage: Saved ${messages.length} messages for chat $chatId');
    } catch (e) {
      debugPrint('LocalStorage: Error saving messages: $e');
    }
  }

  /// Load messages for a specific chat
  Future<List<Message>> loadMessages(String chatId) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final key = '$_messagesKeyPrefix${userId}_$chatId';
      
      final messagesJson = prefs.getString(key);
      if (messagesJson == null) return [];

      final List<dynamic> messagesList = jsonDecode(messagesJson);
      final messages = messagesList.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList();
      
      debugPrint('LocalStorage: Loaded ${messages.length} messages for chat $chatId');
      return messages;
    } catch (e) {
      debugPrint('LocalStorage: Error loading messages: $e');
      return [];
    }
  }

  /// Update a single chat in local storage
  Future<void> updateChat(Chat updatedChat) async {
    try {
      final chats = await loadChats();
      final index = chats.indexWhere((c) => c.id == updatedChat.id);
      
      if (index != -1) {
        chats[index] = updatedChat;
      } else {
        chats.insert(0, updatedChat);
      }
      
      await saveChats(chats);
    } catch (e) {
      debugPrint('LocalStorage: Error updating chat: $e');
    }
  }

  /// Remove a chat from local storage
  Future<void> removeChat(String chatId) async {
    try {
      final chats = await loadChats();
      chats.removeWhere((c) => c.id == chatId);
      await saveChats(chats);
      
      // Also remove messages for this chat
      final userId = await AuthService.getUserId();
      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        final key = '$_messagesKeyPrefix${userId}_$chatId';
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('LocalStorage: Error removing chat: $e');
    }
  }

  /// Update unread count for a chat
  Future<void> updateUnreadCount(String chatId, int unreadCount) async {
    try {
      final chats = await loadChats();
      final index = chats.indexWhere((c) => c.id == chatId);
      
      if (index != -1) {
        chats[index] = chats[index].copyWith(unreadCount: unreadCount);
        await saveChats(chats);
      }
    } catch (e) {
      debugPrint('LocalStorage: Error updating unread count: $e');
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final key = '$_lastSyncKeyPrefix$userId';
      
      final syncTimeStr = prefs.getString(key);
      if (syncTimeStr == null) return null;
      
      return DateTime.parse(syncTimeStr);
    } catch (e) {
      debugPrint('LocalStorage: Error getting last sync time: $e');
      return null;
    }
  }

  /// Clear all local data for current user
  Future<void> clearUserData() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys and remove those belonging to this user
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('$_chatsKeyPrefix$userId') ||
            key.startsWith('$_messagesKeyPrefix${userId}_') ||
            key.startsWith('$_lastSyncKeyPrefix$userId')) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('LocalStorage: Cleared all data for user $userId');
    } catch (e) {
      debugPrint('LocalStorage: Error clearing user data: $e');
    }
  }

  /// Check if we have cached data
  Future<bool> hasCachedData() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final key = '$_chatsKeyPrefix$userId';
      
      return prefs.containsKey(key);
    } catch (e) {
      debugPrint('LocalStorage: Error checking cached data: $e');
      return false;
    }
  }
}
