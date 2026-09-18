import 'dart:ui';
import 'package:flutter/material.dart';
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

class AttachmentPickerBottomSheet extends StatelessWidget {
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
      builder: (ctx) => AttachmentPickerBottomSheet(
        allowPoll: allowPoll,
        onAction: (action) => Navigator.pop(ctx, action),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1E1E24).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.95);

    final items = [
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
      if (allowPoll)
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
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
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
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Grid of circular buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final displayLabel = item.label.isNotEmpty && item.label != item.action.name
                          ? item.label
                          : item.fallbackLabel;

                      return InkWell(
                        onTap: () => onAction(item.action),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
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
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(child: item.icon),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              displayLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
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
