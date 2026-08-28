import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// AppBar с Liquid Glass эффектом и затемнением.
///
/// Используется как `Positioned` виджет в Stack когда Liquid Glass дизайн
/// включён. Glass-панель преломляет контент позади (сообщения),
/// с лёгким затемнением для лучшей читаемости.
///
/// Содержимое AppBar (заголовок, действия) отображается поверх
/// glass-эффекта. Поддерживает необязательный [bottom] виджет (TabBar).
///
/// Окантовка (видимый край glass-формы) убрана за счёт использования
/// [LiquidGlassLayer] + [LiquidGlass.grouped] — форма выходит за пределы
/// видимой области, и Layer обрезает её до своих границ.
class LiquidGlassAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// Виджет заголовка (обычно Row с аватаром и именем)
  final Widget title;

  /// Действия справа (кнопки звонка, меню и т.д.)
  final List<Widget>? actions;

  /// Кнопка «назад»
  final Widget? leading;

  /// Нижний виджет (например, TabBar)
  final PreferredSizeWidget? bottom;

  /// Центрировать ли заголовок по всей ширине AppBar (а не только
  /// в пространстве между leading и actions)
  final bool centerTitle;

  /// Включён ли облегчённый режим (FakeGlass вместо LiquidGlass)
  final bool isLite;

  const LiquidGlassAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.centerTitle = false,
    this.isLite = false,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    final glassSettings = LiquidGlassSettings(
      refractiveIndex: 1.1,
      thickness: 10,
      blur: 12,
      saturation: 1.3,
      lightIntensity: isDark ? 0.5 : 0.8,
      ambientStrength: isDark ? 0.15 : 0.3,
      lightAngle: math.pi / 2,
      glassColor: isDark
          ? const Color.fromARGB(80, 20, 20, 30)
          : const Color.fromARGB(80, 200, 200, 210),
    );

    // Получаем высоту статус-бара для отступа
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final totalHeight = kToolbarHeight + statusBarHeight + bottomHeight;

    // Делаем статус-бар прозрачным чтобы glass-эффект AppBar
    // распространялся на область статус-бара без цветового разрыва
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: SizedBox(
        height: totalHeight,
        // ClipRect обрезает glass-форму по границам AppBar,
        // убирая видимую окантовку по краям
        child: ClipRect(
          child: LiquidGlassLayer(
            settings: glassSettings,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Glass-форма выходит за пределы видимой области
                // (на 40px в каждую сторону), Layer обрезает до своих границ.
                // Таким образом окантовка (рефрактивный край) не видна.
                Positioned(
                  top: -40,
                  left: -40,
                  right: -40,
                  bottom: -40,
                  child: isLite
                      ? FakeGlass.inLayer(
                          shape: const LiquidRoundedSuperellipse(borderRadius: 0),
                          child: Container(
                            // Лёгкое затемнение поверх glass
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        )
                      : LiquidGlass.grouped(
                          clipBehavior: Clip.none,
                          shape: const LiquidRoundedSuperellipse(borderRadius: 0),
                          child: Container(
                            // Лёгкое затемнение поверх glass
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                ),
                // Содержимое AppBar поверх glass
                Positioned(
                  left: 0,
                  right: 0,
                  top: statusBarHeight,
                  height: kToolbarHeight,
                  child: centerTitle
                      // Истинное центрирование: title по центру всего
                      // экрана, leading/actions поверх него
                      ? Stack(
                          children: [
                            Center(child: title),
                            Row(
                              children: [
                                if (leading != null)
                                  leading!
                                else
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () => Navigator.maybePop(context),
                                  ),
                                const Spacer(),
                                if (actions != null) ...actions!,
                              ],
                            ),
                          ],
                        )
                      // Обычная раскладка: title между leading и actions
                      : Row(
                          children: [
                            if (leading != null)
                              leading!
                            else
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.maybePop(context),
                              ),
                            Expanded(child: title),
                            if (actions != null) ...actions!,
                          ],
                        ),
                ),
                // Bottom widget (TabBar) если есть
                if (bottom != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: statusBarHeight + kToolbarHeight,
                    child: bottom!,
                  ),
                // Тонкая тёмная линия снизу для читаемости в светлой теме
                if (!isDark)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 0.5,
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
