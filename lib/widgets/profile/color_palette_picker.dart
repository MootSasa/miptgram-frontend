import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ios_color_picker/show_ios_color_picker.dart';

import '../../services/profile_theme_provider.dart';
import '../../utils/haptic_utils.dart';

/// Виджет горизонтальной/сеточной палитры круглых цветов профиля по аналогии с Telegram.
class ColorPalettePicker extends StatefulWidget {
  final ProfileColorPreset? selectedPreset;
  final ValueChanged<ProfileColorPreset> onSelect;
  final VoidCallback? onPickCustomColor;

  const ColorPalettePicker({
    Key? key,
    required this.selectedPreset,
    required this.onSelect,
    this.onPickCustomColor,
  }) : super(key: key);

  @override
  State<ColorPalettePicker> createState() => _ColorPalettePickerState();
}

class _ColorPalettePickerState extends State<ColorPalettePicker> {
  final IOSColorPickerController _colorPickerController = IOSColorPickerController();

  @override
  void dispose() {
    _colorPickerController.dispose();
    super.dispose();
  }

  void _openColorPicker() {
    HapticUtils.selection();

    final startingColor = (widget.selectedPreset?.isCustom == true && widget.selectedPreset?.isGradient != true
            ? widget.selectedPreset!.backgroundColor
            : (widget.selectedPreset?.backgroundColor ?? const Color(0xFF2B82C9)))
        .withValues(alpha: 1.0);

    _colorPickerController.showIOSCustomColorPicker(
      context: context,
      startingColor: startingColor,
      onColorChanged: (color) {
        final opaqueColor = color.withValues(alpha: 1.0);
        widget.onSelect(ProfileColorPreset.fromCustomColor(opaqueColor));
      },
    );
  }

  void _openGradientColorPicker() {
    HapticUtils.selection();

    Color color1 = const Color(0xFF5AB6F0);
    Color color2 = const Color(0xFF2575C0);

    if (widget.selectedPreset?.isCustom == true &&
        widget.selectedPreset?.isGradient == true &&
        widget.selectedPreset?.gradientColors != null &&
        widget.selectedPreset!.gradientColors!.length >= 2) {
      color1 = widget.selectedPreset!.gradientColors![0];
      color2 = widget.selectedPreset!.gradientColors![1];
    }

    _showGradientPickerSheet(context, color1, color2);
  }

