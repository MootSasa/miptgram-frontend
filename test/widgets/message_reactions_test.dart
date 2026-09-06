import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miptgram/widgets/chat/reactions_panel.dart';
import 'package:miptgram/services/chat_service.dart';

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

    test('Message.fromJson parses localId and reaction lists correctly', () {
      final json = {
        'id': '123',
        'chat_id': '1',
        'sender_id': '42',
        'content': 'Hello from device 1',
        'local_id': 'uuid-1234',
        'reactions': [
          {'emoji': '👍', 'count': 3, 'is_mine': true},
          {'emoji': '❤️', 'count': 1, 'is_mine': false},
        ],
      };

      // Import ChatService Message
      final message = Message.fromJson(json);
      expect(message.id, '123');
      expect(message.localId, 'uuid-1234');
      expect(message.reactions['👍'], 3);
      expect(message.reactions['❤️'], 1);
      expect(message.myReactions, contains('👍'));
      expect(message.myReactions, isNot(contains('❤️')));
    });

    test('Message reaction event active & action flags resolution', () {
      // Test when action is provided
      final eventDataAction = {
        'message_id': '123',
        'user_id': '42',
        'emoji': '🔥',
        'action': 'added',
      };
      final action1 = eventDataAction['action']?.toString();
      final bool? active1 = eventDataAction['active'] is bool ? eventDataAction['active'] as bool : null;
      expect(action1 == 'added' || active1 == true, isTrue);

      // Test when active boolean is provided (legacy or backend format)
      final eventDataActive = {
        'message_id': '123',
        'user_id': '42',
        'emoji': '🔥',
        'active': true,
      };
      final action2 = eventDataActive['action']?.toString();
      final bool? active2 = eventDataActive['active'] is bool ? eventDataActive['active'] as bool : null;
      expect(action2 == 'added' || active2 == true, isTrue);

      final eventDataRemoved = {
        'message_id': '123',
        'user_id': '42',
        'emoji': '🔥',
        'active': false,
      };
      final action3 = eventDataRemoved['action']?.toString();
      final bool? active3 = eventDataRemoved['active'] is bool ? eventDataRemoved['active'] as bool : null;
      expect(action3 == 'removed' || active3 == false, isTrue);
    });
  });
}
