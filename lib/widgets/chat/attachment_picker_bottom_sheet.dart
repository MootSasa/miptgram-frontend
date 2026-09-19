import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
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

class AttachmentPickerResult {
  final AttachmentPickerAction? action;
  final List<File>? files;
  final bool asDocument;
  final bool sendImmediately;

  const AttachmentPickerResult.action(this.action)
      : files = null,
        asDocument = false,
        sendImmediately = false;

  const AttachmentPickerResult.files(
    this.files, {
    this.asDocument = false,
    this.sendImmediately = false,
  }) : action = null;
}

class AttachmentPickerBottomSheet extends StatefulWidget {
  final bool allowPoll;

  const AttachmentPickerBottomSheet({
    Key? key,
    this.allowPoll = true,
  }) : super(key: key);

  static Future<AttachmentPickerResult?> show(
    BuildContext context, {
    bool allowPoll = true,
  }) {
    return showModalBottomSheet<AttachmentPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => AttachmentPickerBottomSheet(
        allowPoll: allowPoll,
      ),
    );
  }

  @override
  State<AttachmentPickerBottomSheet> createState() =>
      _AttachmentPickerBottomSheetState();
}

class _AttachmentPickerBottomSheetState extends State<AttachmentPickerBottomSheet> {
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selectedAssets = [];
  bool _isLoadingAssets = true;
  bool _hasPermission = false;
  bool _sendAsDocument = false;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _loadRecentAssets();
  }

  Future<void> _loadRecentAssets() async {
    // PhotoManager is only supported on mobile/macOS; fallback gracefully elsewhere
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS)) {
      if (mounted) {
        setState(() {
          _isLoadingAssets = false;
          _hasPermission = false;
        });
      }
      return;
    }

    try {
      final PermissionState state = await PhotoManager.requestPermissionExtend();
      if (!mounted) return;

      if (state.hasAccess) {
        final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
          onlyAll: true,
          type: RequestType.common,
        );

        if (paths.isNotEmpty && mounted) {
          final recentAlbum = paths.first;
          final list = await recentAlbum.getAssetListRange(start: 0, end: 80);
          if (mounted) {
            setState(() {
              _assets = list;
              _hasPermission = true;
              _isLoadingAssets = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading recent media: $e');
    }

    if (mounted) {
      setState(() {
        _hasPermission = false;
        _isLoadingAssets = false;
      });
    }
  }

  void _toggleSelection(AssetEntity asset) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        if (_selectedAssets.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 10 items can be selected at once'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedAssets.add(asset);
      }
    });
  }

  Future<void> _onAssetTap(AssetEntity asset) async {
    if (_selectedAssets.isNotEmpty) {
      _toggleSelection(asset);
      return;
    }

    // Single item tapped without selection: open in media editor/preview
    setState(() => _isConverting = true);
    try {
      File? file = await asset.originFile;
      file ??= await asset.file;
      if (file != null && mounted) {
        Navigator.pop(
          context,
          AttachmentPickerResult.files(
            [file],
            asDocument: false,
            sendImmediately: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading asset file: $e');
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  Future<void> _sendSelected() async {
    if (_selectedAssets.isEmpty || _isConverting) return;
    setState(() => _isConverting = true);

    try {
      final List<File> files = [];
      for (final asset in _selectedAssets) {
        File? file = await asset.originFile;
        file ??= await asset.file;
        if (file != null) {
          files.add(file);
        }
      }

      if (mounted && files.isNotEmpty) {
        Navigator.pop(
          context,
          AttachmentPickerResult.files(
            files,
            asDocument: _sendAsDocument,
            sendImmediately: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error preparing files for send: $e');
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1E1E24).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.97);

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.58, 0.94],
      builder: (context, scrollController) {
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
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.8,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Drag Handle Pill
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white30 : Colors.black26,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Top Section Bar: "Недавние" + "Галерея" shortcut
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.translate('chat_recent_photos'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.titleMedium?.color,
                              letterSpacing: -0.2,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(
                                context,
                                const AttachmentPickerResult.action(
                                  AttachmentPickerAction.gallery,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.l10n.translate('chat_gallery'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2AABEE),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: Color(0xFF2AABEE),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Media Grid Section
                    Expanded(
                      child: _buildMediaGrid(scrollController, isDark, theme),
                    ),

                    // Bottom Bar (Action Buttons or Send Bar)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _selectedAssets.isNotEmpty
                          ? _buildSendBar(isDark, theme)
                          : _buildActionsRow(isDark, theme),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaGrid(
    ScrollController scrollController,
    bool isDark,
    ThemeData theme,
  ) {
    if (_isLoadingAssets) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    // If no permission or no media available
    if (!_hasPermission || _assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 32,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.translate('chat_allow_gallery_access'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF2AABEE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () => PhotoManager.openSetting(),
                child: Text(
                  context.l10n.translate('settings'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Grid: Item 0 = Camera tile, Items 1..N = AssetEntity tiles
    final totalCount = _assets.length + 1;

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 1.0,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildCameraTile(isDark);
        }

        final asset = _assets[index - 1];
        final isSelected = _selectedAssets.contains(asset);
        final selectionIndex = _selectedAssets.indexOf(asset) + 1;

        return _buildAssetTile(asset, isSelected, selectionIndex, isDark);
      },
    );
  }

  Widget _buildCameraTile(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF272730) : const Color(0xFFE8EAEE),
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pop(
            context,
            const AttachmentPickerResult.action(AttachmentPickerAction.camera),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5E3A).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: iconoir.Camera(
                  color: Colors.white,
                  width: 22,
                  height: 22,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.translate('chat_camera'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetTile(
    AssetEntity asset,
    bool isSelected,
    int selectionIndex,
    bool isDark,
  ) {
    final isVideo = asset.type == AssetType.video;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail Image
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onAssetTap(asset),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AssetEntityImage(
                  asset,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(240),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: isDark ? Colors.black26 : Colors.black12,
                    child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                  ),
                ),

                // Selected tint overlay & border
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2AABEE).withValues(alpha: 0.22),
                      border: Border.all(
                        color: const Color(0xFF2AABEE),
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),

                // Video duration chip
                if (isVideo)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatDuration(asset.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Selection Badge (Top-right corner hitbox)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleSelection(asset),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF2AABEE)
                        : Colors.black.withValues(alpha: 0.35),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: isSelected
                        ? Text(
                            '$selectionIndex',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(bool isDark, ThemeData theme) {
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
        icon: const iconoir.MediaImage(color: Colors.white, width: 24, height: 24),
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
        icon: const iconoir.Page(color: Colors.white, width: 24, height: 24),
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
        icon: const iconoir.MapPin(color: Colors.white, width: 24, height: 24),
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
        icon: const iconoir.User(color: Colors.white, width: 24, height: 24),
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
        icon: const iconoir.MusicDoubleNote(color: Colors.white, width: 24, height: 24),
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
          icon: const iconoir.StatsUpSquare(color: Colors.white, width: 24, height: 24),
        ),
    ];

    return Container(
      key: const ValueKey('actions_row'),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _AnimatedPickerButton(
                item: item,
                onTap: () => Navigator.pop(
                  context,
                  AttachmentPickerResult.action(item.action),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSendBar(bool isDark, ThemeData theme) {
    final count = _selectedAssets.length;

    return Container(
      key: const ValueKey('send_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22222A) : const Color(0xFFF3F4F7),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // "Без сжатия" toggle
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _sendAsDocument = !_sendAsDocument);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: _sendAsDocument
                        ? const Color(0xFF2AABEE)
                        : Colors.transparent,
                    border: Border.all(
                      color: _sendAsDocument
                          ? const Color(0xFF2AABEE)
                          : (isDark ? Colors.white38 : Colors.black38),
                      width: 1.8,
                    ),
                  ),
                  child: _sendAsDocument
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.translate('chat_send_without_compression'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Selected count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2AABEE).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFF2AABEE),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Send Button
          GestureDetector(
            onTap: _isConverting ? null : _sendSelected,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF38B2FF), Color(0xFF0088EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0088EA).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isConverting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const iconoir.Send(
                        color: Colors.white,
                        width: 22,
                        height: 22,
                      ),
              ),
            ),
          ),
        ],
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: item.gradient,
                boxShadow: [
                  BoxShadow(
                    color: item.gradient.colors.first.withValues(alpha: 0.35),
                    blurRadius: _isPressed ? 6 : 10,
                    offset: Offset(0, _isPressed ? 2 : 4),
                  ),
                ],
              ),
              child: Center(child: item.icon),
            ),
            const SizedBox(height: 6),
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
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
