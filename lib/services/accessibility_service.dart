import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Service for managing accessibility features including screen reader support,
/// font scaling, color contrast, and keyboard navigation.
class AccessibilityService {
  AccessibilityService._();

  static final AccessibilityService _instance = AccessibilityService._();
  factory AccessibilityService() => _instance;

  /// Gets the current system text scale factor, respecting user preferences.
  /// Returns a value clamped between 0.5 and 3.0 for reasonable bounds.
  double getTextScaleFactor(BuildContext context) {
    final double scale = MediaQuery.of(context).textScaler.scale(1.0);
    return scale.clamp(0.5, 3.0);
  }

  /// Returns a scaled font size based on the system text scale factor.
  /// [baseSize] is the default font size in logical pixels.
  double scaleFontSize(BuildContext context, double baseSize) {
    return baseSize * getTextScaleFactor(context);
  }

  /// Calculates the contrast ratio between two colors according to WCAG formula.
  /// Returns a value between 1 (no contrast) and 21 (maximum contrast).
  static double calculateContrastRatio(Color foreground, Color background) {
    final double fgLuminance = _getLuminance(foreground);
    final double bgLuminance = _getLuminance(background);
    final double lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final double darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Checks if the color contrast meets WCAG AA or AAA standards for normal text.
  /// [isLargeText] indicates if text is large (18pt+ or 14pt+ bold).
  bool meetsContrastStandard(
      Color foreground, Color background, {bool isLargeText = false}) {
    final double ratio = calculateContrastRatio(foreground, background);
    if (isLargeText) {
      return ratio >= 3.0; // AA for large text
    } else {
      return ratio >= 4.5; // AA for normal text
    }
  }

  /// Adjusts a color to meet minimum contrast ratio against a background.
  /// Returns a new color that meets [minRatio] (default 4.5 for AA).
  Color ensureContrast(
      Color color, Color background, {double minRatio = 4.5}) {
    double ratio = calculateContrastRatio(color, background);
    if (ratio >= minRatio) return color;

    // If contrast is insufficient, adjust towards black or white
    final bool isDark = _getLuminance(background) < 0.5;
    final Color target = isDark ? Colors.white : Colors.black;

    // Binary search for optimal adjustment
    double low = 0.0;
    double high = 1.0;
    for (int i = 0; i < 10; i++) {
      double mid = (low + high) / 2;
      Color adjusted = Color.lerp(color, target, mid)!;
      double newRatio = calculateContrastRatio(adjusted, background);
      if (newRatio >= minRatio) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return Color.lerp(color, target, high)!;
  }

  /// Announces a string to screen readers (TalkBack, VoiceOver, etc.).
  /// Use for live region updates like toast messages or dynamic content changes.
  ///
  /// Prefer using [sendAnnouncement] for multi-window support.
  @Deprecated('Use sendAnnouncement instead. This API is incompatible with multiple windows.')
  void announce(String message) {
    sendAnnouncement(message);
  }

  /// Announces a string to screen readers with optional assertiveness.
  /// This is the preferred method for multi-window support.
  /// [assertive] defaults to false (polite announcement).
  void sendAnnouncement(String message, {bool assertive = false}) {
    SemanticsService.sendAnnouncement(
      WidgetsBinding.instance.platformDispatcher.views.first,
      message,
      TextDirection.ltr,
      assertiveness: assertive
          ? Assertiveness.assertive
          : Assertiveness.polite,
    );
  }
}

/// Manages keyboard navigation focus for a group of focusable widgets.
/// Provides methods to move focus to next/previous element.
class FocusManager {
    final List<FocusNode> _focusNodes = [];
    int _currentIndex = -1;

    void add(FocusNode node) {
      _focusNodes.add(node);
      if (_focusNodes.length == 1) {
        _currentIndex = 0;
      }
    }

    void remove(FocusNode node) {
      final index = _focusNodes.indexOf(node);
      if (index != -1) {
        _focusNodes.removeAt(index);
        if (_currentIndex >= index) {
          _currentIndex = (_currentIndex - 1).clamp(0, _focusNodes.length - 1);
        }
      }
    }

    void focusNext() {
      if (_focusNodes.isEmpty) return;
      _currentIndex = (_currentIndex + 1) % _focusNodes.length;
      _focusNodes[_currentIndex].requestFocus();
    }

    void focusPrevious() {
      if (_focusNodes.isEmpty) return;
      _currentIndex = (_currentIndex - 1) % _focusNodes.length;
      if (_currentIndex < 0) _currentIndex = _focusNodes.length - 1;
      _focusNodes[_currentIndex].requestFocus();
    }

    void focusFirst() {
      if (_focusNodes.isEmpty) return;
      _currentIndex = 0;
      _focusNodes[_currentIndex].requestFocus();
    }

    void focusLast() {
      if (_focusNodes.isEmpty) return;
      _currentIndex = _focusNodes.length - 1;
      _focusNodes[_currentIndex].requestFocus();
    }

    bool hasFocus(FocusNode node) {
      return _focusNodes[_currentIndex] == node;
    }

    void dispose() {
      for (final node in _focusNodes) {
        node.dispose();
      }
      _focusNodes.clear();
    }
  }

  /// Helper to calculate relative luminance of a color.
  double _getLuminance(Color color) {
    final double r = (color.r * 255.0).round().clamp(0, 255) / 255.0;
    final double g = (color.g * 255.0).round().clamp(0, 255) / 255.0;
    final double b = (color.b * 255.0).round().clamp(0, 255) / 255.0;
  
    final double rs = r <= 0.03928 ? r / 12.92 : math.pow((r + 0.055) / 1.055, 2.4).toDouble();
    final double gs = g <= 0.03928 ? g / 12.92 : math.pow((g + 0.055) / 1.055, 2.4).toDouble();
    final double bs = b <= 0.03928 ? b / 12.92 : math.pow((b + 0.055) / 1.055, 2.4).toDouble();
  
    return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
  }