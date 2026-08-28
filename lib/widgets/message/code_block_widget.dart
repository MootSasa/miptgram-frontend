import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/glass_toast_service.dart';
import '../../services/profile_theme_provider.dart';
import '../profile/reply_strip_painter.dart';

// --- НАСТРОЙКИ СТИЛЯ БЛОКА КОДА ---
/// Радиус скругления основного контейнера блока кода.
const double _kCodeBlockBorderRadius = 6.0;
/// Вертикальный внешний отступ блока кода (от текста сообщения).
const double _kCodeBlockVerticalMargin = 4.0;
// ----------------------------------

class CodeBlockWidget extends StatelessWidget {
  final String code;
  final String? language;
  final bool isDark;
  final bool isMe;

  const CodeBlockWidget({
    Key? key,
    required this.code,
    this.language,
    required this.isDark,
    this.isMe = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Retrieve name color preset & strip style from ProfileThemeProvider
    final profileTheme = context.watch<ProfileThemeProvider>();
    final preset = profileTheme.currentNameColorPreset;
    final stripStyle = profileTheme.currentStripStyle;

    final accentColor = preset.primaryColor;
    final cardBgColor = preset.getOpaqueCardBackgroundColor(isDark);

    final codeBgColor = isDark ? const Color(0xFF191F26) : const Color(0xFFF0F4F8);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    // Remove background from syntax highlighting theme to use container background
    final codeTheme = Map<String, TextStyle>.from(
      isDark ? atomOneDarkTheme : atomOneLightTheme,
    );
    if (codeTheme.containsKey('root')) {
      final rootStyle = codeTheme['root']!;
      codeTheme['root'] = rootStyle.copyWith(backgroundColor: Colors.transparent);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: _kCodeBlockVerticalMargin),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(_kCodeBlockBorderRadius),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Accent Bar (ReplyStripWidget)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ReplyStripWidget(
                preset: preset,
                style: stripStyle,
                width: 3.5,
                borderRadius: 2,
              ),
            ),
            const SizedBox(width: 8),
            // Code Content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: codeBgColor,
                  borderRadius: BorderRadius.circular(_kCodeBlockBorderRadius - 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Language
                    if (language != null && language!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                          border: Border(
                            bottom: BorderSide(color: borderColor, width: 0.5),
                          ),
                        ),
                        child: Text(
                          language!.toUpperCase(),
                          style: GoogleFonts.firaCode(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    // Code body with line wrapping
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: HighlightView(
                        code.trim(),
                        language: language ?? 'plaintext',
                        theme: codeTheme,
                        padding: EdgeInsets.zero,
                        textStyle: GoogleFonts.firaCode(
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    // Footer button
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        GlassToastService().show(
                          context, 
                          'Код скопирован в буфер обмена',
                          icon: Icons.copy_all_rounded,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: borderColor, width: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.copy,
                              size: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'КОПИРОВАТЬ КОД',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

