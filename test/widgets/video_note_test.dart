import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:miptgram/services/chat_service.dart';
import 'package:miptgram/services/video_note_recorder_service.dart';
import 'package:miptgram/widgets/chat/liquid_glass_input_field.dart';
import 'package:miptgram/widgets/chat/round_video_recording_overlay.dart';
import 'package:miptgram/widgets/message/message_bubble.dart';
import 'package:miptgram/widgets/message/video_message_widget.dart';
import 'package:miptgram/l10n/app_localizations.dart';

class _TestAppLocalizations extends AppLocalizations {
  final Map<String, String> translations;
  _TestAppLocalizations(Locale locale, this.translations) : super(locale);

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
  Future<AppLocalizations> load(Locale locale) async {
    return _TestAppLocalizations(locale, translations);
  }

  @override
  bool shouldReload(_TestAppLocalizationsDelegate old) => false;
}

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      _TestAppLocalizationsDelegate({
        'chat_video_note': 'Video message',
        'chat_video_note_hold_hint': 'Hold to record video',
        'chat_video_note_swipe_cancel': 'Slide to cancel',
        'chat_video_note_release_cancel': 'Release to cancel',
        'chat_video_note_lock': 'Lock',
        'chat_video_note_too_short': 'Hold to record video. Tap to switch to voice.',
        'chat_video_note_send': 'Send',
        'chat_video_note_discard': 'Discard',
        'chat_video_note_flip_camera': 'Flip camera',
        'chat_video_note_stop': 'Stop',
        'chat_video_note_tap_switch': 'Tap to switch to video',
        'chat_video_note_tap_voice': 'Tap to switch to voice',
        'chat_video_note_permission_denied': 'Camera or microphone access denied',
        'chat_edited': 'edited',
      }),
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoNoteRecorderService Unit Tests', () {
    test('Initial properties are correct', () {
      final service = VideoNoteRecorderService();
      expect(service.isRecording, isFalse);
      expect(service.isInitialized, isFalse);
      expect(service.isFrontCamera, isTrue);
      expect(service.elapsed, Duration.zero);
      expect(service.renderer, isNull);
      expect(service.errorMessage, isNull);
    });

    test('Permission helpers on non-mobile test runner return expected defaults', () async {
      final service = VideoNoteRecorderService();
      // In flutter test environment (Linux/desktop), hasPermissions returns true by default
      final hasPerm = await service.hasPermissions();
      expect(hasPerm, isTrue);

      final permDenied = await service.isPermanentlyDenied();
      expect(permDenied, isFalse);
    });
  });

  group('RoundVideoRecordingOverlay Widget Tests', () {
    testWidgets('Renders BackdropFilter, circular viewfinder, timer, and slide hint',
        (WidgetTester tester) async {
      final recorderService = VideoNoteRecorderService();
      bool cancelled = false;
      bool sent = false;
      bool tooShort = false;

      await tester.pumpWidget(
        createTestApp(
          RoundVideoRecordingOverlay(
            recorderService: recorderService,
            onCancel: () => cancelled = true,
            onSend: (_) => sent = true,
            onTooShort: () => tooShort = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Cinematic backdrop blur
      expect(find.byType(BackdropFilter), findsOneWidget);

      // 2. Circular camera viewfinder
      expect(find.byType(ClipOval), findsAtLeastNWidgets(1));

      // 3. Timer badge (initial 0:00)
      expect(find.text('0:00'), findsOneWidget);

      // 4. Slide to cancel hint
      expect(find.text('Slide to cancel'), findsOneWidget);
      expect(find.byType(iconoir.NavArrowLeft), findsOneWidget);

      // 5. Lock indicator
      expect(find.byType(iconoir.Lock), findsOneWidget);
      expect(find.byType(iconoir.NavArrowUp), findsOneWidget);

      expect(cancelled, isFalse);
      expect(sent, isFalse);
      expect(tooShort, isFalse);
    });

    testWidgets('Swipe up locks recording and reveals hands-free control bar',
        (WidgetTester tester) async {
      final recorderService = VideoNoteRecorderService();
      final overlayKey = GlobalKey();

      await tester.pumpWidget(
        createTestApp(
          RoundVideoRecordingOverlay(
            key: overlayKey,
            recorderService: recorderService,
            onCancel: () {},
            onSend: (_) {},
            onTooShort: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Initially hands-free buttons (Trash, Refresh/Flip, SendSolid) are not shown
      expect(find.byType(iconoir.Trash), findsNothing);
      expect(find.byType(iconoir.Refresh), findsNothing);
      expect(find.byType(iconoir.SendSolid), findsNothing);

      // Simulate dragging up beyond threshold (-75)
      final state = overlayKey.currentState as dynamic;
      state.updatePointerOffset(0.0, -80.0);
      await tester.pump(const Duration(milliseconds: 300));

      // Now hands-free controls are rendered
      expect(find.byType(iconoir.Trash), findsOneWidget);
      expect(find.byType(iconoir.Refresh), findsOneWidget);
      expect(find.byType(iconoir.SendSolid), findsOneWidget);
    });
  });

  group('VideoMessageWidget Tests', () {
    testWidgets('Renders circular container with time & status pill',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          const VideoMessageWidget(
            videoUrl: 'https://example.com/video_note.mp4',
            size: 240.0,
            isMe: true,
            isRead: true,
            sendStatus: 1,
            timeText: '14:22',
          ),
        ),
      );
      await tester.pump();

      // Circular video container with ClipOval
      expect(find.byType(ClipOval), findsOneWidget);

      // Time pill displays time
      expect(find.text('14:22'), findsOneWidget);

      // Outgoing status for read message (DoubleCheck)
      expect(find.byType(iconoir.DoubleCheck), findsOneWidget);
    });
  });

  group('MessageBubble Round Video Integration Tests', () {
    testWidgets('Renders VideoMessageWidget with transparent background for round message',
        (WidgetTester tester) async {
      final roundMessage = Message(
        id: 'msg-round-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        content: 'video_note.mp4',
        messageType: 'round',
        fileUrl: 'https://example.com/video_note.mp4',
        fileName: 'video_note.mp4',
        isRound: true,
        isEdited: false,
        senderName: 'Alice',
        createdAt: '2026-09-12T10:00:00Z',
      );

      await tester.pumpWidget(
        createTestApp(
          MessageBubble(
            message: roundMessage,
            isMe: false,
            currentUserId: 'user-2',
            formatTime: (_) => '10:00',
          ),
        ),
      );
      await tester.pump();

      // Must render VideoMessageWidget
      expect(find.byType(VideoMessageWidget), findsOneWidget);

      // Find Container that wraps the bubbleCore
      final containers = tester.widgetList<Container>(find.byType(Container));
      final bubbleContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color == Colors.transparent,
      );
      expect(bubbleContainer, isNotNull);
    });
  });

  group('LiquidGlassInputField Media Mode Tests', () {
    testWidgets('Shows microphone when empty and toggles to video camera on tap',
        (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        createTestApp(
          LiquidGlassInputField(
            enabled: false,
            controller: controller,
            hintText: 'Message',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially microphone icon is visible
      expect(find.byType(iconoir.MicrophoneSolid), findsOneWidget);
      expect(find.byType(iconoir.VideoCamera), findsNothing);

      // Tap on the media button to toggle
      await tester.tap(find.byType(iconoir.MicrophoneSolid));
      await tester.pumpAndSettle();

      // Now video camera icon is visible
      expect(find.byType(iconoir.VideoCamera), findsOneWidget);
    });
  });
}
