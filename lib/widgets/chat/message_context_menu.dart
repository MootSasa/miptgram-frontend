import 'package:flutter/material.dart';
import '../../utils/emoji_utils.dart';
import '../../utils/haptic_utils.dart';
import '../../l10n/app_localizations.dart';

class MessageContextMenu extends StatefulWidget {
  final Offset messageOffset;
  final Size messageSize;
  final bool isMe;
  final int? sendStatus;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String emoji) onReaction;
  final Set<String> selectedEmojis;

  const MessageContextMenu({
    Key? key,
    required this.messageOffset,
    required this.messageSize,
    required this.isMe,
    this.sendStatus,
    required this.onReply,
    required this.onCopy,
    required this.onPin,
    required this.onEdit,
    required this.onDelete,
    required this.onReaction,
    this.selectedEmojis = const {},
  }) : super(key: key);

  @override
  State<MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<MessageContextMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _controller.reverse().then((_) => Navigator.pop(context));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    // Calculate menu position - appear on the LEFT as requested
    const double menuHeight = 280.0;
    
    double top = widget.messageOffset.dy + widget.messageSize.height + 8;
    bool showAbove = false;
    
    if (top + menuHeight > size.height - 50) {
      top = widget.messageOffset.dy - menuHeight - 8;
      showAbove = true;
    }
    
    // Ensure menu stays within vertical bounds
    top = top.clamp(16.0, size.height - menuHeight - 16.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Semi-transparent background
          GestureDetector(
            onTap: _handleDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ),
          // The Menu
          Positioned(
            top: top,
            left: 16,
            child: ScaleTransition(
              scale: _animation,
              alignment: showAbove ? Alignment.bottomLeft : Alignment.topLeft,
              child: Row(
                crossAxisAlignment: showAbove ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _buildEmojiPanel(theme),
                  const SizedBox(width: 8),
                  _buildActionPanel(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPanel(ThemeData theme) {
    final emojis = EmojiUtils.getFrequentEmojis();
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((emoji) {
          final isSelected = widget.selectedEmojis.contains(emoji);
          return InkWell(
            onTap: () {
              HapticUtils.tap();
              widget.onReaction(emoji);
              _handleDismiss();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              padding: const EdgeInsets.all(4),
              decoration: isSelected
                  ? BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    )
                  : null,
              child: Center(
                child: EmojiUtils.appleEmoji(emoji, size: 24),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionPanel(ThemeData theme) {
    final bool isSending = widget.sendStatus == 0;
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionItem(Icons.reply, context.l10n.translate('chat_action_reply'), widget.onReply, theme, enabled: !isSending),
          _buildActionItem(Icons.copy, context.l10n.translate('chat_action_copy'), widget.onCopy, theme, enabled: !isSending),
          _buildActionItem(Icons.push_pin, context.l10n.translate('chat_action_pin'), widget.onPin, theme, enabled: !isSending),
          if (widget.isMe) 
            _buildActionItem(Icons.edit, context.l10n.translate('chat_edit_message'), widget.onEdit, theme, enabled: !isSending),
          const Divider(height: 1),
          _buildActionItem(Icons.delete, context.l10n.translate('chat_action_delete'), widget.onDelete, theme, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap, ThemeData theme, {bool isDestructive = false, bool enabled = true}) {
    final color = isDestructive ? Colors.red : (enabled ? theme.colorScheme.onSurface : theme.disabledColor);
    return InkWell(
      onTap: enabled ? () {
        HapticUtils.tap();
        onTap();
        _handleDismiss();
      } : null,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
