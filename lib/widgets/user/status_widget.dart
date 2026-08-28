import 'package:flutter/material.dart';

class StatusWidget extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSeen;

  const StatusWidget({
    Key? key,
    required this.isOnline,
    this.lastSeen,
  }) : super(key: key);

  /// Formats the last seen time according to the requirements:
  /// - Less than 1 hour: "был(а) X минут назад"
  /// - 1-24 hours: "был(а) X часов назад"
  /// - Yesterday (by calendar): "был(а) вчера"
  /// - Older: "был(а) давно"
  String _getLastSeenText() {
    if (!isOnline && lastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(lastSeen!);
      
      // Check if it was yesterday by calendar
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastSeenDay = DateTime(lastSeen!.year, lastSeen!.month, lastSeen!.day);
      
      // If it was yesterday by calendar
      if (lastSeenDay == yesterday) {
        return 'был(а) вчера';
      }
      
      // If less than 1 hour
      if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        // Handle Russian plural forms
        final minutesText = _getMinutesText(minutes);
        return 'был(а) $minutes $minutesText назад';
      }
      
      // If less than 24 hours (but not yesterday by calendar)
      if (difference.inHours < 24) {
        final hours = difference.inHours;
        // Handle Russian plural forms
        final hoursText = _getHoursText(hours);
        return 'был(а) $hours $hoursText назад';
      }
      
      // If it was today but more than 24 hours ago (edge case for late hours)
      if (lastSeenDay == today) {
        final hours = difference.inHours;
        final hoursText = _getHoursText(hours);
        return 'был(а) $hours $hoursText назад';
      }
      
      // Older than yesterday
      return 'был(а) давно';
    }
    return '';
  }

  /// Returns the correct Russian plural form for minutes
  String _getMinutesText(int minutes) {
    final lastDigit = minutes % 10;
    final lastTwoDigits = minutes % 100;
    
    if (lastTwoDigits >= 11 && lastTwoDigits <= 19) {
      return 'минут';
    }
    if (lastDigit == 1) {
      return 'минуту';
    }
    if (lastDigit >= 2 && lastDigit <= 4) {
      return 'минуты';
    }
    return 'минут';
  }

  /// Returns the correct Russian plural form for hours
  String _getHoursText(int hours) {
    final lastDigit = hours % 10;
    final lastTwoDigits = hours % 100;
    
    if (lastTwoDigits >= 11 && lastTwoDigits <= 19) {
      return 'часов';
    }
    if (lastDigit == 1) {
      return 'час';
    }
    if (lastDigit >= 2 && lastDigit <= 4) {
      return 'часа';
    }
    return 'часов';
  }

  @override
  Widget build(BuildContext context) {
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
          isOnline ? 'в сети' : _getLastSeenText(),
          style: TextStyle(
            fontSize: 12,
            color: isOnline ? Colors.green : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
