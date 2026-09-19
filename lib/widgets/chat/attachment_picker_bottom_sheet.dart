import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import '../../l10n/app_localizations.dart';

enum AttachmentPickerAction {
  camera,
  gallery,
  file,
  location,
  poll,
  contact,
  music,
}

class AttachmentPickerBottomSheet extends StatefulWidget {
  final bool allowPoll;
  final ValueChanged<AttachmentPickerAction> onAction;

  const AttachmentPickerBottomSheet({
    Key? key,
    this.allowPoll = true,
    required this.onAction,
  }) : super(key: key);

  static Future<AttachmentPickerAction?> show(
    BuildContext context, {
    bool allowPoll = true,
  }) {
    return showModalBottomSheet<AttachmentPickerAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => AttachmentPickerBottomSheet(
        allowPoll: allowPoll,
        onAction: (action) => Navigator.pop(ctx, action),
      ),
    );
  }

  @override
  State<AttachmentPickerBottomSheet> createState() =>
      _AttachmentPickerBottomSheetState();
}

class _AttachmentPickerBottomSheetState extends State<AttachmentPickerBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1C1C22).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.95);

    final items = [
      _PickerItem(
        action: AttachmentPickerAction.gallery,
        label: context.l10n.translate('chat_gallery'),
        fallbackLabel: 'Gallery',
        gradient: const LinearGradient(
          colors: [Color(0xFF33A9FF), Color(0xFF0077E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: const iconoir.MediaImage(color: Colors.white, width: 26, height: 26),
      ),
      _PickerItem(
        action: AttachmentPickerAction.camera,
        label: context.l10n.translate('chat_camera'),
        fallbackLabel: 'Camera',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: const iconoir.Camera(color: Colors.white, width: 26, height: 26),
      ),
      _PickerItem(
        action: AttachmentPickerAction.file,
        label: context.l10n.translate('chat_file'),
        fallbackLabel: 'File',
        gradient: const LinearGradient(
          colors: [Color(0xFF6B72FF), Color(0xFF434EE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: const iconoir.Page(color: Colors.white, width: 26, height: 26),
      ),
      _PickerItem(
        action: AttachmentPickerAction.location,
        label: context.l10n.translate('chat_location'),
        fallbackLabel: 'Location',
        gradient: const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: const iconoir.MapPin(color: Colors.white, width: 26, height: 26),
      ),
      _PickerItem(
        action: AttachmentPickerAction.contact,
        label: context.l10n.translate('chat_contact'),
        fallbackLabel: 'Contact',
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: const iconoir.User(color: Colors.white, width: 26, height: 26),
      ),
      _PickerItem(
        action: AttachmentPickerAction.music,
        label: context.l10n.translate('chat_music'),
        fallbackLabel: 'Music',
        gradient: const LinearGradient(
          colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: const iconoir.MusicDoubleNote(color: Colors.white, width: 26, height: 26),
      ),
      if (widget.allowPoll)
        _PickerItem(
          action: AttachmentPickerAction.poll,
          label: context.l10n.translate('chat_poll'),
          fallbackLabel: 'Poll',
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: const iconoir.StatsUpSquare(color: Colors.white, width: 26, height: 26),
        ),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.8,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // Drag Handle Pill
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 4-Column Responsive Grid with Staggered Entrance Animations
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];

                      // Staggered cascade entrance curve per item
                      final double start = (index * 0.045).clamp(0.0, 0.6);
                      final double end = (start + 0.45).clamp(0.0, 1.0);
                      final itemCurve = CurvedAnimation(
                        parent: _entranceController,
                        curve: Interval(start, end, curve: Curves.easeOutBack),
                      );
                      final fadeCurve = CurvedAnimation(
                        parent: _entranceController,
                        curve: Interval(start, end, curve: Curves.easeOut),
                      );

                      return FadeTransition(
                        opacity: fadeCurve,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.45, end: 1.0).animate(itemCurve),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.35),
                              end: Offset.zero,
                            ).animate(itemCurve),
                            child: _AnimatedPickerButton(
                              item: item,
                              onTap: () => widget.onAction(item.action),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedPickerButton extends StatefulWidget {
  final _PickerItem item;
  final VoidCallback onTap;

  const _AnimatedPickerButton({
    Key? key,
    required this.item,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_AnimatedPickerButton> createState() => _AnimatedPickerButtonState();
}

class _AnimatedPickerButtonState extends State<_AnimatedPickerButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final displayLabel = item.label.isNotEmpty && item.label != item.action.name
        ? item.label
        : item.fallbackLabel;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: item.gradient,
                boxShadow: [
                  BoxShadow(
                    color: item.gradient.colors.first.withValues(alpha: 0.35),
                    blurRadius: _isPressed ? 6 : 12,
                    offset: Offset(0, _isPressed ? 2 : 4),
                  ),
                ],
              ),
              child: Center(child: item.icon),
            ),
            const SizedBox(height: 7),
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerItem {
  final AttachmentPickerAction action;
  final String label;
  final String fallbackLabel;
  final LinearGradient gradient;
  final Widget icon;

  const _PickerItem({
    required this.action,
    required this.label,
    required this.fallbackLabel,
    required this.gradient,
    required this.icon,
  });
}
