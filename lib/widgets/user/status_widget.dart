import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/date_time_utils.dart';

class StatusWidget extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSeen;

  const StatusWidget({
    Key? key,
    required this.isOnline,
    this.lastSeen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusText = isOnline
        ? context.l10n.translate('chat_status_online')
        : DateTimeUtils.formatLastSeen(lastSeen, context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? Colors.green : Colors.grey,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 12,
            color: isOnline ? Colors.green : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
