import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/glass_toast_service.dart';
import '../../utils/haptic_utils.dart';

/// Interactive Link Preview Card Widget.
///
/// Supports large media banner layout vs compact side-thumbnail layout.
/// Tapping navigates to the URL externally.
class LinkPreviewCard extends StatelessWidget {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final bool preferLargeMedia;
  final VoidCallback? onRemove;
  final bool isDark;

  const LinkPreviewCard({
    Key? key,
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.preferLargeMedia = false,
    this.onRemove,
    this.isDark = false,
  }) : super(key: key);

  String get _domain {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst(RegExp(r'^www\.'), '').toUpperCase();
    } catch (_) {
      return 'LINK';
    }
  }

  String get _displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.where((s) => s.isNotEmpty).join(' / ');
      return path.isNotEmpty ? path : uri.host;
    } catch (_) {
      return url;
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    HapticUtils.tap();
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        GlassToastService().show(context, 'Не удалось открыть ссылку', icon: Icons.error_outline);
      }
    } catch (e) {
      GlassToastService().show(context, 'Ошибка открытия ссылки', icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final cardBgColor = isDark
        ? Colors.black.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: primaryColor,
            width: 3.5,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: preferLargeMedia && imageUrl != null
              ? _buildLargeLayout(theme, primaryColor)
              : _buildCompactLayout(theme, primaryColor),
        ),
      ),
    );
  }

  Widget _buildLargeLayout(ThemeData theme, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              imageUrl!,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 6),
        ],
        _buildTextInfo(theme, primaryColor),
      ],
    );
  }

  Widget _buildCompactLayout(ThemeData theme, Color primaryColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildTextInfo(theme, primaryColor)),
        if (imageUrl != null) ...[
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              imageUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextInfo(ThemeData theme, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _domain,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}
