import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:miptgram/services/chat_service.dart';
import 'package:miptgram/services/liquid_glass_provider.dart';
import 'package:miptgram/widgets/chat/chat_scaffold.dart';
import 'package:miptgram/widgets/chat/chat_input_bar.dart';
import 'package:miptgram/widgets/chat/chat_messages_list_view.dart';
import 'package:miptgram/l10n/app_localizations.dart';

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
          ChatScaffold(
            appBar: const Text('Test AppBar'),
            floatingActionButton: const Text('Test FAB'),
            body: const Center(child: Text('Test Body Content')),
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
}
