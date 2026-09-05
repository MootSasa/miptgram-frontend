import 'package:flutter_test/flutter_test.dart';
import 'package:miptgram/services/account_manager.dart';
import 'package:miptgram/services/websocket_service.dart';

void main() {
  group('DeviceSession Model Tests', () {
    test('DeviceSession serializes and deserializes GeoIP and metadata correctly', () {
      final now = DateTime.now();
      final session = DeviceSession(
        id: 'session-123',
        deviceId: 'device-abc',
        userId: 'user-xyz',
        deviceName: 'MacBook Pro',
        deviceType: DeviceType.macos,
        os: 'macOS',
        osVersion: '14.5',
        lastActive: now,
        isCurrent: true,
        location: 'Москва, Россия',
        ipAddress: '192.168.1.10',
        city: 'Москва',
        country: 'Россия',
        countryCode: 'RU',
        appVersion: '1.0.0',
      );

      final json = session.toJson();
      expect(json['id'], equals('session-123'));
      expect(json['deviceId'], equals('device-abc'));
      expect(json['userId'], equals('user-xyz'));
      expect(json['deviceName'], equals('MacBook Pro'));
      expect(json['deviceType'], equals(DeviceType.macos.index));
      expect(json['os'], equals('macOS'));
      expect(json['osVersion'], equals('14.5'));
      expect(json['isCurrent'], isTrue);
      expect(json['location'], equals('Москва, Россия'));
      expect(json['ipAddress'], equals('192.168.1.10'));
      expect(json['city'], equals('Москва'));
      expect(json['country'], equals('Россия'));
      expect(json['countryCode'], equals('RU'));
      expect(json['appVersion'], equals('1.0.0'));

      final restored = DeviceSession.fromJson(json);
      expect(restored.id, equals(session.id));
      expect(restored.deviceId, equals(session.deviceId));
      expect(restored.deviceName, equals(session.deviceName));
      expect(restored.deviceType, equals(DeviceType.macos));
      expect(restored.os, equals(session.os));
      expect(restored.osVersion, equals(session.osVersion));
      expect(restored.isCurrent, isTrue);
      expect(restored.location, equals('Москва, Россия'));
      expect(restored.ipAddress, equals('192.168.1.10'));
      expect(restored.city, equals('Москва'));
      expect(restored.country, equals('Россия'));
      expect(restored.countryCode, equals('RU'));
      expect(restored.appVersion, equals('1.0.0'));
    });

    test('DeviceSession copyWith works as expected', () {
      final session = DeviceSession(
        id: 's1',
        deviceId: 'd1',
        userId: 'u1',
        deviceName: 'Pixel 8',
        deviceType: DeviceType.android,
        os: 'Android',
        osVersion: '14',
        lastActive: DateTime.now(),
        isCurrent: false,
      );

      final updated = session.copyWith(
        deviceName: 'My Phone',
        city: 'Санкт-Петербург',
        country: 'Россия',
        ipAddress: '10.0.0.1',
      );

      expect(updated.id, equals('s1'));
      expect(updated.deviceName, equals('My Phone'));
      expect(updated.city, equals('Санкт-Петербург'));
      expect(updated.country, equals('Россия'));
      expect(updated.ipAddress, equals('10.0.0.1'));
      expect(updated.deviceType, equals(DeviceType.android));
    });
  });

  group('WebSocketEvent Session Terminated Tests', () {
    test('parses session_terminated event correctly', () {
      final json = {
        'type': 'session_terminated',
        'data': {
          'device_id': 'device-old',
          'reason': 'Session terminated by user from another device',
        },
        'timestamp': 1712345678,
      };

      final event = WebSocketEvent.fromJson(json);
      expect(event.type, equals(WebSocketEventType.sessionTerminated));
      expect(event.data['device_id'], equals('device-old'));
      expect(event.data['reason'], contains('Session terminated'));
    });
  });
}
