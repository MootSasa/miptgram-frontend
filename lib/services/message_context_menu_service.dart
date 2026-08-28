import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/chat/message_context_menu.dart';
import '../services/chat_service.dart';

class MessageContextMenuService {
  static final MessageContextMenuService _instance = MessageContextMenuService._internal();
  factory MessageContextMenuService() => _instance;
  MessageContextMenuService._internal();

  bool _isShowing = false;

  void show({
    required BuildContext context,
    required Message message,
    required GlobalKey messageKey,
    required bool isMe,
    required VoidCallback onReply,
    required VoidCallback onPin,
    required VoidCallback onEdit,
    required Function(Message message) onDelete,
    required Function(String messageId, String emoji) onReaction,
  }) {
    if (_isShowing) return;

    final RenderBox? renderBox = messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _isShowing = true;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => MessageContextMenu(
          messageOffset: offset,
          messageSize: size,
          isMe: isMe,
          sendStatus: message.sendStatus,
          onReply: onReply,
          onCopy: () {
            Clipboard.setData(ClipboardData(text: message.content));
          },
          onPin: onPin,
          onEdit: onEdit,
          onDelete: () => onDelete(message),
          onReaction: (emoji) => onReaction(message.id, emoji),
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) {
      _isShowing = false;
    });
  }
}
