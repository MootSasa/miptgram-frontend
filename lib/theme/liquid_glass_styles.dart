import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Central repository of Liquid Glass styles and touch physics across Miptgram.
/// Provides tuned iOS-like physical parameters (refraction, optical rim,
/// shadows, touch response) for all floating chrome components.
class LiquidGlassStyles {
  LiquidGlassStyles._();

  // ---------------------------------------------------------------------------
  // Touch physics presets
  // ---------------------------------------------------------------------------
  static const LiquidGlassTouch touchSubtle = LiquidGlassTouch(
    flex: LiquidGlassFlex.subtle(),
  );

  static const LiquidGlassTouch touchPronounced = LiquidGlassTouch(
    flex: LiquidGlassFlex.pronounced(),
  );

  static const LiquidGlassTouch touchDefault = LiquidGlassTouch(
    flex: LiquidGlassFlex(),
  );

  // ---------------------------------------------------------------------------
  // Floating Glass AppBar (Chat header)
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle appBarStyle(bool isDark, {bool isLite = false}) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 27,
        borderType: OpticalBorder(
          borderSaturation: 1.1,
          ambientIntensity: 1.2,
          borderSolidity: 0.1,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark
            ? const Color.fromARGB(35, 30, 30, 42)
            : const Color.fromARGB(45, 255, 255, 255),
        shadow: const LiquidGlassShadow(
          blur: 8.0,
          opacity: 0.12,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.12,
        distortionWidth: 26,
        magnification: 1.0,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Chat Input Field
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle inputStyle(bool isDark, {bool isLite = false}) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 24,
        borderType: OpticalBorder(
          borderSaturation: 1.0,
          ambientIntensity: 1.0,
          borderSolidity: 0.1,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark
            ? const Color.fromARGB(35, 25, 25, 35)
            : const Color.fromARGB(50, 255, 255, 255),
        shadow: const LiquidGlassShadow(
          blur: 6.0,
          opacity: 0.10,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.10,
        distortionWidth: 20,
        magnification: 1.0,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Floating Action Button (Scroll to bottom)
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle fabStyle(bool isDark, {bool isLite = false}) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.squircle(
        cornerRadius: 24,
        borderType: OpticalBorder(
          borderSaturation: 1.2,
          ambientIntensity: 1.3,
          borderSolidity: 0.15,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark
            ? const Color.fromARGB(45, 35, 35, 48)
            : const Color.fromARGB(65, 255, 255, 255),
        shadow: const LiquidGlassShadow(
          blur: 10.0,
          opacity: 0.18,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.15,
        distortionWidth: 22,
        magnification: 1.02,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Reply / Quote Preview Bar
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle replyPreviewStyle(bool isDark, {bool isLite = false}) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 16,
        borderType: OpticalBorder(
          borderSaturation: 1.0,
          ambientIntensity: 1.0,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark
            ? const Color.fromARGB(35, 30, 30, 40)
            : const Color.fromARGB(45, 255, 255, 255),
        shadow: const LiquidGlassShadow(
          blur: 5.0,
          opacity: 0.08,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.08,
        distortionWidth: 16,
        magnification: 1.0,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Chat Context / Header Menu
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle menuStyle(bool isDark, {bool isLite = false}) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 28,
        borderType: OpticalBorder(
          borderSaturation: 1.2,
          ambientIntensity: 1.1,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark
            ? const Color.fromARGB(50, 25, 25, 35)
            : const Color.fromARGB(65, 255, 255, 255),
        shadow: const LiquidGlassShadow(
          blur: 14.0,
          opacity: 0.20,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.10,
        distortionWidth: 20,
        magnification: 1.0,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Read-only system notification bottom bar
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle readOnlyBarStyle(bool isDark, {bool isLite = false}) {
    return inputStyle(isDark, isLite: isLite);
  }

  // ---------------------------------------------------------------------------
  // Filter chips
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle filterChipStyle(
    bool isDark, {
    bool isLite = false,
    bool isSelected = false,
  }) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 18,
        borderType: OpticalBorder(
          borderSaturation: 1.1,
          ambientIntensity: 1.1,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isSelected
            ? const Color(0x660088CC)
            : (isDark
                ? const Color.fromARGB(40, 30, 30, 42)
                : const Color.fromARGB(50, 255, 255, 255)),
        shadow: const LiquidGlassShadow(
          blur: 4.0,
          opacity: 0.08,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.08,
        distortionWidth: 14,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Action Buttons (Round 58x58)
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle profileButtonStyle(bool isDark, {bool isLite = false}) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.roundedRectangle(
        cornerRadius: 29,
        borderType: OpticalBorder(
          borderSaturation: 1.1,
          ambientIntensity: 1.2,
          borderSolidity: 0.12,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark
            ? const Color.fromARGB(40, 30, 30, 42)
            : const Color.fromARGB(55, 255, 255, 255),
        shadow: const LiquidGlassShadow(
          blur: 8.0,
          opacity: 0.12,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.12,
        distortionWidth: 20,
        magnification: 1.0,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Segmented Control (Tabs)
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle segmentedControlStyle(bool isDark, {bool isLite = false}) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 15,
        borderType: OpticalBorder(
          borderSaturation: 1.0,
          ambientIntensity: 1.1,
          borderSolidity: 0.1,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark
            ? const Color.fromARGB(35, 25, 25, 35)
            : const Color.fromARGB(50, 255, 255, 255),
        shadow: const LiquidGlassShadow(
          blur: 6.0,
          opacity: 0.10,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.10,
        distortionWidth: 16,
        magnification: 1.0,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Glass Toast / Floating Notification
  // ---------------------------------------------------------------------------
  static LiquidGlassStyle toastStyle(bool isDark, {bool isLite = false}) {
    return LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 24,
        borderType: OpticalBorder(
          borderSaturation: 1.1,
          ambientIntensity: 1.2,
          borderSolidity: 0.12,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: isDark
            ? const Color.fromARGB(140, 20, 20, 28)
            : const Color.fromARGB(140, 250, 250, 255),
        shadow: const LiquidGlassShadow(
          blur: 16.0,
          opacity: 0.20,
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.12,
        distortionWidth: 24,
        magnification: 1.0,
      ),
      liteGlass: isLite ? LiquidGlassLitePickup.backdrop : null,
    );
  }
}
