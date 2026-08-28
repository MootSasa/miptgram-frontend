import 'package:flutter/material.dart';

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
    return PopupMenuButton<MessageAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Message actions',
      onSelected: onAction,
      itemBuilder: (context) => [
        const PopupMenuItem<MessageAction>(
          value: MessageAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit'),
          ),
        ),
        const PopupMenuItem<MessageAction>(
          value: MessageAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete'),
          ),
        ),
        const PopupMenuItem<MessageAction>(
          value: MessageAction.forward,
          child: ListTile(
            leading: Icon(Icons.forward),
            title: Text('Forward'),
          ),
        ),
        const PopupMenuItem<MessageAction>(
          value: MessageAction.reply,
          child: ListTile(
            leading: Icon(Icons.reply),
            title: Text('Reply'),
          ),
        ),
        const PopupMenuItem<MessageAction>(
          value: MessageAction.react,
          child: ListTile(
            leading: Icon(Icons.mood),
            title: Text('React'),
          ),
        ),
        const PopupMenuItem<MessageAction>(
          value: MessageAction.pin,
          child: ListTile(
            leading: Icon(Icons.push_pin),
            title: Text('Pin'),
          ),
        ),
        const PopupMenuItem<MessageAction>(
          value: MessageAction.save,
          child: ListTile(
            leading: Icon(Icons.save),
            title: Text('Save'),
          ),
        ),
      ],
    );
  }
}