  void _showGradientPickerSheet(BuildContext context, Color initialColor1, Color initialColor2) {
    Color c1 = initialColor1.withValues(alpha: 1.0);
    Color c2 = initialColor2.withValues(alpha: 1.0);

    // Выбираем пользовательский градиент сразу
    widget.onSelect(ProfileColorPreset.fromCustomGradient(c1, c2));

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2C3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Настройка двухцветного градиента',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Предпросмотр диагонального круга
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [c1, c1, c2, c2],
                        stops: const [0.0, 0.5, 0.5, 1.0],
                        transform: const GradientRotation(-math.pi / 4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Кнопка выбор Цвет 1
                      GestureDetector(
                        onTap: () {
                          HapticUtils.selection();
                          _colorPickerController.showIOSCustomColorPicker(
                            context: context,
                            startingColor: c1,
                            onColorChanged: (newColor) {
                              final opaque = newColor.withValues(alpha: 1.0);
                              setSheetState(() {
                                c1 = opaque;
                              });
                              widget.onSelect(ProfileColorPreset.fromCustomGradient(c1, c2));
                            },
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c1,
                                border: Border.all(color: Colors.white38, width: 2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Первый цвет',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.swap_horiz_rounded, color: Colors.white38, size: 28),
                      // Кнопка выбор Цвет 2
                      GestureDetector(
                        onTap: () {
                          HapticUtils.selection();
                          _colorPickerController.showIOSCustomColorPicker(
                            context: context,
                            startingColor: c2,
                            onColorChanged: (newColor) {
                              final opaque = newColor.withValues(alpha: 1.0);
                              setSheetState(() {
                                c2 = opaque;
                              });
                              widget.onSelect(ProfileColorPreset.fromCustomGradient(c1, c2));
                            },
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c2,
                                border: Border.all(color: Colors.white38, width: 2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Второй цвет',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B82C9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Готово',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ряд 1: Сплошные цвета + кнопка выбора своего цвета
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ProfileColorPresets.row1Solids.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index < ProfileColorPresets.row1Solids.length) {
                final preset = ProfileColorPresets.row1Solids[index];
                return _buildColorCircle(
                  preset: preset,
                  isSelected: widget.selectedPreset?.id == preset.id,
                );
              }
              // Кнопка выбора собственного сплошного цвета
              final isCustomSolidSelected = widget.selectedPreset?.isCustom == true &&
                  widget.selectedPreset?.isGradient != true;
              return _buildCustomColorButton(isSelected: isCustomSolidSelected);
            },
          ),
        ),
        const SizedBox(height: 10),
        // Ряд 2: Диагональные двухцветные полукруги + кнопка выбора своего градиента
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ProfileColorPresets.row2Gradients.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index < ProfileColorPresets.row2Gradients.length) {
                final preset = ProfileColorPresets.row2Gradients[index];
                return _buildColorCircle(
                  preset: preset,
                  isSelected: widget.selectedPreset?.id == preset.id,
                );
              }
              // Кнопка выбора собственного градиента
              final isCustomGradientSelected = widget.selectedPreset?.isCustom == true &&
                  widget.selectedPreset?.isGradient == true;
              return _buildCustomGradientColorButton(isSelected: isCustomGradientSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorCircle({
    required ProfileColorPreset preset,
    required bool isSelected,
  }) {
    const size = 36.0;

    Widget circleContent;

    if (preset.isGradient) {
      final colors = preset.gradientColors!;
      circleContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [colors[0], colors[0], colors[1], colors[1]],
            stops: const [0.0, 0.5, 0.5, 1.0],
            transform: const GradientRotation(-math.pi / 4),
          ),
        ),
      );
    } else {
      circleContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: preset.backgroundColor,
        ),
      );
    }

    if (isSelected) {
      return GestureDetector(
        onTap: () {
          HapticUtils.selection();
          widget.onSelect(preset);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size + 6,
          height: size + 6,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: preset.ringColor,
              width: 2.0,
            ),
          ),
          child: circleContent,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticUtils.selection();
        widget.onSelect(preset);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: circleContent,
      ),
    );
  }

  /// Плашка с иконкой палитры для выбора собственного сплошного цвета
  Widget _buildCustomColorButton({required bool isSelected}) {
    const size = 36.0;

    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSelected && widget.selectedPreset?.isCustom == true
            ? null
            : const SweepGradient(
                colors: [
                  Colors.red,
                  Colors.yellow,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ],
              ),
        color: isSelected && widget.selectedPreset?.isCustom == true
            ? widget.selectedPreset!.backgroundColor
            : null,
      ),
      child: const Center(
        child: Icon(
          Icons.palette_rounded,
          size: 18,
          color: Colors.white,
        ),
      ),
    );

    if (isSelected) {
      return GestureDetector(
        onTap: _openColorPicker,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size + 6,
          height: size + 6,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
          ),
          child: child,
        ),
      );
    }

    return GestureDetector(
      onTap: _openColorPicker,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: child,
      ),
    );
  }

  /// Плашка с иконкой палитры для выбора собственного градиента (2 цвета)
  Widget _buildCustomGradientColorButton({required bool isSelected}) {
    const size = 36.0;

    List<Color> colors = [const Color(0xFF5AB6F0), const Color(0xFF2575C0)];

    if (isSelected &&
        widget.selectedPreset?.isCustom == true &&
        widget.selectedPreset?.isGradient == true &&
        widget.selectedPreset?.gradientColors != null &&
        widget.selectedPreset!.gradientColors!.length >= 2) {
      colors = widget.selectedPreset!.gradientColors!;
    }

    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [colors[0], colors[0], colors[1], colors[1]],
          stops: const [0.0, 0.5, 0.5, 1.0],
          transform: const GradientRotation(-math.pi / 4),
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.palette_rounded,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (isSelected) {
      return GestureDetector(
        onTap: _openGradientColorPicker,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size + 6,
          height: size + 6,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
          ),
          child: child,
        ),
      );
    }

    return GestureDetector(
      onTap: _openGradientColorPicker,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: child,
      ),
    );
  }
}
