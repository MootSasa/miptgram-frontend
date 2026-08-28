import 'package:flutter/material.dart';
import '../../utils/emoji_utils.dart';

/// Панель реакций — появляется при длинном нажатии на сообщение.
class ReactionsPanel extends StatelessWidget {
  final Function(String emoji) onReactionSelected;

  static const _defaultReactions = ['❤️', '👍', '😱', '😂', '😢', '🔥', '👏', '🎉'];

  const ReactionsPanel({Key? key, required this.onReactionSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _defaultReactions.map((emoji) => InkWell(
          onTap: () => onReactionSelected(emoji),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: EmojiUtils.appleEmoji(emoji, size: 22),
          ),
        )).toList(),
      ),
    );
  }
}

/// Отображение реакций под сообщением
class MessageReactionsRow extends StatelessWidget {
  final Map<String, int> reactions; // emoji → count
  final String? myReaction; // emoji I reacted with
  final Function(String emoji)? onTap;

  const MessageReactionsRow({
    Key? key,
    required this.reactions,
    this.myReaction,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: reactions.entries.map((entry) {
        final isMine = entry.key == myReaction;
        return InkWell(
          onTap: () => onTap?.call(entry.key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMine
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: isMine ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmojiUtils.appleEmoji(entry.key, size: 14),
                if (entry.value > 1) ...[
                  const SizedBox(width: 2),
                  Text('${entry.value}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                          color: isMine ? Theme.of(context).colorScheme.primary : Colors.grey[600])),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
