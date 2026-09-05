import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/wallpaper_provider.dart';

/// Unified scaffold for all chat screens (private chat, group chat, channel).
/// Supports custom wallpapers, floating glass AppBar, bottom input bars,
/// and smooth back navigation with keyboard dismissal.
class ChatScaffold extends StatelessWidget {
  final Widget body;
  final Widget? appBar;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final Widget? customBackground;
  final Color? backgroundColor;
  final bool? canPop;
  final void Function(bool didPop, dynamic result)? onPopInvoked;

  const ChatScaffold({
    Key? key,
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.customBackground,
    this.backgroundColor,
    this.canPop,
    this.onPopInvoked,
  }) : super(key: key);

  /// Helper to calculate standard top padding for chat message lists
  /// when a floating glass app bar is positioned over the content.
  static double getTopContentPadding(BuildContext context) {
    return MediaQuery.of(context).padding.top + kToolbarHeight + 16.0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardVisible = bottomInset > 0;
    final defaultCanPop = canPop ?? !isKeyboardVisible;

    return PopScope(
      canPop: defaultCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (isKeyboardVisible) {
            FocusScope.of(context).unfocus();
          }
          if (onPopInvoked != null) {
            onPopInvoked!(didPop, result);
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Wallpaper background layer
            _buildBackground(context),

            // 2. Main content layer
            Positioned.fill(
              child: Column(
                children: [
                  Expanded(child: body),
                  if (bottomBar != null) bottomBar!,
                ],
              ),
            ),

            // 3. Floating AppBar layer
            if (appBar != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: appBar!,
              ),

            // 4. Floating Action Button layer
            if (floatingActionButton != null)
              Positioned(
                right: 16,
                bottom: bottomInset + 80,
                child: floatingActionButton!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    if (customBackground != null) {
      return customBackground!;
    }

    final wallpaperPath = context.watch<WallpaperProvider?>()?.wallpaperPath;
    if (wallpaperPath != null && wallpaperPath.isNotEmpty) {
      final file = File(wallpaperPath);
      if (file.existsSync()) {
        return Positioned.fill(
          child: Image.file(
            file,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }
}
