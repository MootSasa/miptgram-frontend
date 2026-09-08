import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import '../../l10n/app_localizations.dart';
import '../../services/chat_service.dart';
import '../../utils/haptic_utils.dart';

/// Floating Link Preview Configuration Bar above the chat input field.
///
/// Gives the user full Telegram-like control over:
/// 1. Preview position (above or below text)
/// 2. Media size (large banner vs compact thumbnail)
/// 3. Selecting which URL to preview when multiple exist
/// 4. Disabling/removing the preview entirely
class LinkPreviewInputBar extends StatelessWidget {
  final LinkPreviewOptions options;
  final List<String> detectedUrls;
  final ValueChanged<LinkPreviewOptions> onOptionsChanged;
  final VoidCallback onRemove;

  const LinkPreviewInputBar({
    Key? key,
    required this.options,
    required this.detectedUrls,
    required this.onOptionsChanged,
    required this.onRemove,
  }) : super(key: key);

  String _formatUrlDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final activeUrl = options.url ?? (detectedUrls.isNotEmpty ? detectedUrls.first : '');
    final domain = _formatUrlDomain(activeUrl);

    final bgColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.95);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              iconoir.Link(
                color: primaryColor,
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Превью ссылки: $domain',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
              if (detectedUrls.length > 1) ...[
                PopupMenuButton<String>(
                  tooltip: 'Выбрать ссылку',
                  icon: Icon(Icons.arrow_drop_down, color: primaryColor, size: 20),
                  onSelected: (url) {
                    HapticUtils.tap();
                    onOptionsChanged(options.copyWith(url: url));
                  },
                  itemBuilder: (ctx) => detectedUrls.map((u) {
                    return PopupMenuItem<String>(
                      value: u,
                      child: Text(
                        _formatUrlDomain(u),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: u == activeUrl ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: context.l10n.translate('link_preview_remove'),
                onPressed: () {
                  HapticUtils.tap();
                  onRemove();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Position toggle
              _buildOptionChip(
                context: context,
                label: options.showAboveText
                    ? context.l10n.translate('link_preview_above')
                    : context.l10n.translate('link_preview_below'),
                icon: options.showAboveText
                    ? Icons.vertical_align_top
                    : Icons.vertical_align_bottom,
                onTap: () {
                  HapticUtils.tap();
                  onOptionsChanged(
                    options.copyWith(showAboveText: !options.showAboveText),
                  );
                },
                theme: theme,
              ),
              const SizedBox(width: 8),
              // Media size toggle
              _buildOptionChip(
                context: context,
                label: options.preferLargeMedia
                    ? context.l10n.translate('link_preview_large')
                    : context.l10n.translate('link_preview_small'),
                icon: options.preferLargeMedia
                    ? Icons.photo_size_select_actual
                    : Icons.crop_original,
                onTap: () {
                  HapticUtils.tap();
                  onOptionsChanged(
                    options.copyWith(preferLargeMedia: !options.preferLargeMedia),
                  );
                },
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
