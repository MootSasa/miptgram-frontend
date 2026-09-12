import '../../utils/image_utils.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/date_time_utils.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ChatListItem extends StatelessWidget {
  final String chatName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String avatarUrl;
  final bool isOnline;
  final bool isGroup;
  final bool isRoundVideo;
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
    this.isRoundVideo = false,
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
            backgroundColor: const Color(0xFF0088CC),
            backgroundImage: avatarImageProvider(avatarUrl),
            onBackgroundImageError: (_, __) {},
            child: avatarImageProvider(avatarUrl) == null
                ? Text(
                    chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
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
          if (isRoundVideo) ...[
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 11,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: isRoundVideo
                ? Text(
                    (lastMessage.isNotEmpty &&
                            lastMessage != 'Видеосообщение' &&
                            lastMessage != 'Video message')
                        ? lastMessage
                        : (AppLocalizations.of(context)
                                ?.translate('chat_video_note') ??
                            'Video message'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                : RichText(
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