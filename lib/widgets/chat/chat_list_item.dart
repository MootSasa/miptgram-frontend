import '../../utils/image_utils.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/date_time_utils.dart';
import 'package:flutter/material.dart';

class ChatListItem extends StatelessWidget {
  final String chatName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String avatarUrl;
  final bool isOnline;
  final bool isGroup;
  final int unreadCount;
  final VoidCallback onTap;

  const ChatListItem({
    Key? key,
    required this.chatName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.avatarUrl,
    required this.isOnline,
    required this.isGroup,
    this.unreadCount = 0,
    required this.onTap,
  }) : super(key: key);

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final now = DateTime.now();

    if (DateTimeUtils.isToday(localTime, now: now)) {
      return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    } else if (DateTimeUtils.isYesterday(localTime, now: now)) {
      return 'Yesterday';
    } else {
      return '${localTime.day}/${localTime.month}/${localTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: avatarImageProvider(avatarUrl),
          ),
          if (!isGroup && isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chatName,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: RichText(
              text: EmojiUtils.buildEmojiTextSpan(
                lastMessage,
                style: TextStyle(
                  color: hasUnread ? Colors.grey[800] : Colors.grey[600],
                  fontSize: 14,
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? Theme.of(context).colorScheme.primary : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}