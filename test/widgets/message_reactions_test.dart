import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miptgram/widgets/chat/reactions_panel.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        primaryContainer: const Color(0xFFE8DEF8),
      ),
    ),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('MessageReactionsRow Widget Tests', () {
    testWidgets('Renders reaction badges and counts properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          const MessageReactionsRow(
            reactions: {'👍': 3, '❤️': 1},
            myReactions: {'👍'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('👍'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('Highlights user selected reactions with theme colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          const MessageReactionsRow(
            reactions: {'🔥': 2, '🎉': 5},
            myReactions: {'🔥', '🎉'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animatedContainers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ).toList();

      expect(animatedContainers.length, 2);
      for (final container in animatedContainers) {
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
        expect(decoration.color, const Color(0xFFE8DEF8));
      }
    });

    testWidgets('Non-selected reactions do not have primary border', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          const MessageReactionsRow(
            reactions: {'🔥': 2},
            myReactions: {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('Tapping a badge calls onTap callback with correct emoji', (WidgetTester tester) async {
      String? tappedEmoji;

      await tester.pumpWidget(
        createTestApp(
          MessageReactionsRow(
            reactions: const {'🚀': 1},
            myReactions: const {'🚀'},
            onTap: (emoji) {
              tappedEmoji = emoji;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('🚀'));
      await tester.pumpAndSettle();

      expect(tappedEmoji, '🚀');
    });

    testWidgets('Adding new reaction animates at the leftmost position (index 0)', (WidgetTester tester) async {
      Map<String, int> reactions = {'❤️': 2};
      Set<String> myReactions = {};

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return createTestApp(
              Column(
                children: [
                  MessageReactionsRow(
                    reactions: reactions,
                    myReactions: myReactions,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        reactions = {'🚀': 1, '❤️': 2};
                        myReactions = {'🚀'};
                      });
                    },
                    child: const Text('Add Reaction'),
                  ),
                ],
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('🚀'), findsNothing);

      await tester.tap(find.text('Add Reaction'));
      await tester.pump();
      expect(find.text('🚀'), findsOneWidget);

      final wrapFinder = find.byType(Wrap);
      expect(wrapFinder, findsOneWidget);
      final wrapWidget = tester.widget<Wrap>(wrapFinder);
      expect(wrapWidget.children.length, 2);

      final firstKey = (wrapWidget.children[0] as KeyedSubtree).key as ValueKey<String>;
      final secondKey = (wrapWidget.children[1] as KeyedSubtree).key as ValueKey<String>;

      expect(firstKey.value, '🚀');
      expect(secondKey.value, '❤️');

      await tester.pumpAndSettle();
    });

    testWidgets('Removing reaction collapses and disposes badge', (WidgetTester tester) async {
      Map<String, int> reactions = {'🚀': 1, '❤️': 2};
      Set<String> myReactions = {'🚀'};

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return createTestApp(
              Column(
                children: [
                  MessageReactionsRow(
                    reactions: reactions,
                    myReactions: myReactions,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        reactions = {'❤️': 2};
                        myReactions = {};
                      });
                    },
                    child: const Text('Remove Reaction'),
                  ),
                ],
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🚀'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);

      await tester.tap(find.text('Remove Reaction'));
      await tester.pump();

      await tester.pumpAndSettle();
      expect(find.text('🚀'), findsNothing);
      expect(find.text('❤️'), findsOneWidget);
    });
  });
}
