import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;

/// Enum representing the possible actions that can be performed on a message.
enum MessageAction {
  edit,
  delete,
  forward,
  reply,
  react,
  pin,
  save,
}

/// A widget that displays a popup menu for message actions.
///
/// This widget shows a button that, when pressed, reveals a menu of actions
/// that can be performed on a message (edit, delete, forward, reply, react, pin, save).
///
/// The [onAction] callback is invoked when an action is selected from the menu.
class MessageActionsWidget extends StatelessWidget {
  /// Callback invoked when an action is selected.
  final void Function(MessageAction action) onAction;

  const MessageActionsWidget({
    Key? key,
    required this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;

    return PopupMenuButton<MessageAction>(
      icon: iconoir.MoreVert(color: iconColor, width: 22, height: 22),
      tooltip: 'Message actions',
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem<MessageAction>(
          value: MessageAction.edit,
          child: ListTile(
            leading: iconoir.EditPencil(color: iconColor, width: 20, height: 20),
            title: const Text('Edit'),
          ),
        ),
        const PopupMenuItem<MessageAction>(
          value: MessageAction.delete,
          child: ListTile(
            leading: iconoir.Trash(color: Colors.redAccent, width: 20, height: 20),
            title: Text('Delete'),
          ),
        ),
        PopupMenuItem<MessageAction>(
          value: MessageAction.forward,
          child: ListTile(
            leading: iconoir.Forward(color: iconColor, width: 20, height: 20),
            title: const Text('Forward'),
          ),
        ),
        PopupMenuItem<MessageAction>(
          value: MessageAction.reply,
          child: ListTile(
            leading: iconoir.Reply(color: iconColor, width: 20, height: 20),
            title: const Text('Reply'),
          ),
        ),
        PopupMenuItem<MessageAction>(
          value: MessageAction.react,
          child: ListTile(
            leading: iconoir.Emoji(color: iconColor, width: 20, height: 20),
            title: const Text('React'),
          ),
        ),
        PopupMenuItem<MessageAction>(
          value: MessageAction.pin,
          child: ListTile(
            leading: iconoir.Pin(color: iconColor, width: 20, height: 20),
            title: const Text('Pin'),
          ),
        ),
        PopupMenuItem<MessageAction>(
          value: MessageAction.save,
          child: ListTile(
            leading: iconoir.FloppyDisk(color: iconColor, width: 20, height: 20),
            title: const Text('Save'),
          ),
        ),
      ],
    );
  }
}