import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:miptgram/services/liquid_glass_provider.dart';
import 'package:miptgram/widgets/chat/chat_scaffold.dart';
import 'package:miptgram/widgets/chat/chat_input_bar.dart';
import 'package:miptgram/widgets/chat/chat_messages_list_view.dart';
import 'package:miptgram/widgets/chat/liquid_glass_input_field.dart';

Widget createTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LiquidGlassProvider()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  group('ChatScaffold Widget Tests', () {
    testWidgets('Renders body, appBar, and floatingActionButton correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ChatScaffold(
            appBar: Text('Test AppBar'),
            floatingActionButton: Text('Test FAB'),
            body: Center(child: Text('Test Body Content')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test AppBar'), findsOneWidget);
      expect(find.text('Test FAB'), findsOneWidget);
      expect(find.text('Test Body Content'), findsOneWidget);
    });
  });

  group('ChatMessagesListView Widget Tests', () {
    testWidgets('Renders loading indicator when isLoading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChatMessagesListView(
            isLoading: true,
            itemCount: 0,
            itemBuilder: (context, index) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Renders empty state when itemCount is 0',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChatMessagesListView(
            isLoading: false,
            itemCount: 0,
            emptyTitle: 'No messages here',
            itemBuilder: (context, index) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No messages here'), findsOneWidget);
    });

    testWidgets('Renders message items when itemCount > 0',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChatMessagesListView(
            isLoading: false,
            itemCount: 3,
            itemBuilder: (context, index) => Text('Message $index'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Message 0'), findsOneWidget);
      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsOneWidget);
    });
  });

  group('ChatInputBar Widget Tests', () {
    testWidgets('Renders input field with hintText', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        createTestApp(
          ChatInputBar(
            controller: controller,
            hintText: 'Custom hint...',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom hint...'), findsOneWidget);
    });

    testWidgets('Renders editing banner and handles onCancelEditing',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      bool cancelled = false;

      await tester.pumpWidget(
        createTestApp(
          ChatInputBar(
            controller: controller,
            isEditing: true,
            editingTitle: 'Editing Message Title',
            onCancelEditing: () {
              cancelled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editing Message Title'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(cancelled, isTrue);
    });
  });

  group('TelegramTextSelectionToolbar Widget Tests', () {
    testWidgets('Toggles between horizontal pill and expanded vertical menu',
        (WidgetTester tester) async {
      final controller = RichTextEditingController(text: 'Hello world');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TelegramTextSelectionToolbar(
                anchors: const TextSelectionToolbarAnchors(
                    primaryAnchor: Offset(100, 100)),
                buttonItems: const [],
                controller: controller,
                onHideToolbar: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // State 1: Horizontal compact pill
      expect(find.text('Вырезать'), findsOneWidget);
      expect(find.text('Цитировать'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.text('Назад'), findsNothing);

      // Tap overflow button
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // State 2: Expanded vertical menu
      expect(find.text('Копировать'), findsOneWidget);
      expect(find.text('Скрытый'), findsOneWidget);
      expect(find.text('Вставить'), findsOneWidget);
      expect(find.text('Жирный'), findsOneWidget);
      expect(find.text('Вставить как обычный текст'), findsOneWidget);
      expect(find.text('Курсив'), findsOneWidget);
      expect(find.text('Подчёркнутый'), findsOneWidget);
      expect(find.text('Назад'), findsOneWidget);

      // Tap "Назад"
      await tester.tap(find.text('Назад'));
      await tester.pumpAndSettle();

      // Returns to horizontal pill
      expect(find.text('Вырезать'), findsOneWidget);
      expect(find.text('Цитировать'), findsOneWidget);
      expect(find.text('Назад'), findsNothing);
    });

    testWidgets(
        'showLinkDialog in edit mode displays Редактировать ссылку and Удалить ссылку',
        (WidgetTester tester) async {
      final controller = RichTextEditingController(text: 'Visit Google site');
      controller.selection =
          const TextSelection(baseOffset: 6, extentOffset: 12);
      controller.applyLinkToSelection('https://google.com');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    controller.selection =
                        const TextSelection(baseOffset: 6, extentOffset: 12);
                    TextFormattingUtils.showLinkDialog(context, controller);
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Редактировать ссылку'), findsOneWidget);
      expect(find.text('Удалить ссылку'), findsOneWidget);
      expect(find.text('https://google.com'), findsOneWidget);

      // Tap "Удалить ссылку"
      await tester.tap(find.text('Удалить ссылку'));
      await tester.pumpAndSettle();

      expect(controller.spans.isEmpty, isTrue);
      expect(controller.text, 'Visit Google site');
    });
  });

  group('LiquidGlassInputField Widget Tests', () {
    testWidgets(
        'Renders TextField directly without SingleChildScrollView and assigns scrollController',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Test message');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        createTestApp(
          LiquidGlassInputField(
            enabled: true,
            controller: controller,
            hintText: 'Type a message...',
            focusNode: focusNode,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.scrollController, isNotNull);
      expect(textField.maxLines, isNull);

      // Verify that TextField is NOT wrapped inside SingleChildScrollView
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );

      // Verify Theme provides textSelectionTheme
      final themeFinder = find.ancestor(
        of: textFieldFinder,
        matching: find.byType(Theme),
      );
      expect(themeFinder, findsWidgets);
      final themeWidget = tester.widget<Theme>(themeFinder.first);
      expect(themeWidget.data.textSelectionTheme.selectionHandleColor, isNotNull);
      expect(themeWidget.data.textSelectionTheme.selectionColor, isNotNull);
    });

    testWidgets(
        'Assigns TelegramTextSelectionControls with TextSelectionHandleControls to TextField',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Hello world');
      await tester.pumpWidget(
        createTestApp(
          LiquidGlassInputField(
            enabled: true,
            controller: controller,
            hintText: 'Type...',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.selectionControls, isA<TextSelectionHandleControls>());
      expect(textField.selectionControls, isA<TelegramTextSelectionControls>());
    });
  });
}
