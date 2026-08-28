import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/websocket_service.dart';
import '../../services/liquid_glass_provider.dart';
import '../../services/unread_count_provider.dart';
import '../../services/wallpaper_provider.dart';
import '../../services/database/app_database.dart';
import '../../services/sync_service.dart';
import '../../config/app_config.dart';
import 'package:drift/drift.dart' show Value;
import '../../utils/image_utils.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/haptic_utils.dart';
import '../../widgets/chat/liquid_glass_input_field.dart';
import '../../widgets/chat/floating_glass_app_bar.dart';
import '../../widgets/chat/matte_app_bar.dart';
import '../../widgets/chat/visible_message_detector.dart';
import '../../widgets/chat/swipe_to_reply_wrapper.dart';
import '../../widgets/chat/reply_preview_bar.dart';
import '../../widgets/chat/message_reply_info.dart';
import '../../widgets/chat/unread_separator.dart';
import '../../widgets/chat/reactions_panel.dart';
import '../../widgets/message/message_status_widget.dart';
import '../../widgets/message/text_message_widget.dart';
import '../../widgets/message/message_bubble.dart';
import '../../utils/swipe_back_route.dart';
import 'private_chat_screen.dart';
import 'channel_screen.dart';
import 'group_info_screen.dart';
import 'poll_create_screen.dart';

