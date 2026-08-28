import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// AppBar с матовым блюр-эффектом (без Liquid Glass).
///
/// Используется в обычном (classic) режиме дизайна для создания
/// эффекта матового стекла на верхней панели. Контент позади
/// частично просматривается через полупрозрачный фон с размытием.
///
/// Содержимое AppBar (заголовок, действия) отображается поверх
/// блюр-эффекта. Поддерживает необязательный [bottom] виджет (TabBar).
class MatteAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// Виджет заголовка (обычно Row с аватаром и именем)
  final Widget title;

  /// Действия справа (кнопки звонка, меню и т.д.)
  final List<Widget>? actions;

  /// Кнопка «назад"
  final Widget? leading;

  /// Нижний виджет (например, TabBar)
  final PreferredSizeWidget? bottom;

  /// Центрировать ли заголовок по всей ширине AppBar
  final bool centerTitle;

  const MatteAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.centerTitle = false,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final totalHeight = kToolbarHeight + statusBarHeight + bottomHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: SizedBox(
        height: totalHeight,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.7),
              child: Stack(
                children: [
                  // Содержимое AppBar поверх блюра
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
      ),
    );
  }
}
