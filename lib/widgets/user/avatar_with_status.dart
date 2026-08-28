import 'package:flutter/material.dart';

/// A widget that displays a user avatar with an online status indicator.
/// Shows a blue circle in the bottom-right corner when the user is online.
class AvatarWithStatus extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final bool isOnline;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AvatarWithStatus({
    Key? key,
    required this.avatarUrl,
    required this.name,
    this.radius = 22,
    this.isOnline = false,
    this.backgroundColor,
    this.onTap,
  }) : super(key: key);

  /// Validates and returns a valid avatar URL, or null if invalid
  String? _getValidAvatarUrl() {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    try {
      final uri = Uri.parse(avatarUrl!);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return avatarUrl;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final validUrl = _getValidAvatarUrl();
    final bgColor = backgroundColor ?? const Color(0xFF0088CC);
    
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      backgroundImage: validUrl != null ? NetworkImage(validUrl) : null,
      child: validUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );

    // If online, wrap with stack to show the indicator
    if (isOnline) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: const Color(0xFF0088CC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
