import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/splash_screen.dart';
import 'services/settings_service.dart';
import 'services/account_manager.dart';
import 'services/liquid_glass_provider.dart';
import 'services/unread_count_provider.dart';
import 'services/deep_link_service.dart';
import 'services/notification_settings_provider.dart';
import 'services/notification_service.dart';
import 'services/push_service_detector.dart';
import 'services/privacy_settings_provider.dart';
import 'services/banking_cards_provider.dart';
import 'services/wallet_security_provider.dart';
import 'services/wallpaper_provider.dart';
import 'services/profile_theme_provider.dart';
import 'utils/emoji_utils.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: main() started');

  // Initialize AppConfig (4-tier dynamic environment configuration)
  await AppConfig.init();

  // Load Apple Emoji font dynamically
  // We don't await it here to not block the splash screen, 
  // but it will apply once loaded.
  EmojiUtils.loadAppleEmojiFont();

  // Detect available push services (GMS/HMS) before Firebase init
  final pushDetector = PushServiceDetector();
  final pushType = await pushDetector.detect();
  debugPrint('Detected push service: $pushType');

  // Initialize Firebase only if GMS is available
  if (pushType == PushServiceType.gms) {
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization skipped: $e');
    }
  } else {
    debugPrint('Firebase skipped: GMS not available (pushType=$pushType)');
  }

  // Initialize services
  await SettingsService().init();
  await AccountManager().init();

  // Initialize deep link service
  await DeepLinkService().init();

  runApp(const MiptgramApp());
}

class MiptgramApp extends StatelessWidget {
  const MiptgramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => LiquidGlassProvider()..init()),
        ChangeNotifierProvider(create: (_) => UnreadCountProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => NotificationSettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => PrivacySettingsProvider()..loadAll()),
        ChangeNotifierProvider(create: (_) => WallpaperProvider()..init()),
        ChangeNotifierProvider(create: (_) => ProfileThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => WalletSecurityProvider()),
        ChangeNotifierProxyProvider<WalletSecurityProvider, BankingCardsProvider>(
          create: (_) => BankingCardsProvider(),
          update: (_, security, cards) => cards!..update(security),
        ),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          return MaterialApp(
            title: 'Miptgram',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('ru'),
              Locale('es'),
              Locale('fr'),
              Locale('de'),
              Locale('it'),
              Locale('pt'),
              Locale('zh'),
              Locale('ja'),
              Locale('ko'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            navigatorKey: DeepLinkService().navigatorKey,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
