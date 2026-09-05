import 'package:flutter_test/flutter_test.dart';
import 'package:miptgram/services/chat_service.dart';

void main() {
  group('System Notifications Message Parsing Tests', () {
    test('Correctly extracts alert lines from security alert payload', () {
      const content = '🔔 Новый вход в аккаунт\n'
          '📱 Устройство: Chrome on Windows\n'
          '💻 ОС: Windows 11\n'
          '🌐 Местоположение: Москва, Россия (127.0.0.1)\n'
          '⏰ Время: 2026-09-03 21:00:00';

      final lines = content.split('\n');
      String device = '';
      String os = '';
      String location = '';
      String timeStr = '';

      for (final line in lines) {
        if (line.contains('📱')) {
          device = line.replaceAll('📱', '').replaceAll('Устройство:', '').replaceAll('Device:', '').trim();
        } else if (line.contains('💻')) {
          os = line.replaceAll('💻', '').replaceAll('ОС:', '').replaceAll('OS:', '').trim();
        } else if (line.contains('🌐')) {
          location = line.replaceAll('🌐', '').replaceAll('Местоположение:', '').replaceAll('Location:', '').replaceAll('Локация:', '').trim();
        } else if (line.contains('⏰')) {
          timeStr = line.replaceAll('⏰', '').replaceAll('Время:', '').replaceAll('Time:', '').trim();
        }
      }

      expect(device, equals('Chrome on Windows'));
      expect(os, equals('Windows 11'));
      expect(location, equals('Москва, Россия (127.0.0.1)'));
      expect(timeStr, equals('2026-09-03 21:00:00'));
    });

    test('Chat with chatType system is recognized correctly', () {
      final chat = Chat(
        id: 'system-chat-1',
        chatType: 'system',
        name: 'Системные уведомления',
        updatedAt: DateTime.now().toIso8601String(),
        isPinned: true,
      );

      expect(chat.chatType, equals('system'));
      expect(chat.isPinned, isTrue);
      expect(chat.name, equals('Системные уведомления'));
    });
  });
}
