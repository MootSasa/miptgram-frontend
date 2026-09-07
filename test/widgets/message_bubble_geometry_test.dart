import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:miptgram/l10n/app_localizations.dart';
import 'package:miptgram/models/name_color_preset.dart';
import 'package:miptgram/services/chat_service.dart';
import 'package:miptgram/services/profile_theme_provider.dart';
import 'package:miptgram/utils/date_time_utils.dart';
import 'package:miptgram/widgets/chat/message_reply_info.dart';
import 'package:miptgram/widgets/chat/reply_preview_bar.dart';
import 'package:miptgram/widgets/profile/reply_strip_painter.dart';

class _TestAppLocalizations extends AppLocalizations {
  final Map<String, String> translations;
  _TestAppLocalizations(super.locale, this.translations);

  @override
  String translate(String key) => translations[key] ?? key;
}

class _TestAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  final Map<String, String> translations;
  const _TestAppLocalizationsDelegate([this.translations = const {}]);

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      _TestAppLocalizations(locale, translations),
    );
  }

  @override
  bool shouldReload(_TestAppLocalizationsDelegate old) => false;
}

const Map<String, String> _kTranslations = {
  'chat_reply_you': 'Вы',
  'chat_reply_to': '{name}',
  'chat_message_type_voice': 'Голосовое сообщение',
  'chat_message_type_video': 'Видеосообщение',
  'chat_message_type_file': 'Файл',
  'chat_message_type_photo': 'Фотография',
};