// --- НАСТРОЙКИ СТИЛЯ СООБЩЕНИЙ ---
/// Радиус скругления «облачка» сообщения.
const double _kMessageBorderRadius = 18.0;
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

  // WebSocket
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  bool _isTyping = false;
  Timer? _typingTimer;
  String? _typingUserName;

  // Reply / Quote state
  Message? _replyToMessage;
  bool _isQuote = false;
  String? _quoteText;
  int _quoteOffset = 0;
  int _quoteLength = 0;

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
    }
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

    final typingUserId = event.data['user_id']?.toString();
    if (typingUserId == _currentUserId) return;

    // Get typing user name from participants
    final typingUser = _participants.firstWhere(
      (p) => p.id == typingUserId,
      orElse: () => ChatParticipant(
          id: '', username: '', displayName: 'Someone', role: 'member'),
    );

    if (mounted) {
      setState(() {
        _typingUserName = typingUser.displayName.isNotEmpty
            ? typingUser.displayName
            : typingUser.username;
        _isTyping = true;
      });

      // Clear typing indicator after 3 seconds
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _typingUserName = null;
          });
        }
      });
    }
  }

  void _sendTypingIndicator() {
    _wsService.sendTypingIndicator(widget.chatId);
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
    );
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final replyTo = _replyToMessage;
    final replyIsQuote = _isQuote;
    final replyQuoteText = _quoteText;
    final replyQuoteOffset = _quoteOffset;
    final replyQuoteLength = _quoteLength;

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
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
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

    return PopScope(
      canPop: !isKeyboardVisible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isKeyboardVisible) {
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // TabBarView на весь экран
            Positioned.fill(
              child: tabBarView,
            ),
            // Floating Glass AppBar поверх контента
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FloatingGlassAppBar(
                name: displayName,
                avatarUrl: widget.groupAvatar ?? _groupAvatar,
                isOnline: false, // Group itself doesn't have online status
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
            ),
            // Positioned TabBar below the floating AppBar
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              left: 0,
              right: 0,
              child: Center(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final glassEnabled = context.watch<LiquidGlassProvider>().enabled;
    final wallpaperPath = context.watch<WallpaperProvider>().wallpaperPath;

    // В glass-режиме Scaffold без appBar, нужен отступ для glass AppBar + TabBar
    final topPadding = MediaQuery.of(context).padding.top +
            kToolbarHeight +
            kTextTabBarHeight + 24.0;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final typingIndicator = _isTyping
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
        : const SizedBox.shrink();

    final messageList = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: EdgeInsets.only(
                  top: topPadding,
                  left: 12,
                  right: 12,
                  bottom: _inputHeight + bottomInset,
                ),
                itemCount: _messages.length,
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
                    onRetry: (msg) => _retryMessage(msg),
                    onReplyTap: (replyToId, chatId) => _handleReplyTap(
                      replyToId,
                      chatId,
                      fromMessageId: message.id,
                    ),
                    formatTime: _formatTime,
                  );

                  // Wrap incoming messages with VisibleMessageDetector
                  if (!isMe) {
                    messageWidget = VisibleMessageDetector(
                      messageId: message.id,
                      onMessageSeen: () => _onMessageVisible(message.id),
                      visibilityThreshold: 0.3,
                      visibleDuration: const Duration(milliseconds: 300),
                      child: messageWidget,
                    );
                  }

                  // Wrap with SwipeToReplyWrapper for swipe-to-reply gesture
                  messageWidget = SwipeToReplyWrapper(
                    onReply: () => _startReply(message),
                    enabled: true,
                    child: messageWidget,
                  );

                  // Date separator
                  final prevMessage = index < _messages.length - 1 ? _messages[index + 1] : null;
                  final currentDt = DateTime.tryParse(message.createdAt) ?? DateTime.now();
                  final prevDt = prevMessage != null ? (DateTime.tryParse(prevMessage.createdAt) ?? DateTime.now()) : null;
                  final currentDate = DateTime(currentDt.year, currentDt.month, currentDt.day);
                  final prevDate = prevDt != null ? DateTime(prevDt.year, prevDt.month, prevDt.day) : null;

                  final items = <Widget>[];
                  if (currentDate != prevDate) {
                    String label;
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final yesterday = today.subtract(const Duration(days: 1));
                    if (currentDate == today) {
                      label = 'Сегодня';
                    } else if (currentDate == yesterday) {
                      label = 'Вчера';
                    } else {
                      label = '${currentDt.day}.${currentDt.month.toString().padLeft(2, '0')}.${currentDt.year}';
                    }
                    items.add(DateSeparator(dateLabel: label));
                  }
                  items.add(messageWidget);

                  return Column(children: items);
                },
              );

    final messageInput = _buildMessageInput();

    // Always use Stack so the input floats over messages
    return Stack(
      children: [
        // Background wallpaper
        if (wallpaperPath != null)
          Positioned.fill(
            child: Image.file(
              File(wallpaperPath),
              fit: BoxFit.cover,
            ),
          ),
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              final statusBarHeight = MediaQuery.of(context).padding.top;
              final appBarBottom = statusBarHeight + 54 + 8;
              final fadeStart = appBarBottom + 20;
              final fadeEnd = statusBarHeight + 10;

              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                ],
                stops: [
                  0.0,
                  (fadeEnd / bounds.height).clamp(0.0, 1.0),
                  (fadeStart / bounds.height).clamp(0.0, 1.0),
                  1.0,
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Column(
              children: [
                typingIndicator,
                Expanded(child: messageList),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset,
          child: Container(
            key: _inputKey,
            child: messageInput,
          ),
        ),
        Positioned(
          right: 14,
          bottom: _inputHeight + 10 + bottomInset,
          child: ScrollDownFab(
            visible: _showScrollDownFab,
            unreadCount: 0, // В группах пока без счетчика
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
    final glassEnabled = context.watch<LiquidGlassProvider>().enabled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reply/Quote preview floating bubble
        if (_replyToMessage != null)
          ReplyPreviewBar(
            replyToMessage: _replyToMessage!,
            isQuote: _isQuote,
            quoteText: _quoteText,
            onClose: _cancelReply,
            onTap: () => _scrollToMessage(_replyToMessage!.id),
            enabled: glassEnabled,
            isLite: context.watch<LiquidGlassProvider>().isLite,
          ),
        LiquidGlassInputField(
          enabled: glassEnabled,
          isLite: context.watch<LiquidGlassProvider>().isLite,
          controller: _messageController,
          hintText: 'Type a message...',
          onChanged: (_) => _sendTypingIndicator(),
          onSend: _isSending ? null : _sendMessage,
          onAttach: () {
            // TODO: Implement attachment picker
          },
          onEmoji: () {
            // TODO: Implement emoji picker
          },
          isSending: _isSending,
        ),
      ],
    );
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
