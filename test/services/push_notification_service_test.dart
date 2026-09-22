import 'package:flutter_test/flutter_test.dart';
import 'package:miptgram/services/push_service_detector.dart';
import 'package:miptgram/services/desktop_tray_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Push Service and Notification Tests', () {
    test('PushServiceDetector singleton returns consistent instance', () {
      final detector1 = PushServiceDetector();
      final detector2 = PushServiceDetector();

      expect(identical(detector1, detector2), isTrue);
      expect(detector1.isDetected, isFalse);
      expect(detector1.serviceType, equals(PushServiceType.none));
    });

    test('PushServiceDetector detect on non-Android platform resolves properly', () async {
      final detector = PushServiceDetector();
      final result = await detector.detect();

      expect(detector.isDetected, isTrue);
      // On non-Android platforms, detect returns gms (iOS/macOS) or none (Linux/Windows)
      expect(result, isA<PushServiceType>());
    });

    test('DesktopTrayService singleton returns consistent instance', () {
      final service1 = DesktopTrayService();
      final service2 = DesktopTrayService();

      expect(identical(service1, service2), isTrue);
    });
  });
}
