import 'package:flutter/material.dart';

/// Виджет отображения статуса доставки/прочтения сообщения.
/// ✓ — доставлено на сервер
/// ✓✓ — прочитано получателем
/// Серые — не прочитано, цветные (акцентные) — прочитано
class MessageStatusWidget extends StatelessWidget {
  final bool isRead;
  final bool isOutgoing;
  final Color? accentColor;
  final Color? colorOverride;

  const MessageStatusWidget({
    Key? key,
    required this.isRead,
    required this.isOutgoing,
    this.accentColor,
    this.colorOverride,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOutgoing) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = colorOverride ?? (isRead
        ? (accentColor ?? theme.colorScheme.primary)
        : Colors.grey);

    if (isRead) {
      // ✓✓ — прочитано (две галочки, цветные)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done, size: 16, color: color),
          Transform.translate(
            offset: const Offset(-6, 0),
            child: Icon(Icons.done, size: 16, color: color),
          ),
        ],
      );
    } else {
      // ✓ — доставлено (одна галочка, серая)
      return Icon(Icons.done, size: 16, color: color);
    }
  }
}
