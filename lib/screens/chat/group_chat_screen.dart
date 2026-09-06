import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/websocket_service.dart';
import '../../services/liquid_glass_provider.dart';
import '../../services/unread_count_provider.dart';
import '../../services/database/app_database.dart';
import '../../services/sync_service.dart';
import '../../services/message_context_menu_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_config.dart';
import 'package:drift/drift.dart' show Value;
import '../../utils/image_utils.dart';
import '../../utils/emoji_utils.dart';
import '../../widgets/chat/liquid_glass_input_field.dart';
import '../../widgets/chat/floating_glass_app_bar.dart';
import '../../widgets/chat/chat_scaffold.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/chat_messages_list_view.dart';
import '../../widgets/chat/visible_message_detector.dart';
import '../../widgets/chat/swipe_to_reply_wrapper.dart';
import '../../widgets/chat/unread_separator.dart';
import '../../widgets/message/message_bubble.dart';
import '../../utils/swipe_back_route.dart';
import 'private_chat_screen.dart';
import 'channel_screen.dart';
import '../../utils/date_time_utils.dart';
import 'group_info_screen.dart';
// ---------------------------------

class GroupChatScreen extends StatefulWidget {
  static const String routeName = '/group_chat';

  final String chatId;
  final String? groupName;
  final String? groupAvatar;
  final String? initialMessageId;

  const GroupChatScreen({
    Key? key,
    required this.chatId,
    this.groupName,
    this.groupAvatar,
    this.initialMessageId,
  }) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Message> _messages = [];
  final MarkdownTextEditingController _messageController = MarkdownTextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isMuted = false;
  bool _isSending = false;
  String? _currentUserId;
  String _groupName = '';
  String? _groupAvatar;
  List<ChatParticipant> _participants = [];
  bool _showScrollDownFab = false;
  double _lastScrollOffset = 0;
  double _accumulatedScrollDown = 0;
  double _accumulatedScrollUp = 0;
  String? _highlightMessageId;
  final Map<String, GlobalKey> _messageKeys = {};
  final GlobalKey _inputKey = GlobalKey();
  double _inputHeight = 90.0;
  Timer? _highlightTimer;
  final List<String> _jumpHistory = [];
  final Map<String, Map<String, int>> _messageReactions = {}; // msgId → {emoji → count}
  final Map<String, Set<String>> _myReactions = {}; // msgId → Set<emoji>

  // WebSocket
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  bool _isTyping = false;
  Timer? _typingTimer;
  String? _typingUserName;
  String? _typingUserId;

  // Reply / Quote state
  Message? _replyToMessage;
  bool _isQuote = false;
  String? _quoteText;
  int _quoteOffset = 0;
  int _quoteLength = 0;

  // Edit message state
  bool _isEditing = false;
  String? _editingMessageId;

  void _cancelEditing() {
    _stopMyTyping();
    setState(() {
      _isEditing = false;
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _initWebSocket();

    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      final delta = offset - _lastScrollOffset;
      _lastScrollOffset = offset;

      if (delta < 0) {
        _accumulatedScrollDown -= delta;
        _accumulatedScrollUp = 0;
      } else if (delta > 0) {
        _accumulatedScrollUp += delta;
        _accumulatedScrollDown = 0;
      }

      final isScrollingDown = _scrollController.position.userScrollDirection == ScrollDirection.forward;
      
      // Clear jump history when near bottom
      if (offset < 100 && _jumpHistory.isNotEmpty) {
        _jumpHistory.clear();
      }

      // Dynamic threshold: height of the newest message
      double threshold = 150.0;
      if (_messages.isNotEmpty) {
        final firstMsgId = _messages.first.id;
        final key = _messageKeys[firstMsgId];
        final renderBox = key?.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          threshold = renderBox.size.height;
        }
      }
      
      bool shouldShow = _showScrollDownFab;
      if (offset <= threshold) {
        shouldShow = false;
      } else if (_jumpHistory.isNotEmpty) {
        shouldShow = true;
      } else if (delta < 0 && _accumulatedScrollDown >= 80.0 && isScrollingDown) {
        shouldShow = true;
      } else if (delta > 0 && _accumulatedScrollUp >= 120.0) {
        shouldShow = false;
      }
      
      if (shouldShow != _showScrollDownFab) {
        setState(() {
          _showScrollDownFab = shouldShow;
          if (shouldShow) {
            _accumulatedScrollDown = 0;
          } else {
            _accumulatedScrollUp = 0;
          }
        });
      }
    });

