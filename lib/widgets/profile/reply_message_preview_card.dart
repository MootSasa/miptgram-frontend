import 'package:flutter/material.dart';
import '../../models/name_color_preset.dart';
import 'reply_strip_painter.dart';

/// Виджет интерактивной карточки предпросмотра сообщения и ответа
/// для вкладки «Имя» на экране выбора цвета профиля.
class ReplyMessagePreviewCard extends StatelessWidget {
  final NameColorPreset preset;
  final ReplyStripStyle stripStyle;
  final String userName;
  final String? avatarUrl;

  const ReplyMessagePreviewCard({
    Key? key,
    required this.preset,
    required this.stripStyle,
    required this.userName,
    this.avatarUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1721) : const Color(0xFFE3EDF7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Сообщение в чате
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF212D3B) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Имя отправителя
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    color: preset.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: '.SF Pro Text',
                  ),
                  child: Text(userName),
                ),
                const SizedBox(height: 6),

                // Блок цитаты ответа (Reply Quote)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: preset.getOpaqueCardBackgroundColor(isDark),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Акцентная полоса цитирования
                        ReplyStripWidget(
                          preset: preset,
                          style: stripStyle,
                          width: 3.5,
                          borderRadius: 2,
                        ),
                        const SizedBox(width: 8),

                        // Текст цитаты
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: preset.primaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Предложение по дизайну интерфейса в Miptgram 🚀',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1C2530),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Текст ответа
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Цвет имени и стиль полоски цитирования применены успешно!',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '12:45',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
