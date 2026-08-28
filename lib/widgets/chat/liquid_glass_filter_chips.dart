import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:motor/motor.dart';

import '../../utils/haptic_utils.dart';

/// Создаёт матрицу jelly-трансформации (копия из liquid_glass_bottom_bar.dart).
Matrix4 _buildJellyTransform({
  required Offset velocity,
  double maxDistortion = 0.7,
  double velocityScale = 1000.0,
}) {
  final speed = velocity.distance;
  final direction = speed > 0 ? velocity / speed : Offset.zero;
  final distortionFactor =
      (speed / velocityScale).clamp(0.0, 1.0) * maxDistortion;

  if (distortionFactor == 0) {
    return Matrix4.identity();
  }

  final squashX = 1.0 - (direction.dx.abs() * distortionFactor * 0.5);
  final squashY = 1.0 - (direction.dy.abs() * distortionFactor * 0.5);
  final stretchX = 1.0 + (direction.dy.abs() * distortionFactor * 0.3);
  final stretchY = 1.0 + (direction.dx.abs() * distortionFactor * 0.3);

  final scaleX = squashX * stretchX;
  final scaleY = squashY * stretchY;

  return Matrix4.diagonal3Values(scaleX, scaleY, 1.0);
}

/// Фильтры чатов (Все, Личные, Группы, Каналы) с Liquid Glass эффектом.
///
/// Дизайн — точная копия нижнего бара, но уменьшенный:
/// - Та же структура: LiquidGlassLayer + LiquidGlassBlendGroup +
///   LiquidGlass.grouped + скользящий glass-индикатор
/// - Высота 36 (вместо 64), borderRadius 18 (вместо 32)
/// - Те же настройки стекла, пружинные анимации, jelly-эффект
class LiquidGlassFilterChips extends StatefulWidget {
  final bool enabled;
  final List<String> filters;
  final int activeFilter;
  final ValueChanged<int> onFilterSelected;
  final List<int> unreadCounts;

  /// Включён ли облегчённый режим (FakeGlass вместо LiquidGlass)
  final bool isLite;

  const LiquidGlassFilterChips({
    Key? key,
    required this.enabled,
    required this.filters,
    required this.activeFilter,
    required this.onFilterSelected,
    this.unreadCounts = const [],
    this.isLite = false,
  }) : super(key: key);

  @override
  State<LiquidGlassFilterChips> createState() => _LiquidGlassFilterChipsState();
}

class _LiquidGlassFilterChipsState extends State<LiquidGlassFilterChips> {
  @override
  Widget build(BuildContext context) {
    if (widget.enabled) {
      return _buildGlassFilters(context);
    }
    return _buildClassicFilters(context);
  }

