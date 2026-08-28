import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:motor/motor.dart';

import '../../utils/haptic_utils.dart';

/// Создаёт матрицу jelly-трансформации на основе скорости для органичного
/// эффекта сжатия и растяжения.
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

/// Описание вкладки в нижнем баре.
class LiquidGlassBottomBarTab {
  const LiquidGlassBottomBarTab({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// Плавающий нижний бар с Liquid Glass эффектом, реализованный по примеру
/// из liquid_glass_renderer.
///
/// Использует [LiquidGlassLayer] + [LiquidGlassBlendGroup] +
/// [LiquidGlass.grouped] для основного бара, и скользящий glass-индикатор
/// с пружинными анимациями через [motor].
class LiquidGlassBottomBar extends StatefulWidget {
  const LiquidGlassBottomBar({
    Key? key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.onAddTap,
    this.spacing = 8,
    this.horizontalPadding = 20,
    this.bottomPadding = 20,
    this.barHeight = 64,
    this.glassSettings,
    this.isLite = false,
  }) : super(key: key);

  /// Индекс активной вкладки
  final int selectedIndex;

  /// Коллбэк при выборе вкладки
  final ValueChanged<int> onTabSelected;

  /// Коллбэк при нажатии кнопки "+" (добавить)
  final VoidCallback? onAddTap;

  final double spacing;
  final double horizontalPadding;
  final double bottomPadding;
  final double barHeight;
  final LiquidGlassSettings? glassSettings;

  /// Включён ли облегчённый режим (FakeGlass вместо LiquidGlass)
  final bool isLite;

  @override
  State<LiquidGlassBottomBar> createState() => _LiquidGlassBottomBarState();
}

class _LiquidGlassBottomBarState extends State<LiquidGlassBottomBar> {
  static const _tabs = [
    LiquidGlassBottomBarTab(label: 'Настройки', icon: Icons.settings),
    LiquidGlassBottomBarTab(label: 'Чаты', icon: Icons.chat),
    LiquidGlassBottomBarTab(label: 'Поиск', icon: Icons.search),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final theme = Theme.of(context);

    final glassSettings = widget.glassSettings ??
        LiquidGlassSettings(
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

    return LiquidGlassLayer(
      settings: glassSettings,
      child: LiquidGlassBlendGroup(
        blend: 10,
        child: Padding(
          padding: EdgeInsets.only(
            left: widget.horizontalPadding,
            right: widget.horizontalPadding,
            bottom: widget.bottomPadding,
            top: widget.bottomPadding,
          ),
          child: Row(
            spacing: widget.spacing,
            children: [
              // Основной бар с вкладками (занимает всё свободное пространство)
              Expanded(
                child: _TabIndicator(
                  tabIndex: widget.selectedIndex,
                  tabCount: _tabs.length,
                  onTabChanged: widget.onTabSelected,
                  child: widget.isLite
                      ? FakeGlass.inLayer(
                          shape: const LiquidRoundedSuperellipse(borderRadius: 32),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            height: widget.barHeight,
                            decoration: isDark
                                ? null
                                : BoxDecoration(
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      width: 0.5,
                                    ),
                                  ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (var i = 0; i < _tabs.length; i++)
                                  Expanded(
                                    child: _BottomBarTab(
                                      tab: _tabs[i],
                                      selected: widget.selectedIndex == i,
                                      onTap: () {
                                        HapticUtils.selection();
                                        widget.onTabSelected(i);
                                      },
                                      isDark: isDark,
                                      theme: theme,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : LiquidGlass.grouped(
                          clipBehavior: Clip.none,
                          shape: const LiquidRoundedSuperellipse(borderRadius: 32),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            height: widget.barHeight,
                            decoration: isDark
                                ? null
                                : BoxDecoration(
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      width: 0.5,
                                    ),
                                  ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (var i = 0; i < _tabs.length; i++)
                                  Expanded(
                                    child: _BottomBarTab(
                                      tab: _tabs[i],
                                      selected: widget.selectedIndex == i,
                                      onTap: () {
                                        HapticUtils.selection();
                                        widget.onTabSelected(i);
                                      },
                                      isDark: isDark,
                                      theme: theme,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              // Кнопка "+" — как в примере LiquidOval + LiquidStretch
              if (widget.onAddTap != null)
                if (widget.isLite)
                  FakeGlass.inLayer(
                    shape: const LiquidOval(),
                    child: GlassGlow(
                      child: GestureDetector(
                        onTap: widget.onAddTap,
                        child: Container(
                          height: widget.barHeight,
                          width: widget.barHeight,
                          decoration: isDark
                              ? null
                              : BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    width: 0.5,
                                  ),
                                ),
                          child: Center(
                            child: Icon(
                              Icons.add,
                              size: 28,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  LiquidStretch(
                    child: LiquidGlass.grouped(
                      shape: const LiquidOval(),
                      child: GlassGlow(
                        child: GestureDetector(
                          onTap: widget.onAddTap,
                          child: Container(
                            height: widget.barHeight,
                            width: widget.barHeight,
                            decoration: isDark
                                ? null
                                : BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      width: 0.5,
                                    ),
                                  ),
                            child: Center(
                              child: Icon(
                                Icons.add,
                                size: 28,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка вкладки в нижнем баре с иконкой и подписью.
class _BottomBarTab extends StatelessWidget {
  const _BottomBarTab({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.isDark,
    required this.theme,
  });

  final LiquidGlassBottomBarTab tab;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? theme.colorScheme.primary
        : (isDark ? Colors.white54 : Colors.black54);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: tab.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  selected ? (tab.selectedIcon ?? tab.icon) : tab.icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Скользящий glass-индикатор с пружинными анимациями и поддержкой перетаскивания.
/// Реализован по примеру _TabIndicator из liquid_glass_renderer.
class _TabIndicator extends StatefulWidget {
  const _TabIndicator({
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
  State<_TabIndicator> createState() => _TabIndicatorState();
}

class _TabIndicatorState extends State<_TabIndicator>
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
  void didUpdateWidget(covariant _TabIndicator oldWidget) {
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
                    _IndicatorTransform(
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
                    _IndicatorTransform(
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

/// Трансформация индикатора — позиционирование + jelly-эффект на основе скорости.
class _IndicatorTransform extends StatelessWidget {
  const _IndicatorTransform({
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