    // Notify provider that this chat is open (so unread count is not incremented)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<UnreadCountProvider>().setOpenChat(widget.chatId);
      } catch (_) {}
    });
  }

  void _initWebSocket() {
    // Subscribe to WebSocket events for this chat
    // Note: We only use eventStream.listen, not subscribe() to avoid duplicate handling
    _wsSubscription = _wsService.eventStream.listen(_handleWebSocketEvent);
  }

  void _handleWebSocketEvent(WebSocketEvent event) {
    // Handle events specific to this chat
    if (event.type == WebSocketEventType.newMessage) {
      final chatId = event.data['chat_id']?.toString();
      if (chatId == widget.chatId) {
        _onNewMessage(event);
      }
    } else if (event.type == WebSocketEventType.messageRead) {
      final chatId = event.data['chat_id']?.toString();
      if (chatId == widget.chatId) {
        _onMessageRead(event);
      }
    } else if (event.type == WebSocketEventType.typing) {
      final chatId = event.data['chat_id']?.toString();
      if (chatId == widget.chatId) {
        _onTypingIndicator(event);
      }
    } else if (event.type == WebSocketEventType.messageEdited) {
      final chatId = event.data['chat_id']?.toString();
      if (chatId == widget.chatId) {
        _onMessageEdited(event);
      }
    } else if (event.type == WebSocketEventType.messageDeleted) {
      final chatId = event.data['chat_id']?.toString();
      if (chatId == widget.chatId) {
        _onMessageDeleted(event);
      }
    } else if (event.type == WebSocketEventType.userStatus) {
      _onUserStatusUpdate(event);
    } else if (event.type == WebSocketEventType.messageReactionUpdated) {
      final chatId = event.data['chat_id']?.toString();
      if (chatId == widget.chatId) {
        _onMessageReactionUpdated(event);
      }
    }
  }

  void _onMessageReactionUpdated(WebSocketEvent event) {
    final messageId = event.data['message_id']?.toString();
    if (messageId == null) return;

    final userId = event.data['user_id']?.toString();
    final emoji = event.data['emoji']?.toString();
    final action = event.data['action']?.toString(); // "added" or "removed"

    final Map<String, int> reactionsMap = {};
    if (event.data['reactions'] is List) {
      for (final r in event.data['reactions']) {
        if (r is Map && r['emoji'] != null && r['count'] != null) {
          final cnt = (r['count'] as num).toInt();
          if (cnt > 0) {
            reactionsMap[r['emoji'].toString()] = cnt;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _messageReactions[messageId] = reactionsMap;

        if (userId != null && userId == _currentUserId && emoji != null) {
          final mySet = _myReactions.putIfAbsent(messageId, () => <String>{});
          if (action == 'added') {
            mySet.add(emoji);
          } else if (action == 'removed') {
            mySet.remove(emoji);
          }
          if (mySet.isEmpty) {
            _myReactions.remove(messageId);
          }
        }

        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            reactions: reactionsMap,
            myReactions: _myReactions[messageId] ?? _messages[idx].myReactions,
          );
        }
      });

      try {
        AppDatabase().updateMessageReactions(
          messageId,
          reactionsMap,
          _myReactions[messageId] ?? {},
        );
      } catch (e) {
        debugPrint('GroupChatScreen: error updating reactions in DB: $e');
      }
    }
  }

  void _onMessageDeleted(WebSocketEvent event) {
    final messageId = event.data['message_id']?.toString();
    if (messageId == null) return;

    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.id == messageId);
      });
    }

    try {
      AppDatabase().deleteMessage(messageId);
    } catch (e) {
      debugPrint('GroupChatScreen: error deleting message from DB: $e');
    }
  }

  void _onUserStatusUpdate(WebSocketEvent event) {
    final userId = event.data['user_id']?.toString();
    final isOnline = event.data['is_online'] == true;
    if (userId == null) return;

    if (mounted) {
      setState(() {
        final idx = _participants.indexWhere((p) => p.id == userId);
        if (idx != -1) {
          _participants[idx] = _participants[idx].copyWith(isOnline: isOnline);
        }
      });
    }
  }

  void _onMessageEdited(WebSocketEvent event) {
    final messageId = event.data['message_id']?.toString();
    final newContent = event.data['content']?.toString();
    if (messageId == null || newContent == null) return;

    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            content: newContent,
            isEdited: true,
          );
        }
      });
    }

    try {
      AppDatabase().updateMessageContent(messageId, newContent);
    } catch (_) {}
  }

  void _onNewMessage(WebSocketEvent event) {
    final messageData = event.data['message'] as Map<String, dynamic>?;
    if (messageData == null) return;

    // Don't add if message is from current user (already added when sending)
    final senderId = messageData['sender_id']?.toString();
    if (senderId == _currentUserId) return;

    final message = Message.fromJson(messageData);

    // Дедупликация: не добавлять если сообщение уже есть в списке
    if (_messages.any((m) => m.id == message.id)) return;

    // Сохранить в Drift для оффлайн-доступа
    final db = AppDatabase();
    try {
      db.saveMessage(_messageToCompanion(message));
    } catch (_) {}

    if (mounted) {
      setState(() {
        if (_typingUserId == message.senderId || _isTyping) {
          _typingTimer?.cancel();
          _isTyping = false;
          _typingUserId = null;
          _typingUserName = null;
        }
        _messages.insert(0, message);
      });
      // Don't auto-scroll to bottom on new message - user should stay at current position
      // _scrollToBottom(); // Removed: user should control scroll position
    }
  }

  void _onTypingIndicator(WebSocketEvent event) {
    // Show/hide scroll-down FAB logic
    final showFab = _scrollController.hasClients && _scrollController.offset > 200;
    if (showFab != _showScrollDownFab) {
      setState(() => _showScrollDownFab = showFab);
    }

    final chatId = event.data['chat_id']?.toString();
    if (chatId != widget.chatId) return;

    final typingUserId = event.data['user_id']?.toString();
    if (typingUserId == _currentUserId) return;

    final bool isTyping = event.data['is_typing'] != false;
    if (!isTyping) {
      if (mounted && _typingUserId == typingUserId) {
        _typingTimer?.cancel();
        setState(() {
          _isTyping = false;
          _typingUserId = null;
          _typingUserName = null;
        });
      }
      return;
    }

    // Get typing user name from event or participants
    final eventUserName = event.data['user_name']?.toString();
    String name = eventUserName ?? '';
    if (name.isEmpty) {
      final typingUser = _participants.firstWhere(
        (p) => p.id == typingUserId,
        orElse: () => ChatParticipant(
            id: '', username: '', displayName: 'Someone', role: 'member'),
      );
      name = typingUser.displayName.isNotEmpty
          ? typingUser.displayName
          : typingUser.username;
    }

    if (mounted) {
      setState(() {
        _typingUserId = typingUserId;
        _typingUserName = name;
        _isTyping = true;
      });

      // Clear typing indicator after 4 seconds (Telegram-like smooth window)
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _typingUserId = null;
            _typingUserName = null;
          });
        }
      });
    }
  }

  Timer? _typingKeepAliveTimer;
  bool _amITyping = false;

  void _onInputTextChanged(String text) {
    final bool hasText = text.trim().isNotEmpty;
    if (hasText) {
      if (!_amITyping) {
        _amITyping = true;
        _wsService.sendTypingIndicator(widget.chatId, isTyping: true);
      }
      _typingKeepAliveTimer ??= Timer.periodic(const Duration(milliseconds: 2000), (_) {
        if (_messageController.text.trim().isNotEmpty) {
          _wsService.sendTypingIndicator(widget.chatId, isTyping: true);
        } else {
          _stopMyTyping();
        }
      });
    } else {
      _stopMyTyping();
    }
  }

  void _stopMyTyping() {
    _typingKeepAliveTimer?.cancel();
    _typingKeepAliveTimer = null;
    if (_amITyping) {
      _amITyping = false;
      _wsService.sendTypingIndicator(widget.chatId, isTyping: false);
    }
  }

  void _onMessageRead(WebSocketEvent event) {
    // Handle read status update
    final readerId = event.data['reader_id']?.toString();
    if (readerId == _currentUserId) return;

    if (mounted) {
      setState(() {
        // Mark all messages sent by current user as read
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].senderId == _currentUserId) {
            _messages[i] = _messages[i].copyWith(isRead: true);
          }
        }
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    await ChatService.markMessagesAsRead(chatId: widget.chatId);
    // Notify via WebSocket that messages were read
    _wsService.sendMessageRead(widget.chatId);
  }

  Future<void> _loadData() async {
    // Get current user ID
    final userId = await AuthService.getUserId();
    setState(() {
      _currentUserId = userId;
    });

    // Load chat details
    final chatResult = await ChatService.getChat(widget.chatId);
    if (chatResult['success'] == true && mounted) {
      final chat = chatResult['chat'] as ChatDetails;
      setState(() {
        _groupName = chat.name;
        _groupAvatar = chat.avatarUrl;
        _participants = chat.participants;
      });
    }

    // Load messages
    await _loadMessages();

    // Scroll to initial message if specified
    if (widget.initialMessageId != null) {
      _scrollToMessage(widget.initialMessageId!);
    }

    // Mark messages as read when opening chat
    await _markMessagesAsRead();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    // 1. Сначала загрузить из Drift (мгновенно, offline-first)
    final db = AppDatabase();
    List<DbMessage> localMessages = [];
    try {
      localMessages = await db.getMessages(widget.chatId, limit: 50);
    } catch (e) {
      debugPrint('GroupChat: Drift getMessages error: $e');
    }

    if (localMessages.isNotEmpty && mounted) {
      final fixedMessages = localMessages.map((m) {
        if (m.sendStatus == MessageSendStatus.sending.index) {
          if (m.serverId != null) {
            db.updateMessageSendStatus(
                m.localId, m.serverId!, MessageSendStatus.sent.index);
            return m.copyWith(sendStatus: MessageSendStatus.sent.index);
          } else {
            db.updateMessageStatus(m.localId, MessageSendStatus.failed.index);
            return m.copyWith(sendStatus: MessageSendStatus.failed.index);
          }
        }
        return m;
      }).toList();

      setState(() {
        _isLoading = false;
        _messages.clear();
        _messages.addAll(
            fixedMessages.map((m) => Message.fromDbMessage(m)).toList());
        for (final m in _messages) {
          if (m.reactions.isNotEmpty) {
            _messageReactions[m.id] = Map.from(m.reactions);
          }
          if (m.myReactions.isNotEmpty) {
            _myReactions[m.id] = Set.from(m.myReactions);
          }
        }
      });
      _scrollToBottom();
    }

    // 2. Затем загрузить с сервера (обновление)
    try {
      final result = await ChatService.getMessages(chatId: widget.chatId);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            final serverMessages = result['messages'] as List<Message>;
            // Сохранить pending/failed сообщения из текущего списка (их нет на сервере)
            final pendingMessages = _messages
                .where(
                  (m) => m.sendStatus != 1 && m.localId != null,
                )
                .toList();

            _messages.clear();
            _messages.addAll(serverMessages);

            // Добавить pending/failed сообщения обратно (их нет на сервере)
            for (final pending in pendingMessages) {
              if (!_messages.any((m) => m.localId == pending.localId)) {
                _messages.add(pending);
              }
            }

            for (final m in _messages) {
              if (m.reactions.isNotEmpty) {
                _messageReactions[m.id] = Map.from(m.reactions);
              }
              if (m.myReactions.isNotEmpty) {
                _myReactions[m.id] = Set.from(m.myReactions);
              }
            }

            // Сортировка по createdAt по убыванию
            _messages.sort((a, b) {
              try {
                final ta = DateTime.parse(a.createdAt);
                final tb = DateTime.parse(b.createdAt);
                return tb.compareTo(ta);
              } catch (_) {
                return 0;
              }
            });

            // Сохранить в Drift для оффлайн-доступа
            try {
              db.saveMessages(
                  _messages.map((m) => _messageToCompanion(m)).toList());
            } catch (e) {
              debugPrint('GroupChat: Drift saveMessages error: $e');
            }
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('GroupChat: Error loading from server: $e');
      if (mounted && localMessages.isEmpty) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Конвертация Message → MessagesCompanion для Drift
  MessagesCompanion _messageToCompanion(Message msg) {
    final isSent = msg.sendStatus == 1 && msg.id != msg.localId;
    return MessagesCompanion(
      serverId: isSent ? Value(msg.id) : const Value.absent(),
      localId: Value(msg.localId ?? msg.id),
      chatId: Value(msg.chatId),
      senderId: Value(msg.senderId),
      content: Value(msg.content),
      messageType: Value(msg.messageType),
      fileUrl: Value(msg.fileUrl),
      fileName: Value(msg.fileName),
      replyToMessageId: Value(msg.replyToMessageId),
      isQuote: Value(msg.isQuote),
      quoteText: Value(msg.quoteText),
      quoteOffset: Value(msg.quoteOffset),
      quoteLength: Value(msg.quoteLength),
      replyToSenderId: Value(msg.replyInfo?.senderId),
      replyToSenderName: Value(msg.replyInfo?.senderName),
      replyToContent: Value(msg.replyInfo?.content),
      replyToMessageType: Value(msg.replyInfo?.messageType ?? 'text'),
      isRead: Value(msg.isRead),
      isEdited: Value(msg.isEdited),
      sendStatus: Value(msg.sendStatus),
      senderName: Value(msg.senderName),
      senderAvatarUrl: Value(msg.senderAvatarUrl),
      createdAt: Value(msg.createdAt),
      reactions: msg.reactions.isNotEmpty || msg.myReactions.isNotEmpty
          ? Value(jsonEncode({
              'reactions': msg.reactions,
              'my_reactions': msg.myReactions.toList(),
            }))
          : const Value.absent(),
    );
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_isEditing && _editingMessageId != null) {
      final messageId = _editingMessageId!;
      _cancelEditing();
      try {
        final res = await ChatService.editMessage(
          chatId: widget.chatId,
          messageId: messageId,
          content: text,
        );
        if (res['success'] == true) {
          if (mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == messageId);
              if (idx != -1) {
                _messages[idx] = _messages[idx].copyWith(
                  content: text,
                  isEdited: true,
                );
              }
            });
          }
          await AppDatabase().updateMessageContent(messageId, text);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  res['message'] ?? context.l10n.translate('chat_edit_error'),
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error editing group message: $e');
      }
      return;
    }

    final replyTo = _replyToMessage;
    final replyIsQuote = _isQuote;
    final replyQuoteText = _quoteText;
    final replyQuoteOffset = _quoteOffset;
    final replyQuoteLength = _quoteLength;

    _stopMyTyping();
    _messageController.clear();
    setState(() {
      _isSending = true;
      _replyToMessage = null;
      _isQuote = false;
      _quoteText = null;
      _quoteOffset = 0;
      _quoteLength = 0;
    });

    final syncService = SyncService();
    String? pendingLocalId;
    DbMessage? pendingMsg;
    try {
      pendingMsg = await syncService.createPendingMessage(
        chatId: widget.chatId,
        senderId: _currentUserId ?? '',
        content: text,
        messageType: 'text',
        replyToMessageId: replyTo?.id,
        isQuote: replyIsQuote,
        quoteText: replyQuoteText,
        quoteOffset: replyQuoteOffset,
        quoteLength: replyQuoteLength,
        replyToSenderId: replyTo?.senderId,
        replyToSenderName: replyTo?.senderName,
        replyToContent: replyTo?.content,
        replyToMessageType: replyTo?.messageType ?? 'text',
      );
    } catch (e) {
      debugPrint('SyncService createPendingMessage error: $e');
    }

    if (pendingMsg != null) {
      pendingLocalId = pendingMsg.localId;
      final message = Message.fromDbMessage(pendingMsg);
      if (mounted) {
        setState(() {
          _messages.insert(0, message);
          _isSending = false;
        });
        _scrollToBottom();
      }

      try {
        final result = await ChatService.sendMessage(
          chatId: widget.chatId,
          content: text,
          messageType: 'text',
          localId: pendingLocalId,
          replyToMessageId: replyTo?.id,
          isQuote: replyIsQuote,
          quoteText: replyQuoteText,
          quoteOffset: replyQuoteOffset,
          quoteLength: replyQuoteLength,
        );

        if (result['success'] == true) {
          final sentMessage = result['message'];
          final serverId = sentMessage is Message ? sentMessage.id : null;
          if (serverId != null && serverId.isNotEmpty) {
            await syncService.confirmMessageSent(pendingLocalId, serverId);
            if (mounted) {
              setState(() {
                final idx =
                    _messages.indexWhere((m) => m.localId == pendingLocalId);
                if (idx != -1) {
                  _messages[idx] = _messages[idx].copyWith(
                    id: serverId,
                    sendStatus: 1, // sent
                  );
                }
              });
            }
          }
        } else {
          await syncService.markMessageFailed(pendingLocalId);
          if (mounted) {
            setState(() {
              final idx =
                  _messages.indexWhere((m) => m.localId == pendingLocalId);
              if (idx != -1) {
                _messages[idx] =
                    _messages[idx].copyWith(sendStatus: 2); // failed
              }
            });
          }
        }
      } catch (e) {
        debugPrint('ChatService.sendMessage exception: $e');
        await syncService.markMessageFailed(pendingLocalId);
        if (mounted) {
          setState(() {
            final idx =
                _messages.indexWhere((m) => m.localId == pendingLocalId);
            if (idx != -1) {
              _messages[idx] =
                  _messages[idx].copyWith(sendStatus: 2); // failed
            }
          });
        }
      }
    } else {
      final result = await ChatService.sendMessage(
        chatId: widget.chatId,
        content: text,
      );

      if (mounted) {
        if (result['success'] == true) {
          final sentMsg = result['message'] as Message;
          setState(() {
            if (!_messages.any((m) => m.id == sentMsg.id)) {
              _messages.insert(0, sentMsg);
            }
            _isSending = false;
          });
          _scrollToBottom();
        } else {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['message'] ?? 'Failed to send message')),
          );
        }
      }
    }
  }

  /// Повторить отправку failed-сообщения
  Future<void> _retryMessage(Message message) async {
    if (message.localId == null) return;
    final syncService = SyncService();

    setState(() {
      final idx = _messages.indexWhere((m) => m.localId == message.localId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(sendStatus: 0);
      }
    });

    await syncService.retryFailedMessage(message.localId!);

    final db = AppDatabase();
    try {
      final updated = await db.getMessageByLocalId(message.localId!);
      if (updated != null && mounted) {
        setState(() {
          final idx =
              _messages.indexWhere((m) => m.localId == message.localId);
          if (idx != -1) {
            _messages[idx] = Message.fromDbMessage(updated);
          }
        });
      }
    } catch (e) {
      debugPrint('Retry getMessageByLocalId error: $e');
    }
  }

  /// Scroll to a specific message and highlight it
  Future<void> _scrollToMessage(String messageId, {int retryCount = 0}) async {
    if (!mounted) return;

    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
      _setHighlight(messageId);
      return;
    }

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      // In group chats we don't have _hasMoreMessages in the current code, but we should load more
      // For now, let's stick to what's available or add _hasMoreMessages if it exists in API
      // Looking at _loadMessages, it doesn't set _hasMoreMessages yet.
      // But we can call ChatService.getMessages with beforeMessageId.
      
      // Let's assume for now we only scroll to what's loaded, or implement simple load more.
      // Since ChatService.getMessages returns has_more, we should probably track it.
      return;
    }

    const estimatedItemHeight = 110.0;
    final targetOffset = index * estimatedItemHeight;

    if ((_scrollController.offset - targetOffset).abs() > 2000) {
      _scrollController.jumpTo(targetOffset);
    } else {
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    await Future.delayed(const Duration(milliseconds: 100));
    
    if (retryCount < 10) {
      return _scrollToMessage(messageId, retryCount: retryCount + 1);
    }
  }

  void _setHighlight(String messageId) {
    if (!mounted) return;
    setState(() {
      _highlightMessageId = messageId;
    });

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightMessageId = null;
        });
      }
    });
  }

  /// Handles tapping on a reply/forward header: scrolls locally or navigates to another chat
  Future<void> _handleReplyTap(String messageId, String? originalChatId, {String? fromMessageId}) async {
    if (originalChatId == null || originalChatId == widget.chatId) {
      if (fromMessageId != null && (_jumpHistory.isEmpty || _jumpHistory.last != fromMessageId)) {
        _jumpHistory.add(fromMessageId);
        setState(() {
          _showScrollDownFab = true;
        });
      }
      await _scrollToMessage(messageId);
      return;
    }

    final result = await ChatService.getChat(originalChatId);
    if (result['success'] == true) {
      final chat = result['chat'] as ChatDetails;
      Widget targetScreen;
      if (chat.chatType == 'group') {
        targetScreen = GroupChatScreen(chatId: chat.id, initialMessageId: messageId);
      } else if (chat.chatType == 'channel') {
        targetScreen = ChannelScreen(channelId: chat.id, highlightMessageId: messageId);
      } else {
        targetScreen = PrivateChatScreen(
          chatId: chat.id,
          otherUserName: chat.name,
          otherUserAvatar: chat.avatarUrl,
          initialMessageId: messageId,
        );
      }

      if (mounted) {
        Navigator.push(
          context,
          SwipeBackPageRoute(builder: (_) => targetScreen),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'У вас нет доступа к этому сообщению'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startReply(Message message) {
    setState(() {
      _replyToMessage = message;
      _isQuote = false;
      _quoteText = null;
      _quoteOffset = 0;
      _quoteLength = 0;
    });
    // Optional: focus field
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
      _isQuote = false;
      _quoteText = null;
      _quoteOffset = 0;
      _quoteLength = 0;
    });
  }

  String _formatTime(String timestamp) {
    return DateTimeUtils.formatTimeHHmm(timestamp);
  }

  @override
  void dispose() {
    _stopMyTyping();
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _wsSubscription?.cancel();
    _typingTimer?.cancel();

    // Clear the open chat indicator in the provider
    try {
      context.read<UnreadCountProvider>().setOpenChat(null);
    } catch (_) {}

    super.dispose();
  }

  void _updateInputHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? renderBox =
          _inputKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final newHeight = renderBox.size.height;
        if (newHeight != _inputHeight && newHeight > 0) {
          setState(() {
            _inputHeight = newHeight;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _updateInputHeight();
    final displayName = widget.groupName ?? (_groupName.isNotEmpty ? _groupName : 'Group');

    final tabBar = TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Chat'),
        Tab(text: 'Members'),
      ],
    );

    final tabBarView = TabBarView(
      controller: _tabController,
      children: [
        _buildChatTab(),
        _buildMembersTab(),
      ],
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardVisible = bottomInset > 0;

    final int onlineCount = _participants.where((p) => p.isOnline).length;
    final String statusSubtitle;
    if (_isTyping && _typingUserName != null && _typingUserName!.isNotEmpty) {
      statusSubtitle = context.l10n
          .translate('chat_user_typing')
          .replaceAll('{name}', _typingUserName!);
    } else if (onlineCount >= 1) {
      statusSubtitle = context.l10n
          .translate('chat_status_members_and_online')
          .replaceAll('{count}', _participants.length.toString())
          .replaceAll('{online}', onlineCount.toString());
    } else {
      statusSubtitle = context.l10n
          .translate('chat_status_members_count')
          .replaceAll('{count}', _participants.length.toString());
    }

    return ChatScaffold(
      canPop: !isKeyboardVisible,
      onPopInvoked: (didPop, _) {
        if (!didPop && isKeyboardVisible) {
          FocusScope.of(context).unfocus();
        }
      },
      appBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingGlassAppBar(
            name: displayName,
            avatarUrl: widget.groupAvatar ?? _groupAvatar,
            isOnline: false, // Group itself doesn't have online status
            statusText: statusSubtitle,
            statusColor: _isTyping
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[600],
            onBack: () => Navigator.pop(context),
            onTitleTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(
                    chatId: widget.chatId,
                    groupName: displayName,
                    groupAvatar: widget.groupAvatar ?? _groupAvatar,
                  ),
                )),
            onAvatarTap: () {
              GlassChatMenu.show(
                context,
                isMuted: _isMuted,
                onVoiceCall: () {
                  /* TODO: Voice call */
                },
                onVideoCall: () {
                  /* TODO: Video call */
                },
                onSearch: () {
                  /* TODO: Search */
                },
                onToggleMute: () {
                  setState(() => _isMuted = !_isMuted);
                  ChatService.setMuteNotifications(
                      chatId: widget.chatId, muted: _isMuted);
                },
                onClearHistory: () {
                  // TODO: Clear history dialog
                },
                onReport: () {
                  // TODO: Report dialog
                },
                onViewProfile: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupInfoScreen(
                        chatId: widget.chatId,
                        groupName: displayName,
                        groupAvatar: widget.groupAvatar ?? _groupAvatar,
                      ),
                    )),
              );
            },
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: tabBar,
            ),
          ),
        ],
      ),
      body: tabBarView,
    );
  }

  Widget _buildChatTab() {
    final topPadding = MediaQuery.of(context).padding.top +
        kToolbarHeight +
        kTextTabBarHeight +
        24.0;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final typingWidget = _isTyping
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_typingUserName is typing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          )
        : null;

    final messageList = ChatMessagesListView(
      isLoading: _isLoading,
      itemCount: _messages.length,
      scrollController: _scrollController,
      topPadding: topPadding,
      bottomPadding: _inputHeight + bottomInset + 8,
      typingIndicator: typingWidget,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final bool isMe = message.senderId == _currentUserId;
        final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());
        final isHighlighted = _highlightMessageId == message.id;

        Widget messageWidget = MessageBubble(
          key: key,
          message: message,
          isMe: isMe,
          currentUserId: _currentUserId ?? '',
          senderName: isMe ? null : message.senderName,
          isHighlighted: isHighlighted,
          reactions: _messageReactions[message.id] ?? (message.reactions.isNotEmpty ? message.reactions : null),
          myReactions: _myReactions[message.id] ?? (message.myReactions.isNotEmpty ? message.myReactions : null),
          onReactionTap: (emoji) => _toggleReaction(message.id, emoji),
          onRetry: (msg) => _retryMessage(msg),
          onReplyTap: (replyToId, chatId) => _handleReplyTap(
            replyToId,
            chatId,
            fromMessageId: message.id,
          ),
          formatTime: _formatTime,
        );

        if (!isMe) {
          messageWidget = VisibleMessageDetector(
            messageId: message.id,
            onMessageSeen: () => _onMessageVisible(message.id),
            visibilityThreshold: 0.3,
            visibleDuration: const Duration(milliseconds: 300),
            child: messageWidget,
          );
        }

        messageWidget = SwipeToReplyWrapper(
          onReply: () => _startReply(message),
          enabled: true,
          child: messageWidget,
        );

        messageWidget = GestureDetector(
          onTap: () {
            _showContextMenu(message, isMe, key);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: messageWidget,
          ),
        );

        final prevMessage =
            index < _messages.length - 1 ? _messages[index + 1] : null;
        final currentDt =
            DateTimeUtils.parseUtcDateTime(message.createdAt) ?? DateTime.now();
        final prevDt = prevMessage != null
            ? (DateTimeUtils.parseUtcDateTime(prevMessage.createdAt) ?? DateTime.now())
            : null;
        final currentDate = DateTimeUtils.startOfDay(currentDt);
        final prevDate = prevDt != null ? DateTimeUtils.startOfDay(prevDt) : null;

        final items = <Widget>[];
        if (currentDate != prevDate) {
          items.add(DateSeparator(
              dateLabel: DateTimeUtils.formatDateSeparator(currentDt,
                  context: context)));
        }
        items.add(messageWidget);

        return Column(children: items);
      },
    );

    return Stack(
      children: [
        Positioned.fill(child: messageList),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset,
          child: Container(
            key: _inputKey,
            child: _buildMessageInput(),
          ),
        ),
        Positioned(
          right: 14,
          bottom: _inputHeight + 10 + bottomInset,
          child: ScrollDownFab(
            visible: _showScrollDownFab,
            unreadCount: 0,
            onPressed: () {
              if (_jumpHistory.isNotEmpty) {
                final lastId = _jumpHistory.removeLast();
                _scrollToMessage(lastId);
              } else {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    if (_participants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final glassEnabled = context.watch<LiquidGlassProvider>().enabled;
    final topPadding = glassEnabled
        ? MediaQuery.of(context).padding.top +
            kToolbarHeight +
            kTextTabBarHeight
        : 0.0;

    return ListView.builder(
      padding: EdgeInsets.only(
        top: topPadding,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        final roleIcon = participant.role == 'owner'
            ? Icons.star
            : participant.role == 'admin'
                ? Icons.shield
                : null;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF0088CC),
            backgroundImage: getValidAvatarUrl(participant.avatarUrl) != null
                ? avatarImageProvider(participant.avatarUrl)
                : null,
            child: getValidAvatarUrl(participant.avatarUrl) == null
                ? Text(
                    participant.displayName.isNotEmpty
                        ? participant.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          title: Text(participant.displayName),
          subtitle: Text('@${participant.username}'),
          trailing: roleIcon != null
              ? Icon(
                  roleIcon,
                  size: 18,
                  color:
                      participant.role == 'owner' ? Colors.amber : Colors.blue,
                )
              : null,
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return ChatInputBar(
      controller: _messageController,
      hintText: 'Type a message...',
      isEditing: _isEditing,
      onCancelEditing: _cancelEditing,
      replyToMessage: _replyToMessage,
      isQuote: _isQuote,
      quoteText: _quoteText,
      onCancelReply: _cancelReply,
      onTapReply: _replyToMessage != null
          ? () => _scrollToMessage(_replyToMessage!.id)
          : null,
      onChanged: _onInputTextChanged,
      onSend: _sendMessage,
      isSending: _isSending,
    );
  }

  /// Toggle reaction on a message — optimistic update + API call
  void _toggleReaction(String messageId, String emoji) {
    setState(() {
      final mySet = _myReactions.putIfAbsent(messageId, () => <String>{});
      final reactions = _messageReactions.putIfAbsent(messageId, () => <String, int>{});

      final isCurrentlySelected = mySet.contains(emoji);
      if (isCurrentlySelected) {
        mySet.remove(emoji);
        if (mySet.isEmpty) {
          _myReactions.remove(messageId);
        }
        reactions[emoji] = (reactions[emoji] ?? 1) - 1;
        if (reactions[emoji]! <= 0) {
          reactions.remove(emoji);
        }
      } else {
        mySet.add(emoji);
        reactions[emoji] = (reactions[emoji] ?? 0) + 1;
      }

      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(
          reactions: Map.from(reactions),
          myReactions: Set.from(mySet),
        );
      }
    });

    try {
      AppDatabase().updateMessageReactions(
        messageId,
        _messageReactions[messageId] ?? {},
        _myReactions[messageId] ?? {},
      );
    } catch (e) {
      debugPrint('GroupChatScreen: error saving reactions to DB: $e');
    }

    _sendReactionToggle(messageId, emoji);
  }

  Future<void> _sendReactionToggle(String messageId, String emoji) async {
    try {
      await ChatService.toggleReaction(
        chatId: widget.chatId,
        messageId: messageId,
        emoji: emoji,
      );
    } catch (_) {
      // Silently fail — optimistic update already applied
    }
  }

  void _showContextMenu(Message message, bool isMe, GlobalKey key) {
    if (message.messageType == 'text' && _isSingleEmoji(message.content)) {
      if (EmojiUtils.getAnimatedEmojiPath(message.content) != null) {
        return;
      }
    }

    MessageContextMenuService().show(
      context: context,
      message: message,
      messageKey: key,
      isMe: isMe,
      onReply: () => _startReply(message),
      onPin: () {},
      onEdit: () {
        setState(() {
          _cancelReply();
          _messageController.text = message.content;
          _isEditing = true;
          _editingMessageId = message.id;
        });
      },
      onDelete: (msg) => _confirmDeleteMessage(msg),
      onReaction: (msgId, emoji) => _toggleReaction(msgId, emoji),
      selectedEmojis: _myReactions[message.id] ?? message.myReactions,
    );
  }

  void _confirmDeleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.translate('chat_delete_message_title')),
        content: Text(ctx.l10n.translate('chat_delete_message_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage(message);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(ctx.l10n.translate('chat_action_delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(Message message) async {
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });

    try {
      await AppDatabase().deleteMessage(message.id);
    } catch (e) {
      debugPrint('GroupChatScreen: error deleting from DB: $e');
    }

    final result = await ChatService.deleteMessage(
      chatId: widget.chatId,
      messageId: message.id,
    );

    if (result['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to delete message')),
      );
    }
  }

  /// Called when a message becomes visible — marks as read via API
  void _onMessageVisible(String messageId) {
    // Use the same read-up-to API as private chat
    _markMessagesReadUpTo(messageId);
  }

  Future<void> _markMessagesReadUpTo(String messageId) async {
    try {
      final token = await AuthService.getToken();
      final dio = Dio();
      await dio.post(
        '${AppConfig.baseUrl}/api/chats/${widget.chatId}/messages/read-up-to',
        data: {'message_id': messageId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  /// Helper to check if string is exactly one emoji
  bool _isSingleEmoji(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trim();
    final chars = trimmed.characters;
    if (chars.length != 1) return false;

    final rune = chars.first.runes.first;
    // Common emoji ranges
    return (rune >= 0x1F300 && rune <= 0x1FAFF) ||
        (rune >= 0x1F600 && rune <= 0x1F64F) ||
        (rune >= 0x1F680 && rune <= 0x1F6FF) ||
        (rune >= 0x2600 && rune <= 0x26FF) ||
        (rune >= 0x2700 && rune <= 0x27BF) ||
        (rune >= 0xFE00 && rune <= 0xFE0F) ||
        (rune >= 0x1F900 && rune <= 0x1F9FF);
  }
}