  Widget _buildClassicFilters(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final theme = Theme.of(context);

    final bgColor = isDark
        ? const Color(0xFF2C2C2E)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < widget.filters.length; i++)
              Expanded(
                child: _ClassicFilterChip(
                  label: widget.filters[i],
                  unreadCount: i < widget.unreadCounts.length
                      ? widget.unreadCounts[i]
                      : 0,
                  isActive: widget.activeFilter == i,
                  isDark: isDark,
                  theme: theme,
                  onTap: () {
                    HapticUtils.selection();
                    widget.onFilterSelected(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Glass-версия — точная копия структуры нижнего бара.
  /// LiquidGlassLayer → LiquidGlassBlendGroup → Padding →
  /// LiquidGlass.grouped → Container(height: 36) →
  /// _FilterIndicator (скользящий glass-индикатор) → Row с фильтрами.
  Widget _buildGlassFilters(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Те же настройки стекла что и у нижнего бара
    final glassSettings = LiquidGlassSettings(
      refractiveIndex: 1.21,
      thickness: 30,
      blur: 8,
      saturation: 1.5,
      lightIntensity: isDark ? 0.7 : 1.0,
      ambientStrength: isDark ? 0.2 : 0.5,
      lightAngle: math.pi / 2,
      glassColor: isDark
          ? const Color.fromARGB(60, 30, 30, 40)
          : const Color.fromARGB(80, 200, 200, 210),
    );

    // Padding снаружи LiquidGlassLayer чтобы слой стекла
    // покрывал только стеклянную форму, а не область отступов
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: LiquidGlassLayer(
        settings: glassSettings,
        child: LiquidGlassBlendGroup(
          blend: 10,
          child: _FilterIndicator(
            tabIndex: widget.activeFilter,
            tabCount: widget.filters.length,
            onTabChanged: widget.onFilterSelected,
            child: widget.isLite
                ? FakeGlass.inLayer(
                    shape: const LiquidRoundedSuperellipse(borderRadius: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      height: 36,
                      decoration: isDark
                          ? null
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 0.5,
                              ),
                            ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.filters.length; i++)
                            Expanded(
                              child: _GlassFilterChip(
                                label: widget.filters[i],
                                unreadCount: i < widget.unreadCounts.length
                                    ? widget.unreadCounts[i]
                                    : 0,
                                isActive: widget.activeFilter == i,
                                isDark: isDark,
                                theme: theme,
                                onTap: () {
                                  HapticUtils.selection();
                                  widget.onFilterSelected(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                : LiquidGlass.grouped(
                    clipBehavior: Clip.none,
                    shape: const LiquidRoundedSuperellipse(borderRadius: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      height: 36,
                      decoration: isDark
                          ? null
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 0.5,
                              ),
                            ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.filters.length; i++)
                            Expanded(
                              child: _GlassFilterChip(
                                label: widget.filters[i],
                                unreadCount: i < widget.unreadCounts.length
                                    ? widget.unreadCounts[i]
                                    : 0,
                                isActive: widget.activeFilter == i,
                                isDark: isDark,
                                theme: theme,
                                onTap: () {
                                  HapticUtils.selection();
                                  widget.onFilterSelected(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Glass-фильтр (копия _BottomBarTab из liquid_glass_bottom_bar.dart)
// ============================================================

class _GlassFilterChip extends StatelessWidget {
  const _GlassFilterChip({
    required this.label,
    required this.unreadCount,
    required this.isActive,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final int unreadCount;
  final bool isActive;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isActive
        ? theme.colorScheme.primary
        : (isDark ? Colors.white54 : Colors.black54);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isActive ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Classic-фильтр (без glass)
// ============================================================

class _ClassicFilterChip extends StatelessWidget {
  const _ClassicFilterChip({
    required this.label,
    required this.unreadCount,
    required this.isActive,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final int unreadCount;
  final bool isActive;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isActive
        ? theme.colorScheme.primary
        : (isDark ? Colors.white70 : Colors.black54);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Скользящий glass-индикатор (копия _TabIndicator из bottom_bar)
// ============================================================

class _FilterIndicator extends StatefulWidget {
  const _FilterIndicator({
    required this.child,
    required this.tabIndex,
    required this.tabCount,
    required this.onTabChanged,
  });

  final int tabIndex;
  final int tabCount;
  final Widget child;
  final ValueChanged<int> onTabChanged;

  @override
  State<_FilterIndicator> createState() => _FilterIndicatorState();
}

class _FilterIndicatorState extends State<_FilterIndicator>
    with SingleTickerProviderStateMixin {
  bool _isDown = false;
  bool _isDragging = false;

  late double xAlign = _computeXAlignmentForTab(widget.tabIndex);

  double _computeXAlignmentForTab(int tabIndex) {
    final relativeTabIndex =
        (tabIndex / (widget.tabCount - 1)).clamp(0.0, 1.0);
    return (relativeTabIndex * 2) - 1; // от -1 до 1
  }

  @override
  void didUpdateWidget(covariant _FilterIndicator oldWidget) {
    if (oldWidget.tabIndex != widget.tabIndex ||
        oldWidget.tabCount != widget.tabCount) {
      setState(() {
        xAlign = _computeXAlignmentForTab(widget.tabIndex);
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  double _getAlignmentFromGlobalPosition(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(globalPosition);

    final indicatorWidth = 1.0 / widget.tabCount;
    final draggableRange = 1.0 - indicatorWidth;
    final padding = indicatorWidth / 2;

    final rawRelativeX =
        (localPosition.dx / box.size.width).clamp(0.0, 1.0);
    final normalizedX = (rawRelativeX - padding) / draggableRange;

    final adjustedRelativeX = _applyRubberBandResistance(normalizedX);
    return (adjustedRelativeX * 2) - 1;
  }

  double _applyRubberBandResistance(double value) {
    const double resistance = 0.4;
    const double maxOverdrag = 0.3;

    if (value < 0) {
      final overdrag = -value;
      final resistedOverdrag = overdrag * resistance;
      return -resistedOverdrag.clamp(0.0, maxOverdrag);
    } else if (value > 1) {
      final overdrag = value - 1;
      final resistedOverdrag = overdrag * resistance;
      return 1 + resistedOverdrag.clamp(0.0, maxOverdrag);
    } else {
      return value;
    }
  }

  void _onDragDown(DragDownDetails details) {
    setState(() {
      _isDown = true;
      xAlign = _getAlignmentFromGlobalPosition(details.globalPosition);
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      xAlign = _getAlignmentFromGlobalPosition(details.globalPosition);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _isDown = false;
    });

    final box = context.findRenderObject() as RenderBox;
    final currentRelativeX = (xAlign + 1) / 2;
    final tabWidth = 1.0 / widget.tabCount;

    final indicatorWidth = 1.0 / widget.tabCount;
    final draggableRange = 1.0 - indicatorWidth;
    final velocityX =
        (details.velocity.pixelsPerSecond.dx / box.size.width) /
            draggableRange;

    int targetTabIndex;

    if (currentRelativeX < 0) {
      targetTabIndex = 0;
    } else if (currentRelativeX > 1) {
      targetTabIndex = widget.tabCount - 1;
    } else {
      const velocityThreshold = 0.5;
      if (velocityX.abs() > velocityThreshold) {
        final projectedX =
            (currentRelativeX + velocityX * 0.3).clamp(0.0, 1.0);
        targetTabIndex =
            (projectedX / tabWidth).round().clamp(0, widget.tabCount - 1);

        final currentTabIndex =
            (currentRelativeX / tabWidth).round().clamp(0, widget.tabCount - 1);
        if (velocityX > velocityThreshold &&
            targetTabIndex <= currentTabIndex &&
            currentTabIndex < widget.tabCount - 1) {
          targetTabIndex = currentTabIndex + 1;
        } else if (velocityX < -velocityThreshold &&
            targetTabIndex >= currentTabIndex &&
            currentTabIndex > 0) {
          targetTabIndex = currentTabIndex - 1;
        }
      } else {
        targetTabIndex =
            (currentRelativeX / tabWidth).round().clamp(0, widget.tabCount - 1);
      }
    }

    xAlign = _computeXAlignmentForTab(targetTabIndex);

    if (targetTabIndex != widget.tabIndex) {
      widget.onTabChanged(targetTabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final indicatorColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final targetAlignment = _computeXAlignmentForTab(widget.tabIndex);

    return GestureDetector(
      onHorizontalDragDown: _onDragDown,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () => setState(() {
        _isDragging = false;
        _isDown = false;
      }),
      child: VelocityMotionBuilder(
        converter: const SingleMotionConverter(),
        value: xAlign,
        motion: _isDragging
            ? const Motion.interactiveSpring(snapToEnd: true)
            : const Motion.bouncySpring(snapToEnd: true),
        builder: (context, value, velocity, child) {
          final alignment = Alignment(value, 0);
          return SingleMotionBuilder(
            motion: const Motion.snappySpring(
              snapToEnd: true,
              duration: Duration(milliseconds: 300),
            ),
            value: (_isDown ||
                    (alignment.x - targetAlignment).abs() > 0.30)
                ? 1.0
                : 0.0,
            builder: (context, thickness, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Обычный индикатор (цветной, появляется когда glass исчезает)
                  if (thickness < 1)
                    _FilterIndicatorTransform(
                      velocity: velocity,
                      tabCount: widget.tabCount,
                      alignment: alignment,
                      thickness: thickness,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: thickness <= 0.2 ? 1 : 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            borderRadius: BorderRadius.circular(64),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  child!,
                  // Glass-индикатор (появляется при перетаскивании)
                  if (thickness > 0)
                    _FilterIndicatorTransform(
                      velocity: velocity,
                      tabCount: widget.tabCount,
                      alignment: alignment,
                      thickness: thickness,
                      child: LiquidGlass.withOwnLayer(
                        settings: LiquidGlassSettings(
                          visibility: thickness,
                          glassColor: const Color.fromARGB(25, 255, 255, 255),
                          saturation: 1.5,
                          refractiveIndex: 1.15,
                          thickness: 20,
                          lightIntensity: 2,
                          chromaticAberration: 0.5,
                          blur: 0,
                        ),
                        shape: const LiquidRoundedSuperellipse(
                          borderRadius: 64,
                        ),
                        child: const GlassGlow(child: SizedBox.expand()),
                      ),
                    ),
                ],
              );
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// Трансформация индикатора (копия _IndicatorTransform из bottom_bar)
// ============================================================

class _FilterIndicatorTransform extends StatelessWidget {
  const _FilterIndicatorTransform({
    required this.velocity,
    required this.tabCount,
    required this.alignment,
    required this.thickness,
    required this.child,
  });

  final double velocity;
  final int tabCount;
  final Alignment alignment;
  final double thickness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rect = RelativeRect.lerp(
      RelativeRect.fill,
      const RelativeRect.fromLTRB(-14, -14, -14, -14),
      thickness,
    );
    return Positioned.fill(
      left: 4,
      right: 4,
      top: 4,
      bottom: 4,
      child: FractionallySizedBox(
        widthFactor: 1 / tabCount,
        alignment: alignment,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRelativeRect(
              rect: rect!,
              child: SingleMotionBuilder(
                motion: const Motion.bouncySpring(
                  duration: Duration(milliseconds: 600),
                ),
                value: velocity,
                builder: (context, velocity, child) {
                  return Transform(
                    alignment: Alignment.center,
                    transform: _buildJellyTransform(
                      velocity: Offset(velocity, 0),
                      maxDistortion: 0.8,
                      velocityScale: 10,
                    ),
                    child: child,
                  );
                },
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
