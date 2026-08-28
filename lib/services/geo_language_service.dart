import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Сервис для определения официального языка страны по IP-адресу.
///
/// Использует API ipwho.is (основной) и ipapi.co (фоллбэк) для геолокации.
/// Маппинг стран → языки основан на официальных/государственных языках.
class GeoLanguageService {
  static const _primaryApiUrl = 'https://ipwho.is/';
  static const _fallbackApiUrl = 'https://ipapi.co/json/';

  /// Маппинг ISO 3166-1 alpha-2 кодов стран → ISO 639-1 код языка
  /// (основной официальный/государственный язык).
  static const _countryToLanguage = <String, String>{
    // Русскоязычные
    'RU': 'ru', 'BY': 'ru', 'KZ': 'ru', 'KG': 'ru',
    // Англоязычные
    'US': 'en', 'GB': 'en', 'AU': 'en', 'CA': 'en',
    'IE': 'en', 'NZ': 'en', 'ZA': 'en', 'IN': 'en',
    'NG': 'en', 'PH': 'en', 'SG': 'en',
    // Испаноязычные
    'ES': 'es', 'MX': 'es', 'AR': 'es', 'CO': 'es',
    'CL': 'es', 'PE': 'es', 'VE': 'es', 'EC': 'es',
    'CU': 'es', 'BO': 'es', 'PY': 'es', 'UY': 'es',
    'PA': 'es', 'GT': 'es', 'HN': 'es', 'SV': 'es',
    'NI': 'es', 'CR': 'es', 'DO': 'es',
    // Франкоязычные
    'FR': 'fr', 'BE': 'fr', 'SN': 'fr', 'CI': 'fr',
    'ML': 'fr', 'NE': 'fr', 'TG': 'fr', 'BJ': 'fr',
    'CF': 'fr', 'GA': 'fr', 'CG': 'fr', 'TD': 'fr',
    'MG': 'fr', 'CM': 'fr', 'BF': 'fr', 'GN': 'fr',
    // Немецкоязычные
    'DE': 'de', 'AT': 'de', 'CH': 'de', 'LI': 'de',
    // Италоязычные
    'IT': 'it', 'SM': 'it',
    // Португалоязычные
    'PT': 'pt', 'BR': 'pt', 'AO': 'pt', 'MZ': 'pt',
    'CV': 'pt', 'GW': 'pt', 'ST': 'pt', 'TL': 'pt',
    // Китайскоязычные
    'CN': 'zh', 'TW': 'zh', 'HK': 'zh',
    // Японскоязычные
    'JP': 'ja',
    // Корейскоязычные
    'KR': 'ko', 'KP': 'ko',
    // Арабскоязычные (не поддерживаем арабский — маппим на en)
    'SA': 'en', 'AE': 'en', 'EG': 'en', 'IQ': 'en',
  };

  /// Полный текст кнопки смены языка на самом предлагаемом языке.
  /// Пользователь должен увидеть текст на своём родном языке,
  /// чтобы понять, что ему предлагается переключиться.
  static const _switchButtonText = <String, String>{
    'en': 'Switch to English?',
    'ru': 'Переключиться на русский?',
    'es': '¿Cambiar a español?',
    'fr': 'Passer en français ?',
    'de': 'Auf Deutsch umschalten?',
    'it': "Passare all'italiano?",
    'pt': 'Mudar para português?',
    'zh': '切换到中文？',
    'ja': '日本語に切り替えますか？',
    'ko': '한국어로 전환하시겠습니까?',
  };

  /// Поддерживаемые приложением языки
  static const supportedLanguages = [
    'en', 'ru', 'es', 'fr', 'de', 'it', 'pt', 'zh', 'ja', 'ko',
  ];

  /// Определяет язык по IP-адресу.
  ///
  /// Возвращает ISO 639-1 код языка или null если:
  /// - не удалось определить страну
  /// - язык страны не поддерживается приложением
  static Future<String?> detectLanguage() async {
    // Пробуем основной API (ipwho.is) — более щедрые лимиты
    try {
      final response = await http.get(
        Uri.parse(_primaryApiUrl),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final success = data['success'];
        // ipwho.is возвращает success: false при ошибке
        if (success == true || success == null) {
          final countryCode = data['country_code'] as String?;
          if (countryCode != null) {
            final language = _countryToLanguage[countryCode];
            if (language != null && supportedLanguages.contains(language)) {
              debugPrint('[GeoLanguage] Detected $language via ipwho.is ($countryCode)');
              return language;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[GeoLanguage] ipwho.is error: $e');
    }

    // Фоллбэк на ipapi.co
    try {
      final response = await http.get(
        Uri.parse(_fallbackApiUrl),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // ipapi.co при RateLimit возвращает {error: true, reason: "RateLimited"}
        if (data['error'] == true) {
          debugPrint('[GeoLanguage] ipapi.co error: ${data['reason']}');
          return null;
        }
        final countryCode = data['country_code'] as String?;
        if (countryCode != null) {
          final language = _countryToLanguage[countryCode];
          if (language != null && supportedLanguages.contains(language)) {
            debugPrint('[GeoLanguage] Detected $language via ipapi.co ($countryCode)');
            return language;
          }
        }
      }
    } catch (e) {
      debugPrint('[GeoLanguage] ipapi.co error: $e');
    }

    return null;
  }

  /// Возвращает полный текст кнопки смены языка на предлагаемом языке.
  ///
  /// Например: 'ru' → 'Переключиться на русский?', 'en' → 'Switch to English?'
  static String? getSwitchButtonText(String languageCode) {
    return _switchButtonText[languageCode];
  }
}
