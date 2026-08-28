import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/name_color_preset.dart';
import 'reply_strip_painter.dart';

/// Виджет выбора цвета имени и стиля полоски цитирования.
class NameColorPicker extends StatelessWidget {
  final NameColorPreset selectedPreset;
  final ReplyStripStyle selectedStyle;
  final ValueChanged<NameColorPreset> onPresetSelected;
  final ValueChanged<ReplyStripStyle> onStyleSelected;
  final VoidCallback onPickCustomColor;

  const NameColorPicker({
    Key? key,
    required this.selectedPreset,
    required this.selectedStyle,
    required this.onPresetSelected,
    required this.onStyleSelected,
    required this.onPickCustomColor,
  }) : super(key: key);

  Widget _buildNameColorCircle({
    required NameColorPreset preset,
    required ReplyStripStyle style,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const size = 36.0;
    Widget circleContent;

    final c1 = preset.primaryColor;
    final c2 = preset.effectiveSecondary;
    final c3 = preset.effectiveTertiary;

    switch (style) {
      case ReplyStripStyle.solid:
        circleContent = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c1,
          ),
        );
        break;

      case ReplyStripStyle.dualColor:
      case ReplyStripStyle.segmented:
        circleContent = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [c1, c1, c2, c2],
              stops: const [0.0, 0.5, 0.5, 1.0],
              transform: const GradientRotation(-math.pi / 4),
            ),
          ),
        );
        break;

      case ReplyStripStyle.candyCane:
        circleContent = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [c1, c1, c2, c2],
              stops: const [0.0, 0.5, 0.5, 1.0],
              transform: const GradientRotation(-math.pi / 4),
            ),
          ),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c3,
                border: Border.all(color: Colors.white30, width: 0.5),
              ),
            ),
          ),
        );
        break;
    }

    if (isSelected) {
      return GestureDetector(
        onTap: onTap,
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
          child: circleContent,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: circleContent,
      ),
    );
  }

  Widget _buildCustomColorButton({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const size = 36.0;

    final child = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
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
      ),
      child: const Icon(Icons.colorize, color: Colors.white, size: 18),
    );

    if (isSelected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: size + 6,
          height: size + 6,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.0),
          ),
          child: child,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustomSelected = selectedPreset.id.startsWith('custom_name_');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок "Цвет имени"
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Цвет имени',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6C7F93),
            ),
          ),
        ),

        // Выбор цвета имени (круглые палитры)
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: NameColorPresets.defaults.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index < NameColorPresets.defaults.length) {
                final preset = NameColorPresets.defaults[index];
                final isSelected = selectedPreset.id == preset.id;

                return _buildNameColorCircle(
                  preset: preset,
                  style: selectedStyle,
                  isSelected: isSelected,
                  onTap: () => onPresetSelected(preset),
                );
              }

              return _buildCustomColorButton(
                isSelected: isCustomSelected,
                onTap: onPickCustomColor,
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Заголовок "Стиль полоски"
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Стиль полоски ответа',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6C7F93),
            ),
          ),
        ),

        // Карточки выбора стиля полоски
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ReplyStripStyle.values.map((style) {
              final isSelected = selectedStyle == style;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onStyleSelected(style),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedPreset.primaryColor.withValues(alpha: 0.2)
                          : const Color(0xFF232E3C).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? selectedPreset.primaryColor
                            : Colors.white10,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: ReplyStripWidget(
                        preset: selectedPreset,
                        style: style,
                        width: 5.5,
                        height: 28,
                        borderRadius: 2.5,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