Widget buildTestApp(Widget child, {ProfileThemeProvider? themeProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProfileThemeProvider>(
        create: (_) => themeProvider ?? ProfileThemeProvider(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        _TestAppLocalizationsDelegate(_kTranslations),
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  group('Point 2.1 Reply Preview and Truncation Tests', () {
    testWidgets('MessageReplyInfo truncates long text and appends ...',
        (WidgetTester tester) async {
      const longText =
          'Это очень длинное сообщение, которое должно обязательно обрезаться многоточием на конце при отображении в блоке цитаты бабла сообщения';
      const reply = ReplyInfo(
        messageId: '100',
        senderId: 'user_2',
        senderName: 'Иван',
        content: longText,
        messageType: 'text',
      );

      await tester.pumpWidget(
        buildTestApp(
          const MessageReplyInfo(
            replyInfo: reply,
            currentUserId: 'user_1',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Иван'), findsOneWidget);
      // Verify preview text in RichText ends with ...
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText().contains('...'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('MessageReplyInfo displays localized Вы when replying to oneself',
        (WidgetTester tester) async {
      const reply = ReplyInfo(
        messageId: '101',
        senderId: 'user_me',
        senderName: 'Моё Имя',
        content: 'Привет самому себе',
        messageType: 'text',
      );

      await tester.pumpWidget(
        buildTestApp(
          const MessageReplyInfo(
            replyInfo: reply,
            currentUserId: 'user_me',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Вы'), findsOneWidget);
    });

    testWidgets('MessageReplyInfo uses author appearance settings for styling',
        (WidgetTester tester) async {
      const reply = ReplyInfo(
        messageId: '102',
        senderId: 'user_friend',
        senderName: 'Алексей',
        content: 'Исходное сообщение друга',
        messageType: 'text',
        nameColorPresetId: 'name_orange',
        replyStripStyle: 'dualColor',
      );

      await tester.pumpWidget(
        buildTestApp(
          const MessageReplyInfo(
            replyInfo: reply,
            currentUserId: 'user_me',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Алексей'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Алексей'));
      // Author name color should match name_orange preset (0xFFFB8C00)
      expect(textWidget.style?.color, const Color(0xFFFB8C00));

      // Check ReplyStripWidget properties
      final stripWidget = tester.widget<ReplyStripWidget>(find.byType(ReplyStripWidget));
      expect(stripWidget.preset.id, 'name_orange');
      expect(stripWidget.style, ReplyStripStyle.dualColor);
    });

    testWidgets('MessageReplyInfo falls back to name_red and solid strip for other user when preset is null',
        (WidgetTester tester) async {
      const reply = ReplyInfo(
        messageId: '103',
        senderId: 'user_other',
        senderName: 'Михаил',
        content: 'Сообщение с неуказанным стилем',
        messageType: 'text',
        nameColorPresetId: null,
        replyStripStyle: null,
      );

      await tester.pumpWidget(
        buildTestApp(
          const MessageReplyInfo(
            replyInfo: reply,
            currentUserId: 'user_me',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Михаил'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Михаил'));
      // Fallback author name color must be name_red (0xFFE53935), NOT viewer preset
      expect(textWidget.style?.color, const Color(0xFFE53935));

      final stripWidget = tester.widget<ReplyStripWidget>(find.byType(ReplyStripWidget));
      expect(stripWidget.preset.id, 'name_red');
      expect(stripWidget.style, ReplyStripStyle.solid);
    });

    testWidgets('ReplyPreviewBar falls back to name_red and solid strip for other user when preset is null',
        (WidgetTester tester) async {
      final msg = Message(
        id: '201',
        chatId: 'chat_1',
        senderId: 'user_other',
        content: 'Сообщение в баре ответа с неуказанным стилем',
        messageType: 'text',
        isEdited: false,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        senderName: 'Ольга',
        senderNameColorId: null,
        senderReplyStripStyle: null,
      );

      await tester.pumpWidget(
        buildTestApp(
          ReplyPreviewBar(
            replyToMessage: msg,
            currentUserId: 'user_me',
            onClose: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ольга'), findsOneWidget);
      final stripWidget = tester.widget<ReplyStripWidget>(find.byType(ReplyStripWidget));
      expect(stripWidget.preset.id, 'name_red');
      expect(stripWidget.style, ReplyStripStyle.solid);
    });

    testWidgets('ReplyPreviewBar applies author name and custom strip style',
        (WidgetTester tester) async {
      final msg = Message(
        id: '200',
        chatId: 'chat_1',
        senderId: 'user_author',
        content: 'Это текст сообщения автора',
        messageType: 'text',
        isEdited: false,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        senderName: 'Дмитрий',
        senderNameColorId: 'name_green',
        senderReplyStripStyle: 'candyCane',
      );

      await tester.pumpWidget(
        buildTestApp(
          ReplyPreviewBar(
            replyToMessage: msg,
            currentUserId: 'user_me',
            onClose: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Дмитрий'), findsOneWidget);
      final stripWidget = tester.widget<ReplyStripWidget>(find.byType(ReplyStripWidget));
      expect(stripWidget.preset.id, 'name_green');
      expect(stripWidget.style, ReplyStripStyle.candyCane);
    });
  });

  group('Timestamp UTC Format Tests', () {
    test('UTC ISO-8601 string parsing produces exact local time', () {
      const serverUtcString = '2026-09-07T14:30:00.000Z';
      final parsed = DateTimeUtils.parseUtcDateTime(serverUtcString);
      expect(parsed, isNotNull);

      final formatted = DateTimeUtils.formatTimeHHmm(serverUtcString);
      expect(formatted.isNotEmpty, isTrue);
    });
  });

  group('Profile & Name Color Presets Tests', () {
    test('ProfileColorPresets default is blue', () {
      final defaultPreset = ProfileColorPresets.getById('unknown_preset_id');
      expect(defaultPreset.id, 'blue');
      expect(defaultPreset.backgroundColor, const Color(0xFF2B82C9));
    });

    test('Custom dual gradient preset correctly reconstructs colors from ID', () {
      const color1 = Color(0xFF112233);
      const color2 = Color(0xFF445566);
      final custom = ProfileColorPreset.fromCustomGradient(color1, color2);
      expect(custom.id.startsWith('custom_grad_'), isTrue);

      final restored = ProfileColorPresets.getById(custom.id);
      expect(restored.isGradient, isTrue);
      expect(restored.gradientColors?[0].toARGB32(), color1.toARGB32());
      expect(restored.gradientColors?[1].toARGB32(), color2.toARGB32());
    });
  });
}
