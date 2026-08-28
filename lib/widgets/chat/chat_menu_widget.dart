import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Меню чата (три точки)
class ChatMenuWidget extends StatelessWidget {
  final bool isMuted;
  final bool isPrivate;
  final bool isGroup;
  final bool isChannel;
  final VoidCallback onViewProfile;
  final VoidCallback onToggleMute;
  final VoidCallback onAutoDelete;
  final VoidCallback onClearHistory;
  final VoidCallback onDeleteChat;
  final VoidCallback onExportChat;
  final VoidCallback? onShareLink;
  final VoidCallback? onLeaveGroup;
  final VoidCallback onReport;

  const ChatMenuWidget({
    Key? key,
    required this.isMuted,
    this.isPrivate = false,
    this.isGroup = false,
    this.isChannel = false,
    required this.onViewProfile,
    required this.onToggleMute,
    required this.onAutoDelete,
    required this.onClearHistory,
    required this.onDeleteChat,
    required this.onExportChat,
    this.onShareLink,
    this.onLeaveGroup,
    required this.onReport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) => _handleSelection(value, context),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'profile', child: Text(l10n.translate('chat_menu_view_profile'))),
        PopupMenuItem(
          value: 'mute',
          child: Text(isMuted ? l10n.translate('chat_menu_unmute') : l10n.translate('chat_menu_mute')),
        ),
        PopupMenuItem(value: 'auto_delete', child: Text(l10n.translate('chat_menu_auto_delete'))),
        PopupMenuItem(value: 'clear', child: Text(l10n.translate('chat_menu_clear_history'))),
        PopupMenuItem(value: 'export', child: Text(l10n.translate('chat_menu_export'))),
        if (onShareLink != null && (isGroup || isChannel))
          PopupMenuItem(value: 'share_link', child: Text(l10n.translate('chat_menu_share_link'))),
        if (onLeaveGroup != null && (isGroup || isChannel))
          PopupMenuItem(value: 'leave', child: Text(l10n.translate('chat_menu_leave'))),
        PopupMenuItem(value: 'delete', child: Text(l10n.translate('chat_menu_delete_chat'))),
        PopupMenuItem(value: 'report', child: Text(l10n.translate('chat_menu_report'))),
      ],
    );
  }

  void _handleSelection(String value, BuildContext context) {
    switch (value) {
      case 'profile': onViewProfile(); break;
      case 'mute': onToggleMute(); break;
      case 'auto_delete': onAutoDelete(); break;
      case 'clear': onClearHistory(); break;
      case 'export': onExportChat(); break;
      case 'share_link': onShareLink?.call(); break;
      case 'leave': onLeaveGroup?.call(); break;
      case 'delete': onDeleteChat(); break;
      case 'report': onReport(); break;
    }
  }
}

/// Поле поиска в чате — AppBar с полем ввода, навигацией ↑/↓, счётчиком
class ChatSearchBar extends StatefulWidget {
  final Function(String query) onSearch;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;

  const ChatSearchBar({
    Key? key,
    required this.onSearch,
    required this.onPrevious,
    required this.onNext,
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<ChatSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onClose),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.translate('chat_search_hint'),
                border: InputBorder.none,
              ),
              onChanged: widget.onSearch,
            ),
          ),
          if (widget.totalCount > 0)
            Text('${widget.currentIndex + 1}/${widget.totalCount}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: widget.onPrevious),
          IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: widget.onNext),
        ],
      ),
    );
  }
}
