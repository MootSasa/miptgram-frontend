import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../l10n/app_localizations.dart';
import '../../services/liquid_glass_provider.dart';

/// Разделитель «↓ X непрочитанных сообщений» в чате
class UnreadSeparator extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const UnreadSeparator({Key? key, required this.count, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Row(
          children: [
            Expanded(child: Container(height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.3))),
            const SizedBox(width: 8),
            Icon(Icons.arrow_downward, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              l10n.translate('chat_unread_messages').replaceAll('{count}', count.toString()),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.3))),
          ],
        ),
      ),
    );
  }
}

/// Дата-разделитель между днями в чате
class DateSeparator extends StatelessWidget {
  final String dateLabel;

  const DateSeparator({Key? key, required this.dateLabel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.2))),
          const SizedBox(width: 8),
          Text(dateLabel,
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.2))),
        ],
      ),
    );
  }
}

/// FAB кнопка прокрутки вниз с бейджем непрочитанных
class ScrollDownFab extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;
  final bool visible;

  const ScrollDownFab({
    Key? key,
    required this.unreadCount,
    required this.onPressed,
    this.visible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final glassEnabled = context.watch<LiquidGlassProvider>().enabled;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final child = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.keyboard_arrow_down, size: 28),
        if (unreadCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(1.5, 0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: glassEnabled
              ? _buildGlassButton(context, isDark, child)
              : _buildMatteButton(context, isDark, child),
        ),
      ),
    );
  }

  Widget _buildGlassButton(BuildContext context, bool isDark, Widget child) {
    final glassSettings = LiquidGlassSettings(
      refractiveIndex: 1.15,
      thickness: 15,
      blur: 10,
      lightIntensity: isDark ? 0.6 : 0.9,
      ambientStrength: isDark ? 0.2 : 0.4,
      lightAngle: math.pi / 2,
      glassColor: isDark
          ? const Color.fromARGB(60, 40, 40, 50)
          : const Color.fromARGB(70, 255, 255, 255),
    );

    return LiquidGlass.withOwnLayer(
      settings: glassSettings,
      shape: const LiquidOval(),
      child: GlassGlow(
        child: Center(child: child),
      ),
    );
  }

  Widget _buildMatteButton(BuildContext context, bool isDark, Widget child) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.black.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.65),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 0.5,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
