import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/websocket_service.dart';
import '../../services/file_service.dart';
import '../../services/liquid_glass_provider.dart';
import '../../services/unread_count_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/emoji_utils.dart';
import '../../services/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'package:drift/drift.dart' show Value;
import '../../widgets/chat/liquid_glass_input_field.dart';
import '../../widgets/chat/floating_glass_app_bar.dart';
import '../../widgets/chat/chat_scaffold.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/visible_message_detector.dart';
import '../../widgets/chat/swipe_to_reply_wrapper.dart';
import '../../widgets/chat/unread_separator.dart';
import '../../widgets/chat/emoji_sticker_panel.dart';
import '../../widgets/message/fullscreen_photo_viewer.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import '../../services/message_context_menu_service.dart';
import '../../services/glass_toast_service.dart';
import '../../services/wallpaper_provider.dart';
import '../../widgets/message/message_bubble.dart';
import '../../utils/swipe_back_route.dart';
import 'group_chat_screen.dart';
import 'channel_screen.dart';
import '../../utils/date_time_utils.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? initialMessageId;
  final bool? otherUserOnline;
  final DateTime? otherUserLastSeen;
  final String? otherUserId;

  const PrivateChatScreen({
    Key? key,
    required this.chatId,
    this.otherUserName,
    this.otherUserAvatar,
    this.initialMessageId,
    this.otherUserOnline,
    this.otherUserLastSeen,
    this.otherUserId,
  }) : super(key: key);

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final List<Message> _messages = [];
  final MarkdownTextEditingController _textController = MarkdownTextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  String _chatName = '';
  String? _chatAvatar;
  String? _otherUserId;
  String _chatType = 'private'; // 'private', 'saved'
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  bool _isSearchMode = false;
  bool _showEmojiPanel = false;
  bool _isKeyboardRising = false;
  bool _isKeyboardFalling = false;
  double _keyboardHeight = 280.0; // Better default height for most devices
  double _lastBottomInset = 0;
  Timer? _transitionTimer;
  int _searchCurrentIndex = 0;
  int _searchTotalCount = 0;
  String _searchQuery = '';
  final Map<String, Map<String, int>> _messageReactions = {}; // msgId → {emoji → count}
  final Map<String, Set<String>> _myReactions = {}; // msgId → Set<emoji>
  bool _showScrollDownFab = false;
  double _lastScrollOffset = 0;
  double _accumulatedScrollDown = 0;
  double _accumulatedScrollUp = 0;
  List<int> _searchResultIndices = []; // indices of messages matching search
  final List<String> _jumpHistory = [];

  // Unread messages tracking
  String?
      _firstUnreadMessageId; // ID of the oldest unread message (divider anchor)
  int _unreadCount = 0; // Number of unread messages in this chat
  bool _hasScrolledToUnread =
      false; // Whether we've scrolled to the unread area
  bool _showUnreadDivider =
      false; // Show unread divider (persists until user leaves chat)
  int _dividerUnreadCount = 0; // Count shown in divider (frozen at entry time)
  final Set<String> _pendingMarkRead =
      {}; // Messages queued to be marked as read (debounced)
  Timer? _markReadTimer; // Debounce timer for batch mark-as-read
  bool _isMarkingRead = false; // Prevent concurrent mark-as-read calls

  // WebSocket
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  bool _isTyping = false;
  Timer? _typingTimer;
  // ignore: unused_field
  String? _typingUserId;

  // File attachment
  final FileService _fileService = FileService();
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _attachedFiles = [];
  final List<String> _attachedFileNames = [];
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  // Reply / Quote state
  Message? _replyToMessage;     // Message being replied to
  bool _isQuote = false;        // Whether this is a quote (partial text)
  String? _quoteText;           // Selected text for quote
  int _quoteOffset = 0;         // Offset of quote in original message
  int _quoteLength = 0;         // Length of quoted fragment
  String? _highlightMessageId;  // Message ID to highlight (scroll-to)
  Timer? _highlightTimer;       // Timer to clear highlight

  // Editing state
  bool _isEditing = false;
  String? _editingMessageId;

  // GlobalKeys for messages to allow precise scrolling
  final Map<String, GlobalKey> _messageKeys = {};
  final GlobalKey _inputKey = GlobalKey();
  double _inputHeight = 90.0;

  // Пагинация
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    if (widget.otherUserOnline != null) {
      _isOtherUserOnline = widget.otherUserOnline!;
    }
    if (widget.otherUserLastSeen != null) {
      _otherUserLastSeen = widget.otherUserLastSeen;
    }
    if (widget.otherUserId != null) {
      _otherUserId = widget.otherUserId;
    }
    _loadData();
    _initWebSocket();
    _scrollController.addListener(_onScroll);
    _inputFocusNode.addListener(_onFocusChanged);

    // Notify provider that this chat is open (so unread count is not incremented)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<UnreadCountProvider>().setOpenChat(widget.chatId);
      } catch (_) {}
    });
  }

  void _onFocusChanged() {
    if (_inputFocusNode.hasFocus && _showEmojiPanel) {
      setState(() {
        _isKeyboardRising = true;
      });
    }
  }

  void _initWebSocket() {
    // Subscribe to WebSocket events for this chat
    // Note: We only use eventStream.listen, not subscribe() to avoid duplicate handling
    _wsSubscription = _wsService.eventStream.listen(_handleWebSocketEvent);
  }

  Future<void> _saveKeyboardHeight(double height) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('keyboard_height', height);
    } catch (e) {
      debugPrint('Error saving keyboard height: $e');
    }
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
    } else if (event.type == WebSocketEventType.userStatus) {
      _onUserStatusUpdate(event);
    } else if (event.type == WebSocketEventType.unreadCountUpdated) {
      final chatId = event.data['chat_id']?.toString();
      if (chatId == widget.chatId) {
        _onUnreadCountUpdated(event);
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
    final bool? active =
        event.data['active'] is bool ? event.data['active'] as bool : null;
    final bool isAdded = action == 'added' || active == true;
    final bool isRemoved = action == 'removed' || active == false;

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
          if (isAdded) {
            mySet.add(emoji);
          } else if (isRemoved) {
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
        debugPrint('PrivateChatScreen: error updating reactions in DB: $e');
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
      debugPrint('PrivateChatScreen: error deleting message from DB: $e');
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

  void _onUnreadCountUpdated(WebSocketEvent event) {
    final newUnreadCount = event.data['unread_count'] as int? ?? 0;
    if (mounted) {
      setState(() {
        _unreadCount = newUnreadCount;
        if (_unreadCount == 0) {
          _firstUnreadMessageId = null;
          _hasScrolledToUnread = false;
          _showUnreadDivider = false;
        }
      });
    }
  }

  void _onNewMessage(WebSocketEvent event) {
    final messageData = event.data['message'] as Map<String, dynamic>?;
    if (messageData == null) return;

    final message = Message.fromJson(messageData);

    // Дедупликация / обновление: проверяем есть ли уже сообщение по serverId или localId
    final existingIndex = _messages.indexWhere((m) =>
        m.id == message.id ||
        (message.localId != null &&
            message.localId!.isNotEmpty &&
            m.localId == message.localId));

    if (existingIndex != -1) {
      // Сообщение уже в списке (отправлено с этого устройства). Обновляем id и статус если нужно
      if (_messages[existingIndex].id != message.id ||
          _messages[existingIndex].sendStatus != 1) {
        if (mounted) {
          setState(() {
            _messages[existingIndex] = _messages[existingIndex].copyWith(
              id: message.id,
              sendStatus: 1,
            );
          });
        }
      }
      return;
    }

    // Сохранить в Drift для оффлайн-доступа
    final db = AppDatabase();
    try {
      db.saveMessage(_messageToCompanion(message));
    } catch (_) {}

    if (mounted) {
      setState(() {
        // If typing user sent message, immediately cancel typing
        if (_typingUserId == message.senderId || _isTyping) {
          _typingTimer?.cancel();
          _isTyping = false;
          _typingUserId = null;
        }
        _messages.insert(0, message);
      });

      // If message is from other user, queue it for mark-as-read
      if (message.senderId != _currentUserId) {
        _onMessageVisible(message.id);
      }
    }
  }

  void _onTypingIndicator(WebSocketEvent event) {
    final chatId = event.data['chat_id']?.toString();
    if (chatId != widget.chatId) return;

    final typingUserId = event.data['user_id']?.toString();
    if (typingUserId == _currentUserId) return;

    final bool isTyping = event.data['is_typing'] != false;

    if (mounted) {
      if (!isTyping) {
        // User stopped typing / cleared input field
        _typingTimer?.cancel();
        setState(() {
          _isTyping = false;
          _typingUserId = null;
        });
        return;
      }

      setState(() {
        _typingUserId = typingUserId;
        _isTyping = true;
      });

      // Clear typing indicator after 4 seconds (Telegram-like smooth safety window)
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _typingUserId = null;
          });
        }
      });
    }
  }

  void _onEmojiToggle() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _transitionTimer?.cancel();

    if (_showEmojiPanel || _isKeyboardRising) {
      if (_isKeyboardRising && !_showEmojiPanel) {
        // User clicked while transitioning, force close panel
        setState(() {
          _isKeyboardRising = false;
          _showEmojiPanel = false;
        });
        _inputFocusNode.unfocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        return;
      }

      // Panel is open, switch to keyboard
      setState(() {
        _isKeyboardRising = true;
        // Keep _showEmojiPanel = true to prevent jump, will be hidden in build()
      });
      _inputFocusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');

      // Safety for floating windows: if no inset change in 600ms, hide panel
      _transitionTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && _isKeyboardRising && _showEmojiPanel) {
          setState(() {
            _showEmojiPanel = false;
            _isKeyboardRising = false;
          });
        }
      });
    } else {
      // Switch to panel: (Panel renders UNDER keyboard first)
      setState(() {
        _showEmojiPanel = true;
        _isKeyboardRising = false;
        if (bottomInset > 0) {
          _isKeyboardFalling = true;
        }
      });
      // Now hide keyboard - it will slide down and reveal the panel
      if (bottomInset > 0 || _inputFocusNode.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _inputFocusNode.unfocus();
      }
    }
  }

  void _handleBackspace() {
    final text = _textController.text;
    final selection = _textController.selection;

    if (!selection.isValid || (selection.isCollapsed && selection.start == 0)) {
      return;
    }

    if (selection.isCollapsed) {
      final textBefore = text.substring(0, selection.start);
      final charBefore = textBefore.characters.last;
      final newText = text.replaceRange(
        selection.start - charBefore.length,
        selection.start,
        '',
      );
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start - charBefore.length,
        ),
      );
    } else {
      final newText = text.replaceRange(selection.start, selection.end, '');
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    }
  }

  void _onUserStatusUpdate(WebSocketEvent event) {
    final userId = event.data['user_id']?.toString();
    if (userId != _otherUserId) return;

    if (mounted) {
      setState(() {
        _isOtherUserOnline = event.data['is_online'] == true;
        if (event.data['last_seen'] != null) {
          _otherUserLastSeen =
              DateTimeUtils.parseUtcDateTime(event.data['last_seen']);
        } else if (!_isOtherUserOnline) {
          _otherUserLastSeen = DateTime.now();
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
        if (_textController.text.trim().isNotEmpty) {
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
    // Handle read status update - mark all our messages in this chat as read
    final readerId = event.data['reader_id']?.toString();
    if (readerId == _currentUserId) return; // We are the reader, not the sender

    if (mounted) {
      setState(() {
        // Mark all messages sent by current user as read
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].senderId == _currentUserId) {
            _messages[i] = _messages[i].copyWith(isRead: true);
          }
        }
      });

      // Обновить статус isRead в Drift для персистенции
      final db = AppDatabase();
      try {
        db.markMessagesAsRead(widget.chatId, _currentUserId ?? '');
      } catch (e) {
        debugPrint('Drift markMessagesAsRead error: $e');
      }
    }
  }

  /// Called by VisibleMessageDetector when an unread incoming message becomes visible.
  /// Queues the message for batch mark-as-read (debounced).
  void _onMessageVisible(String messageId) {
    if (_pendingMarkRead.contains(messageId)) return;
    _pendingMarkRead.add(messageId);

    // Debounce: flush after 300ms of no new visible messages
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 300), () {
      _flushMarkRead();
    });
  }

  /// Flush pending mark-as-read: find the latest visible message and mark up to it
  Future<void> _flushMarkRead() async {
    if (_pendingMarkRead.isEmpty || _isMarkingRead) return;
    _isMarkingRead = true;

    // Find the latest message among the pending ones (highest created_at = lowest index in reversed list)
    String? latestMessageId;
    int latestIndex = -1;
    for (final id in _pendingMarkRead) {
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx != -1 && idx < (latestIndex == -1 ? 999999 : latestIndex)) {
        latestIndex = idx;
        latestMessageId = id;
      }
    }

    _pendingMarkRead.clear();
    _isMarkingRead = false;

    if (latestMessageId == null) return;

    // Mark all messages up to and including this one as read
    final result = await ChatService.markMessagesReadUpTo(
      chatId: widget.chatId,
      messageId: latestMessageId,
    );

    final markedCount = result['marked_count'] as int? ?? 0;
    if (markedCount > 0) {
      _wsService.sendMessageRead(widget.chatId, markedCount: markedCount);

      // Optimistically update local unread count
      if (mounted) {
        setState(() {
          _unreadCount = (_unreadCount - markedCount).clamp(0, _unreadCount);
        });
      }

      // Update the provider
      if (mounted) {
        final provider = context.read<UnreadCountProvider>();
        provider.decrement(widget.chatId, markedCount);
      }
    }
  }

  /// Mark all unread messages in this chat as read (used when entering chat)
  Future<void> _markAllMessagesAsRead() async {
    final result = await ChatService.markMessagesAsRead(chatId: widget.chatId);
    final markedCount = result['marked_count'] as int? ?? 0;
    if (markedCount > 0) {
      _wsService.sendMessageRead(widget.chatId, markedCount: markedCount);

      // Optimistically clear unread count, but KEEP the divider
      // (_showUnreadDivider and _firstUnreadMessageId persist until user leaves chat)
      if (mounted) {
        setState(() {
          _unreadCount = 0;
        });
      }

      // Update the provider
      if (mounted) {
        final provider = context.read<UnreadCountProvider>();
        provider.clear(widget.chatId);
      }
    }
  }

  // === Reply / Quote methods ===

  /// Start a reply to a message (full message reply)
  void _startReply(Message message) {
    setState(() {
      _replyToMessage = message;
      _isQuote = false;
      _quoteText = null;
      _quoteOffset = 0;
      _quoteLength = 0;
    });
    // Focus the input field
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
  }

  /// Start a quote reply (partial text)
  // ignore: unused_element
  void _startQuote(Message message, String selectedText, int offset, int length) {
    setState(() {
      _replyToMessage = message;
      _isQuote = true;
      _quoteText = selectedText;
      _quoteOffset = offset;
      _quoteLength = length;
    });
    // Focus the input field
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
  }

  /// Cancel the current reply/quote
  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
      _isQuote = false;
      _quoteText = null;
      _quoteOffset = 0;
      _quoteLength = 0;
    });
  }

  /// Cancel current message editing
  void _cancelEditing() {
    _stopMyTyping();
    setState(() {
      _isEditing = false;
      _editingMessageId = null;
      _textController.clear();
    });
  }

  /// Scroll to a specific message and highlight it
  Future<void> _scrollToMessage(String messageId, {int retryCount = 0}) async {
    if (!mounted) return;

    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      // Message is already built and has a context, scroll precisely
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        alignment: 0.5, // Center the message in view
      );
      _setHighlight(messageId);
      return;
    }

    // If message is not built yet, we need to find it in the list
    int index = _messages.indexWhere((m) => m.id == messageId);
    
    // If message not in list, try to load more
    if (index == -1) {
      if (_hasMoreMessages && retryCount < 5) {
        await _loadMoreMessages();
        // Recurse to try finding it again
        return _scrollToMessage(messageId, retryCount: retryCount + 1);
      }
      return; // Not found even after loading more
    }

    // Message is in the list but not built. 
    // In a reversed ListView, higher index means OLDER message = HIGHER scroll offset.
    // We'll jump close to the target then let it refine.
    const estimatedItemHeight = 110.0;
    final targetOffset = index * estimatedItemHeight;

    // Use jump if far, animate if close
    if ((_scrollController.offset - targetOffset).abs() > 2000) {
      _scrollController.jumpTo(targetOffset);
    } else {
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Wait a bit for ListView to build the items at this offset
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Retry to refine position if message is now built
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
    // If original message is in this chat, just scroll to it
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

    // Original message is in a DIFFERENT chat.
    // 1. Check if we have access and get chat details
    final result = await ChatService.getChat(originalChatId);
    if (result['success'] == true) {
      final chat = result['chat'] as ChatDetails;
      
      // 2. Navigate to the appropriate screen
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
      // User doesn't have access or network error
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

  /// Handle scroll events — пагинация при прокрутке вверх + FAB visibility
  void _onScroll() {
    if (!_scrollController.hasClients || _messages.isEmpty) return;

    // Пагинация: когда пользователь проскроллил вверх — загрузить ещё
    if (_hasMoreMessages && !_isLoadingMore) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      // В reverse=true: верх = maxScrollExtent, низ = 0
      // Когда scrollOffset приближается к maxScrollExtent — загрузить старые
      if (currentScroll >= maxScroll * 0.8) {
        _loadMoreMessages();
      }
    }

    // Show/hide scroll-down FAB logic: 
    // - Hide if scrolling UP (towards older messages)
    // - Show if scrolling DOWN (towards newer messages)
    // - Hide if we reached the top of the newest message
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    if (delta < 0) {
      // Scrolling DOWN (towards 0, newer messages in reverse list)
      _accumulatedScrollDown -= delta;
      _accumulatedScrollUp = 0;
    } else if (delta > 0) {
      // Scrolling UP (towards older messages)
      _accumulatedScrollUp += delta;
      _accumulatedScrollDown = 0;
    }

    final isScrollingDown = _scrollController.position.userScrollDirection == ScrollDirection.forward;
    
    // Clear jump history when near bottom
    if (offset < 100 && _jumpHistory.isNotEmpty) {
      _jumpHistory.clear();
    }

    // Dynamic threshold: height of the newest message
    double threshold = 150.0; // Default
    if (_messages.isNotEmpty) {
      final firstMsgId = _messages.first.id;
      final key = _messageKeys[firstMsgId];
      final renderBox = key?.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        threshold = renderBox.size.height; // Message height + small buffer
      }
    }
    
    bool shouldShow = _showScrollDownFab;
    if (offset <= threshold) {
      shouldShow = false;
    } else if (_jumpHistory.isNotEmpty) {
      // Always show if we have return history and are away from bottom
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
        _chatType = chat.chatType;
      });
      // Find the other participant for private chat
      for (var participant in chat.participants) {
        if (participant.id != _currentUserId) {
          setState(() {
            _chatName = participant.displayName.isNotEmpty
                ? participant.displayName
                : participant.username;
            _chatAvatar = participant.avatarUrl;
            _otherUserId = participant.id;
            _isOtherUserOnline = participant.isOnline;
            _otherUserLastSeen = participant.lastSeen;
          });
          break;
        }
      }
    }

    // Get unread info before loading messages
    final unreadInfo = await ChatService.getUnreadInfo(chatId: widget.chatId);
    if (unreadInfo['success'] == true) {
      setState(() {
        _unreadCount = unreadInfo['unread_count'] as int? ?? 0;
        _firstUnreadMessageId =
            unreadInfo['first_unread_message_id'] as String?;
        // Установить разделитель при входе в чат (если есть непрочитанные)
        if (_unreadCount > 0 && _firstUnreadMessageId != null) {
          _showUnreadDivider = true;
          _dividerUnreadCount = _unreadCount;
        }
      });
    }

    // Load saved keyboard height
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHeight = prefs.getDouble('keyboard_height');
      if (savedHeight != null && savedHeight > 100 && mounted) {
        setState(() {
          _keyboardHeight = savedHeight;
        });
      }
    } catch (e) {
      debugPrint('Error loading keyboard height: $e');
    }

    // Load messages
    await _loadMessages();

    // Scroll to initial message if specified (e.g. from cross-chat navigation)
    if (widget.initialMessageId != null) {
      _scrollToMessage(widget.initialMessageId!);
    } else if (_firstUnreadMessageId != null) {
      // Scroll to first unread message if exists (before marking as read,
      // so user can see where they left off)
      _scrollToFirstUnread();
    }

    // Mark ALL unread messages as read after scrolling
    // (use markMessagesAsRead which marks all, not just up to first unread)
    if (_unreadCount > 0) {
      _markAllMessagesAsRead();
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    // 1. Сначала загрузить из Drift (мгновенно, offline-first)
    final db = AppDatabase();
    List<DbMessage> localMessages = [];
    try {
      localMessages = await db.getMessages(widget.chatId, limit: 50);
    } catch (e) {
      debugPrint('Drift getMessages error: $e');
    }

    if (localMessages.isNotEmpty && mounted) {
      // Обработать "зависшие" sending-сообщения:
      // - Если serverId уже установлен → сообщение было подтверждено, исправить на sent
      // - Если serverId null → приложение закрылось до подтверждения, пометить как failed
      final fixedMessages = localMessages.map((m) {
        if (m.sendStatus == MessageSendStatus.sending.index) {
          if (m.serverId != null) {
            // Сообщение было подтверждено сервером, но статус не обновился
            db.updateMessageSendStatus(
                m.localId, m.serverId!, MessageSendStatus.sent.index);
            return m.copyWith(sendStatus: MessageSendStatus.sent.index);
          } else {
            // Действительно зависшее сообщение
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
    }

    // 2. Затем загрузить с сервера (обновление)
    final result =
        await ChatService.getMessages(chatId: widget.chatId, limit: 50);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final serverMessages = result['messages'] as List<Message>;
          _hasMoreMessages = result['has_more'] as bool? ?? false;

          // Сохранить pending/failed сообщения из текущего списка (их нет на сервере)
          final pendingMessages = _messages
              .where(
                (m) => m.sendStatus != 1 && m.localId != null,
              )
              .toList();

          _messages.clear();
          _messageReactions.clear();
          _myReactions.clear();
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

          // Сортировка по createdAt по убыванию (новейшие первыми)
          // для корректного отображения в reverse=true ListView
          _messages.sort((a, b) {
            try {
              final ta = DateTime.parse(a.createdAt);
              final tb = DateTime.parse(b.createdAt);
              return tb.compareTo(ta); // descending
            } catch (_) {
              return 0;
            }
          });

          // Сохранить в Drift для оффлайн-доступа
          try {
            db.saveMessages(
                _messages.map((m) => _messageToCompanion(m)).toList());
          } catch (e) {
            debugPrint('Drift saveMessages error: $e');
          }
        } else if (localMessages.isEmpty) {
          // Нет ни локальных, ни серверных — показать пустое состояние
        }
      });

      if (_firstUnreadMessageId == null || _unreadCount == 0) {
        _scrollToBottom();
      }
    }
  }

  /// Загрузить старые сообщения (пагинация)
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() => _isLoadingMore = true);

    // Получить последнее (самое старое) сообщение
    final lastMessage = _messages.isNotEmpty ? _messages.last : null;

    // Сначала попробовать загрузить из Drift
    final db = AppDatabase();
    try {
      final localMessages = await db.getMessages(
        widget.chatId,
        beforeCreatedAt: lastMessage?.createdAt,
        limit: 50,
      );

      if (localMessages.isNotEmpty) {
        setState(() {
          // Дедупликация: добавлять только сообщения, которых ещё нет
          for (final m
              in localMessages.map((m) => Message.fromDbMessage(m))) {
            if (!_messages.any((existing) =>
                existing.id == m.id ||
                (m.localId != null && existing.localId == m.localId))) {
              _messages.add(m);
              if (m.reactions.isNotEmpty) {
                _messageReactions[m.id] = Map.from(m.reactions);
              }
              if (m.myReactions.isNotEmpty) {
                _myReactions[m.id] = Set.from(m.myReactions);
              }
            }
          }
          _isLoadingMore = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Drift loadMore error: $e');
    }

    // Если в Drift нет — загрузить с сервера
    final result = await ChatService.getMessages(
      chatId: widget.chatId,
      beforeMessageId: lastMessage?.id,
      limit: 50,
    );

    if (result['success'] == true && mounted) {
      final newMessages = result['messages'] as List<Message>;
      _hasMoreMessages = result['has_more'] as bool? ?? false;

      // Сохранить в Drift
      try {
        db.saveMessages(
            newMessages.map((m) => _messageToCompanion(m)).toList());
      } catch (e) {
        debugPrint('Drift saveMessages error: $e');
      }

      setState(() {
        // Дедупликация: добавлять только сообщения, которых ещё нет
        for (final m in newMessages) {
          if (!_messages.any((existing) => existing.id == m.id)) {
            _messages.add(m);
            if (m.reactions.isNotEmpty) {
              _messageReactions[m.id] = Map.from(m.reactions);
            }
            if (m.myReactions.isNotEmpty) {
              _myReactions[m.id] = Set.from(m.myReactions);
            }
          }
        }
        _isLoadingMore = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  /// Конвертация Message → MessagesCompanion для Drift
  MessagesCompanion _messageToCompanion(Message msg) {
    // pending (sendStatus==0) or failed (sendStatus==2): serverId отсутствует в Drift
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
      // isForward: Value(msg.isForward),
      // forwardFromId: Value(msg.forwardFromId),
      // forwardFromName: Value(msg.forwardFromName),
    );
  }

  /// Scroll to the first unread message
  void _scrollToFirstUnread() {
    if (_firstUnreadMessageId == null || _hasScrolledToUnread) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final index = _messages.indexWhere((m) => m.id == _firstUnreadMessageId);
      if (index == -1) {
        _scrollToBottom();
        return;
      }

      // In reversed list, we need to calculate the offset
      // Each message is approximately 60-100 pixels, we'll estimate
      // Scroll to show the unread message with some context above
      const estimatedItemHeight = 80.0;
      final targetOffset =
          (index - 2).clamp(0, _messages.length - 1) * estimatedItemHeight;

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );

      setState(() {
        _hasScrolledToUnread = true;
      });
    });
  }

  Future<void> _sendMessage() async {
    final String text = _textController.text.trim();
    if ((text.isEmpty && _attachedFiles.isEmpty) || _isSending) return;

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
        debugPrint('Error editing message: $e');
      }
      return;
    }

    // Capture reply/quote state before clearing
    final replyTo = _replyToMessage;
    final replyIsQuote = _isQuote;
    final replyQuoteText = _quoteText;
    final replyQuoteOffset = _quoteOffset;
    final replyQuoteLength = _quoteLength;

    _stopMyTyping();
    _textController.clear();
    setState(() {
      _isSending = true;
      _isUploading = _attachedFiles.isNotEmpty;
      // Clear reply state
      _replyToMessage = null;
      _isQuote = false;
      _quoteText = null;
      _quoteOffset = 0;
      _quoteLength = 0;
    });

    try {
      // Upload files first if any
      List<UploadResult> uploadResults = [];
      for (int i = 0; i < _attachedFiles.length; i++) {
        final result = await _fileService.uploadFile(
          _attachedFiles[i],
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
        uploadResults.add(result);
      }

      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });

      final String messageType = _attachedFiles.isNotEmpty
          ? _getMessageTypeFromMimeType(uploadResults.first.mimeType)
          : 'text';
      final String content = _attachedFiles.isNotEmpty
          ? (text.isNotEmpty ? text : uploadResults.first.fileName)
          : text;
      final String? fileUrl =
          uploadResults.isNotEmpty ? uploadResults[0].url : null;
      final String? fileName =
          uploadResults.isNotEmpty ? uploadResults[0].fileName : null;

      _clearAttachedFiles();

      final syncService = SyncService();
      String? pendingLocalId;
      DbMessage? pendingMsg;
      try {
        pendingMsg = await syncService.createPendingMessage(
          chatId: widget.chatId,
          senderId: _currentUserId ?? '',
          content: content,
          messageType: messageType,
          fileUrl: fileUrl,
          fileName: fileName,
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

      // 2. Мгновенно добавить в UI со статусом "sending"
      if (pendingMsg != null) {
        pendingLocalId = pendingMsg.localId; // non-null capture для замыканий
        final message = Message.fromDbMessage(pendingMsg);
        if (mounted) {
          setState(() {
            _messages.insert(0, message);
            _isSending = false;
          });
          _scrollToBottom();
        }

        // 3. Отправить на сервер в фоне
        try {
          final result = await ChatService.sendMessage(
            chatId: widget.chatId,
            content: content,
            messageType: messageType,
            localId: pendingLocalId,
            fileUrl: fileUrl,
            fileName: fileName,
            replyToMessageId: replyTo?.id,
            isQuote: replyIsQuote,
            quoteText: replyQuoteText,
            quoteOffset: replyQuoteOffset,
            quoteLength: replyQuoteLength,
          );

          if (result['success'] == true) {
            // 4. Подтвердить — заменить localId на serverId
            final sentMessage = result['message'];
            final serverId = sentMessage is Message ? sentMessage.id : null;
            if (serverId != null && serverId.isNotEmpty) {
              await syncService.confirmMessageSent(pendingLocalId, serverId);
              // Обновить в UI
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
            // 5. Пометить как failed
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
        // Fallback: SyncService недоступен — отправить напрямую через API
        final result = await ChatService.sendMessage(
          chatId: widget.chatId,
          content: content,
          messageType: messageType,
          fileUrl: fileUrl,
          fileName: fileName,
        );

        if (mounted) {
          if (result['success'] == true) {
            final sentMsg = result['message'] as Message;
            setState(() {
              // Дедупликация: не добавлять если WS уже принёс это сообщение
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

      // Send additional files as separate messages
      for (int i = 1; i < uploadResults.length; i++) {
        final upload = uploadResults[i];
        final additionalMessageType =
            _getMessageTypeFromMimeType(upload.mimeType);

        final additionalResult = await ChatService.sendMessage(
          chatId: widget.chatId,
          content: upload.fileName,
          messageType: additionalMessageType,
          fileUrl: upload.url,
          fileName: upload.fileName,
        );

        if (mounted && additionalResult['success'] == true) {
          final additionalMsg = additionalResult['message'] as Message;
          setState(() {
            // Дедупликация: не добавлять если WS уже принёс это сообщение
            if (!_messages.any((m) => m.id == additionalMsg.id)) {
              _messages.insert(0, additionalMsg);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Send message error: $e');
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// Повторить отправку failed-сообщения
  Future<void> _retryMessage(Message message) async {
    if (message.localId == null) return;
    final syncService = SyncService();

    // Обновить UI на "sending"
    setState(() {
      final idx = _messages.indexWhere((m) => m.localId == message.localId);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(sendStatus: 0);
      }
    });

    await syncService.retryFailedMessage(message.localId!);

    // Перезагрузить сообщение из БД
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

  /// Get message type from mime type
  String _getMessageTypeFromMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('audio/')) return 'audio';
    return 'file';
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

  String _formatTime(String timestamp) {
    return DateTimeUtils.formatTimeHHmm(timestamp);
  }

  /// Validates and returns a valid avatar URL, or null if invalid
  // ignore: unused_element
  String? _getValidAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return url;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateInputHeight();
    final displayName = widget.otherUserName ?? _chatName;

    return Consumer<LiquidGlassProvider>(
      builder: (context, glassProvider, _) {
        final glassEnabled = glassProvider.enabled;

        return ChatScaffold(
          canPop: !_showEmojiPanel && MediaQuery.of(context).viewInsets.bottom == 0,
          onPopInvoked: (didPop, _) {
            if (!didPop) {
              if (_showEmojiPanel) {
                setState(() => _showEmojiPanel = false);
              } else if (MediaQuery.of(context).viewInsets.bottom > 0) {
                FocusScope.of(context).unfocus();
              }
            }
          },
          appBar: FloatingGlassAppBar(
            name: displayName,
            avatarUrl: widget.otherUserAvatar ?? _chatAvatar,
            isOnline: _isOtherUserOnline,
            lastSeen: _otherUserLastSeen,
            statusText: _isTyping ? context.l10n.translate('chat_typing') : null,
            onBack: () => Navigator.pop(context),
            onTitleTap: _viewUserProfile,
            onAvatarTap: () {
              GlassChatMenu.show(
                context,
                isMuted: _isMuted,
                onVoiceCall: _startVoiceCall,
                onVideoCall: _startVideoCall,
                onSearch: () {
                  _searchMessages();
                },
                onToggleMute: _toggleMuteNotifications,
                onClearHistory: _showClearHistoryDialog,
                onReport: _showBlockUserDialog,
                onViewProfile: _viewUserProfile,
              );
            },
          ),
          body: _buildChatContent(glassEnabled),
        );
      },
    );
  }

  // Выделен метод для построения контента чата (сообщения + поле ввода)
  Widget _buildChatContent(bool glassEnabled) {
    final wallpaperPath = context.watch<WallpaperProvider>().wallpaperPath;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    // В glass-режиме Scaffold без appBar, поэтому нужно учесть
    // высоту статус-бара + AppBar для верхнего отступа контента
    final topPadding = mediaQuery.padding.top + kToolbarHeight + 16.0;
    final bottomInset = mediaQuery.viewInsets.bottom;

    // Cap panel height to ensure it doesn't cover the entire chat in small windows
    // but allow it to be as large as the keyboard if possible.
    final double maxPossibleHeight = math.max(200.0, screenHeight - topPadding - 120.0);
    
    // Update keyboard height only when it grows or is stable
    if (bottomInset > 100) {
      if (bottomInset > _keyboardHeight) {
        // Update immediately to prevent jump when keyboard is taller than cache
        _keyboardHeight = bottomInset;
      }
    }

    // The panel height should exactly match our best knowledge of the keyboard height
    final double targetPanelHeight = _keyboardHeight;

    // Keyboard-to-Emoji or Emoji-to-Keyboard stabilization:
    if (_isKeyboardFalling && bottomInset == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isKeyboardFalling) {
          setState(() => _isKeyboardFalling = false);
        }
      });
    }

    if (_isKeyboardRising && _showEmojiPanel) {
      // Hide panel only when keyboard is high enough or stable
      final bool keyboardCoveredPanel = bottomInset >= targetPanelHeight - 5;
      final bool keyboardIsStable = bottomInset > 100 && bottomInset == _lastBottomInset;
      
      if (keyboardCoveredPanel || keyboardIsStable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isKeyboardRising) {
            _transitionTimer?.cancel();
            setState(() {
              // Crucial: Update height to actual current inset to prevent any jump 
              // at the moment of switching shouldShowPanel from true to false.
              _keyboardHeight = bottomInset; 
              _isKeyboardRising = false;
              _showEmojiPanel = false;
            });
            _saveKeyboardHeight(bottomInset);
          }
        });
      }
    }
    
    _lastBottomInset = bottomInset;

    final bool shouldShowPanel = _showEmojiPanel || _isKeyboardRising;
    
    // If we are searching inside the panel (keyboard is up but not for main input), we lift the panel.
    // We don't lift it if the keyboard is just falling from the main input.
    final bool isSearchingInPanel = _showEmojiPanel && bottomInset > 0 && !_isKeyboardRising && !_isKeyboardFalling;

    // Total stable offset for message list and input field.
    final double bottomOffset = isSearchingInPanel
        ? (targetPanelHeight + bottomInset)
        : (shouldShowPanel 
            ? math.max(targetPanelHeight, bottomInset) 
            : (bottomInset > 0 ? bottomInset : 0));

    // The actual height of the emoji panel container.
    final double effectivePanelHeight = shouldShowPanel ? targetPanelHeight : 0;

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
                  '$_chatName is typing...',
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
                    const SizedBox(height: 8),
                    Text(
                      'Start the conversation!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      // В glass-режиме добавляем верхний отступ,
                      // чтобы сообщения не прятались за glass AppBar
                      padding: EdgeInsets.only(
                        top: topPadding,
                        bottom: _inputHeight + bottomOffset,
                      ),
                      itemCount: _messages.length +
                          (_showUnreadDivider && _firstUnreadMessageId != null
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        // Insert unread divider between unread and read messages.
                        // In a reverse=true ListView: index 0 = bottom (newest), N = top (oldest).
                        // _messages[0] = newest, _messages[N] = oldest.
                        // first_unread_message is the OLDEST unread (highest index among unread).
                        // Layout: [newer unread...] [first_unread] | DIVIDER | [last_read] [older read...]
                        if (_showUnreadDivider &&
                            _firstUnreadMessageId != null) {
                          final unreadIndex = _messages
                              .indexWhere((m) => m.id == _firstUnreadMessageId);
                          if (unreadIndex != -1) {
                            // Divider goes AFTER the first unread message,
                            // between unread (lower indices = newer) and read (higher indices = older)
                            final dividerPosition = unreadIndex + 1;

                            if (index == dividerPosition) {
                              return _buildUnreadDivider();
                            }
                            if (index < dividerPosition) {
                              // Unread messages (newer): direct index mapping
                              return _buildMessageItem(index);
                            }
                            // index > dividerPosition: read messages (older), shift by 1 for divider
                            final adjustedIndex = index - 1;
                            if (adjustedIndex >= 0 &&
                                adjustedIndex < _messages.length) {
                              return _buildMessageItem(adjustedIndex);
                            }
                          }
                        }

                        if (index < 0 || index >= _messages.length) {
                          return const SizedBox.shrink();
                        }

                        return _buildMessageItem(index);
                      },
                    ),
                  ),
                ],
              );

    final messageInput = _buildMessageInput();

    final bool isKeyboardVisible = bottomInset > 0;

    // Use PopScope to handle back button for closing emoji panel
    return PopScope(
      canPop: !_showEmojiPanel && !isKeyboardVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_showEmojiPanel) {
            setState(() => _showEmojiPanel = false);
          } else if (isKeyboardVisible) {
            FocusScope.of(context).unfocus();
          }
        }
      },
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Background wallpaper
                if (wallpaperPath != null)
                  Positioned.fill(
                    child: Image.file(
                      File(wallpaperPath),
                      fit: BoxFit.cover,
                    ),
                  ),
                // Сообщения на весь экран (с верхним отступом через ListView.padding)
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      final statusBarHeight = MediaQuery.of(context).padding.top;
                      // FloatingGlassAppBar использует _kAppBarHeight (54) + vertical padding (8).
                      final appBarBottom = statusBarHeight + 54 + 8;
                      final fadeStart = appBarBottom + 20; // Начинаем затухание чуть ниже AppBar
                      final fadeEnd = statusBarHeight; // Полная прозрачность у верхнего края

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
                // Кнопка прокрутки вниз (теперь здесь, в главном Stack чата)
                Positioned(
                  right: 14,
                  bottom: _inputHeight + 10 + bottomOffset,
                  child: ScrollDownFab(
                    visible: _showScrollDownFab,
                    unreadCount: _unreadCount,
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
                // Поле ввода внизу (внутри Stack над сообщениями)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomOffset,
                  child: Container(
                    key: _inputKey,
                    child: messageInput,
                  ),
                ),
                // Панель эмодзи/стикеров ВНУТРИ Stack
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: isSearchingInPanel ? bottomInset : 0,
                  child: AnimatedContainer(
                    duration: Duration(
                        milliseconds: (shouldShowPanel || bottomInset > 0) ? 0 : 200),
                    curve: Curves.easeOutCubic,
                    height: effectivePanelHeight,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: EmojiStickerPanel(
                      controller: _textController,
                      onBackspace: _handleBackspace,
                      onClose: () => setState(() => _showEmojiPanel = false),
                      height: targetPanelHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreadDivider() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Непрочитанные сообщения ($_dividerUnreadCount)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(int index) {
    final message = _messages[index];
    final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());
    final bool isMe = message.senderId == _currentUserId;
    final isHighlighted = _highlightMessageId == message.id;

    Widget messageWidget = MessageBubble(
      key: key,
      message: message,
      isMe: isMe,
      currentUserId: _currentUserId ?? '',
      chatType: _chatType,
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
      onFileTap: (url, name, type) => _openFile(url, name, type),
      formatTime: _formatTime,
    );

    // Wrap with SwipeToReplyWrapper
    messageWidget = SwipeToReplyWrapper(
      onReply: () => _startReply(message),
      enabled: true,
      child: messageWidget,
    );

    // Wrap ALL incoming messages with VisibleMessageDetector
    if (!isMe) {
      messageWidget = VisibleMessageDetector(
        messageId: message.id,
        onMessageSeen: () => _onMessageVisible(message.id),
        visibilityThreshold: 0.3,
        visibleDuration: const Duration(milliseconds: 300),
        child: messageWidget,
      );
    }

    // Context menu trigger
    messageWidget = GestureDetector(
      onTap: () {
        debugPrint('DEBUG: GestureDetector.onTap for message ${message.id}');
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

    // Add date separator if needed
    final prevMessage =
        index < _messages.length - 1 ? _messages[index + 1] : null;
    final currentDt = DateTime.tryParse(message.createdAt) ?? DateTime.now();
    final prevDt = prevMessage != null
        ? (DateTime.tryParse(prevMessage.createdAt) ?? DateTime.now())
        : null;
    final currentDate = _dateOnly(currentDt);
    final prevDate = prevDt != null ? _dateOnly(prevDt) : null;

    final items = <Widget>[];
    if (currentDate != prevDate) {
      items.add(DateSeparator(dateLabel: _formatDateLabel(currentDt)));
    }

    // Add unread separator
    if (_showUnreadDivider && message.id == _firstUnreadMessageId) {
      items.add(UnreadSeparator(
        count: _dividerUnreadCount,
        onTap: () {},
      ));
    }

    items.add(messageWidget);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items,
    );
  }

  Widget _buildMessageInput() {
    return ChatInputBar(
      controller: _textController,
      focusNode: _inputFocusNode,
      isEditing: _isEditing,
      onCancelEditing: _cancelEditing,
      replyToMessage: _replyToMessage,
      isQuote: _isQuote,
      quoteText: _quoteText,
      onCancelReply: _cancelReply,
      onTapReply: _replyToMessage != null
          ? () => _scrollToMessage(_replyToMessage!.id)
          : null,
      attachedFiles: _attachedFiles,
      attachedFileNames: _attachedFileNames,
      onRemoveAttachment: _removeAttachedFile,
      isUploading: _isUploading,
      uploadProgress: _uploadProgress,
      onChanged: _onInputTextChanged,
      onSend: _sendMessage,
      onAttach: _showAttachmentPicker,
      onEmoji: _onEmojiToggle,
      isSending: _isSending,
    );
  }


  /// Navigate to user profile screen
  void _viewUserProfile() {
    if (_otherUserId != null) {
      Navigator.pushNamed(
        context,
        '/profile',
        arguments: {'userId': _otherUserId},
      );
    }
  }

  /// Open search screen for this chat
  void _searchMessages() {
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {
        'chatId': widget.chatId,
        'chatName': _chatName,
      },
    );
  }

  /// Show confirmation dialog for clearing chat history
  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: Text('Delete all messages in this chat with $_chatName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearChatHistory();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Clear all messages in this chat
  Future<void> _clearChatHistory() async {
    final result = await ChatService.clearChatHistory(chatId: widget.chatId);
    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _messages.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat history cleared')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'Failed to clear history')),
        );
      }
    }
  }

  /// Show confirmation dialog for blocking user
  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content:
            Text('Block $_chatName? They won\'t be able to send you messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockUser();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  /// Block the user
  Future<void> _blockUser() async {
    if (_otherUserId == null) return;

    final result = await ChatService.blockUser(userId: _otherUserId!);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_chatName has been blocked')),
        );
        Navigator.pop(context); // Return to previous screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to block user')),
        );
      }
    }
  }

  /// Toggle mute notifications for this chat
  bool _isMuted = false;

  void _toggleMuteNotifications() {
    setState(() {
      _isMuted = !_isMuted;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMuted
            ? 'Notifications muted for this chat'
            : 'Notifications enabled for this chat'),
      ),
    );

    // Persist mute state via ChatService
    ChatService.setMuteNotifications(chatId: widget.chatId, muted: _isMuted);
  }

  /// Start a video call with the other user
  void _startVideoCall() {
    if (_otherUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call - user not found')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/video-call',
      arguments: {
        'chatId': widget.chatId,
        'userId': _otherUserId,
        'userName': _chatName,
        'isVideo': true,
      },
    );
  }

  /// Start a voice call with the other user
  void _startVoiceCall() {
    if (_otherUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call - user not found')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/voice-call',
      arguments: {
        'chatId': widget.chatId,
        'userId': _otherUserId,
        'userName': _chatName,
        'isVideo': false,
      },
    );
  }

  /// Show attachment picker bottom sheet
  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia('image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia('video');
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location'),
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Contact'),
              onTap: () {
                Navigator.pop(context);
                _sendContact();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pick and send media (image or video)
  Future<void> _pickMedia(String type) async {
    try {
      final XFile? pickedFile;
      if (type == 'image') {
        pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      } else {
        pickedFile = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 10),
        );
      }

      if (pickedFile != null) {
        setState(() {
          _attachedFiles.add(File(pickedFile!.path));
          _attachedFileNames.add(pickedFile.name);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick $type: $e')),
        );
      }
    }
  }

  /// Take photo with camera
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _attachedFiles.add(File(photo.path));
          _attachedFileNames.add(photo.name);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  /// Pick and send a document
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            setState(() {
              _attachedFiles.add(File(file.path!));
              _attachedFileNames.add(file.name);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick document: $e')),
        );
      }
    }
  }

  /// Remove attached file
  void _removeAttachedFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
      _attachedFileNames.removeAt(index);
    });
  }

  /// Clear all attached files
  void _clearAttachedFiles() {
    setState(() {
      _attachedFiles.clear();
      _attachedFileNames.clear();
    });
  }

  /// Send current location
  Future<void> _sendLocation() async {
    // This would use geolocator package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Send location functionality will be implemented')),
    );
  }

  /// Send a contact
  Future<void> _sendContact() async {
    // This would use contacts_service package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Send contact functionality will be implemented')),
    );
  }

  /// Open file when tapped
  void _openFile(String fileUrl, String fileName, String messageType) {
    if (messageType == 'image') {
      FullscreenPhotoViewer.open(context, fileUrl);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const iconoir.OpenNewWindow(width: 22, height: 22),
              title: Text(context.l10n.translate('chat_open_file')),
              onTap: () {
                Navigator.pop(context);
                _downloadAndOpenFile(fileUrl, fileName);
              },
            ),
            ListTile(
              leading: const iconoir.Download(width: 22, height: 22),
              title: Text(context.l10n.translate('chat_download')),
              onTap: () {
                Navigator.pop(context);
                _downloadFile(fileUrl, fileName);
              },
            ),
            ListTile(
              leading: const iconoir.ShareAndroid(width: 22, height: 22),
              title: Text(context.l10n.translate('share')),
              onTap: () async {
                Navigator.pop(context);
                await SharePlus.instance.share(
                  ShareParams(text: fileUrl, subject: fileName),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Download and open file
  Future<void> _downloadAndOpenFile(String fileUrl, String fileName) async {
    try {
      if (kIsWeb) {
        // On web, use url_launcher to open the file in a new tab
        final uri = Uri.parse(fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, webOnlyWindowName: '_blank');
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Не удалось открыть файл')),
            );
          }
        }
      } else {
        // On mobile/desktop, download and open
        final filePath = await _fileService.downloadToDownloads(
          fileUrl,
          fileName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Файл скачан: $filePath')),
          );
          // Open the file
          await _fileService.openFile(filePath);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при открытии файла: $e')),
        );
      }
    }
  }

  /// Download file only
  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      final filePath = await _fileService.downloadToDownloads(
        fileUrl,
        fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл скачан: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при скачивании файла: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    // Stop typing indicator if active
    _stopMyTyping();

    // Flush any pending mark-as-read before leaving
    _markReadTimer?.cancel();
    _flushMarkRead();

    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _wsSubscription?.cancel();
    _typingTimer?.cancel();
    _highlightTimer?.cancel();

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

  /// Toggle reaction on a message — optimistic update + API call
  void _toggleReaction(String messageId, String emoji) {
    // Optimistic update
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
      debugPrint('PrivateChatScreen: error saving reactions to DB: $e');
    }

    // API call
    _sendReactionToggle(messageId, emoji);
  }

  Future<void> _sendReactionToggle(String messageId, String emoji) async {
    try {
      final res = await ChatService.toggleReaction(
        chatId: widget.chatId,
        messageId: messageId,
        emoji: emoji,
      );
      if (res['success'] != true) {
        debugPrint(
            'PrivateChatScreen: toggleReaction returned success=false for msg=$messageId: ${res['message']}');
      }
    } catch (e) {
      debugPrint('PrivateChatScreen: toggleReaction exception: $e');
    }
  }

  /// Extract date-only from DateTime
  DateTime _dateOnly(DateTime dt) => DateTimeUtils.startOfDay(dt);

  /// Format date label for date separator
  String _formatDateLabel(DateTime dt) =>
      DateTimeUtils.formatDateSeparator(dt, context: context);

  /// Show enhanced context menu on single tap
  void _showContextMenu(Message message, bool isMe, GlobalKey key) {
    debugPrint('DEBUG: _showContextMenu called for message ${message.id}');
    
    // Do not show context menu when clicking exactly on a big animated emoji.
    // The GestureDetector inside _bubbleBuilder handles the animation/tap.
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
      onPin: () {
        // TODO: Pin message
        GlassToastService()
            .show(context, 'Сообщение закреплено', icon: Icons.push_pin);
      },
      onEdit: () {
        setState(() {
          _cancelReply();
          _textController.text = message.content;
          _isEditing = true;
          _editingMessageId = message.id;
          _inputFocusNode.requestFocus();
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
    // Optimistically remove from UI
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });

    // Remove from local database
    try {
      await AppDatabase().deleteMessage(message.id);
    } catch (e) {
      debugPrint('PrivateChatScreen: error deleting from DB: $e');
    }

    // Call server API
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
