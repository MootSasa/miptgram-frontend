import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';
import 'storage_screen.dart';
import 'devices_screen.dart';
import 'folders_screen.dart';
import 'power_saving_screen.dart';
import 'language_screen.dart';
import 'chat_settings_screen.dart';
import 'accounts_screen.dart';
import 'wallets_screen.dart';
import 'service_menu_screen.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../services/account_manager.dart';
import '../../utils/image_utils.dart';
import '../../utils/haptic_utils.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/liquid_glass_provider.dart';
import '../../widgets/chat/liquid_glass_bottom_bar.dart';
import '../../widgets/chat/classic_bottom_bar.dart';
import '../../widgets/chat/liquid_glass_app_bar.dart';
import '../../widgets/settings/settings_group.dart';
import '../auth/login_screen.dart';
import '../../utils/swipe_back_route.dart';

/// Экран настроек.
///
/// Когда [isEmbedded] = true, используется как страница внутри PageView
/// на главном экране — без собственного Scaffold и bottom bar.
/// Когда [isEmbedded] = false (по умолчанию), работает как самостоятельный экран.
class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const SettingsScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  final AccountManager _accountManager = AccountManager();
  Account? _currentAccount;

  int _versionTapCount = 0;
  DateTime? _lastTapTime;

  String _getSystemAbi() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return defaultTargetPlatform.name;
    }
  }

  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _versionTapCount = 0;
    }
    _lastTapTime = now;
    _versionTapCount++;

    HapticUtils.tap();

    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      Navigator.push(
        context,
        SwipeBackPageRoute(
          builder: (_) => const ServiceMenuScreen(),
        ),
      );
    }
  }

  Widget _buildVersionInfoSection(ThemeData theme, AppLocalizations l10n) {
    final systemAbi = _getSystemAbi();
    const buildDate = AppConfig.buildDate;
    const appVersion = AppConfig.appVersion;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleVersionTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Miptgram v$appVersion ($systemAbi)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.translate('build_date').replaceAll('{date}', buildDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentAccount = _accountManager.currentAccount;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currentAccount = _currentAccount;

    // Меню «три точки» — содержит «Выйти» и «Очистить данные»
    final appBarActions = [
      PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'logout':
              _handleLogout(context);
              break;
            case 'clear_data':
              _showClearDataDialog(context);
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'logout',
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                l10n.translate('menu_logout'),
                style: const TextStyle(color: Colors.red),
              ),
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 24,
            ),
          ),
          PopupMenuItem(
            value: 'clear_data',
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.orange),
              title: Text(
                l10n.translate('clear_data_title'),
                style: const TextStyle(color: Colors.orange),
              ),
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 24,
            ),
          ),
        ],
        icon: const Icon(Icons.more_vert),
      ),
    ];

    // AppBar title — крупная надпись «Настройки»
    final appBarTitle = Text(
      l10n.translate('settings_title'),
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );

    // Содержимое списка настроек (без обёртки ListView)
    final listChildren = <Widget>[
      // Current Account Section
      if (currentAccount != null) ...[
        _buildCurrentAccountSection(theme, l10n, currentAccount),
        const SizedBox(height: 8),
      ],

      SettingsGroup(
        children: [
          // Profile Section
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_profile')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),

          // Accounts Section
          ListTile(
            leading: const Icon(Icons.switch_account, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('accounts_title')),
            subtitle: Text(
              '${_accountManager.accounts.length} ${l10n.translate('accounts_count')}',
            ),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(
                  builder: (_) => const AccountsScreen(),
                ),
              );
            },
          ),

          // Add Account Section
          ListTile(
            leading:
                const Icon(Icons.add_circle_outline, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_add_account')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),

      SettingsGroup(
        children: [
          // Chat Settings Section (Wallpaper + Liquid Glass)
          ListTile(
            leading: const Icon(Icons.chat, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_chat_settings')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const ChatSettingsScreen()),
              );
            },
          ),

          // Privacy Section
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_privacy')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const PrivacyScreen()),
              );
            },
          ),

          // Notifications Section
          ListTile(
            leading: const Icon(Icons.notifications, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_notifications')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),

      SettingsGroup(
        children: [
          // Data & Storage Section
          ListTile(
            leading: const Icon(Icons.storage, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_data_storage')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const StorageScreen()),
              );
            },
          ),

          // Devices Section
          ListTile(
            leading: const Icon(Icons.devices, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_devices')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const DevicesScreen()),
              );
            },
          ),

          // Chat Folders Section
          ListTile(
            leading: const Icon(Icons.folder, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_folders')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const FoldersScreen()),
              );
            },
          ),
        ],
      ),

      SettingsGroup(
        children: [
          // Wallets and Cards Section
          ListTile(
            leading: const Icon(Icons.account_balance_wallet,
                color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_wallets_cards')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const WalletsScreen()),
              );
            },
          ),
        ],
      ),

      SettingsGroup(
        children: [
          // Power Saving Section
          ListTile(
            leading: const Icon(Icons.battery_saver, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_power_saving')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const PowerSavingScreen()),
              );
            },
          ),

          // Language Section
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF0088CC)),
            title: Text(l10n.translate('settings_language')),
            onTap: () {
              HapticUtils.tap();
              Navigator.push(
                context,
                SwipeBackPageRoute(builder: (_) => const LanguageScreen()),
              );
            },
          ),
        ],
      ),

      const SizedBox(height: 24),
      _buildVersionInfoSection(theme, l10n),
      const SizedBox(height: 24),
    ];

    // ListView для classic-режима
    final listView = ListView(
      physics: const ClampingScrollPhysics(),
      padding: widget.isEmbedded
          ? const EdgeInsets.only(bottom: 120)
          : null,
      children: listChildren,
    );

    // Встроенный режим — используется внутри PageView на главном экране
    if (widget.isEmbedded) {
      return Consumer<LiquidGlassProvider>(
        builder: (context, glassProvider, _) {
          final glassEnabled = glassProvider.enabled;

          if (glassEnabled) {
            // Glass-режим: Stack с glass AppBar поверх контента
            // Список уходит под AppBar — стекло преломляет контент
            final topPadding =
                MediaQuery.of(context).padding.top + kToolbarHeight;

            return Stack(
              children: [
                // Контент настроек заполняет весь экран —
                // стеклянный AppBar преломляет список под ним
                Positioned.fill(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      // Отступ чтобы первые элементы были ниже AppBar
                      SizedBox(height: topPadding),
                      // Содержимое списка
                      ...listChildren,
                    ],
                  ),
                ),
                // Glass AppBar поверх контента (без кнопки «назад»)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassAppBar(
                    title: appBarTitle,
                    actions: appBarActions,
                    leading: const SizedBox.shrink(),
                    centerTitle: true,
                    isLite: glassProvider.isLite,
                  ),
                ),
              ],
            );
          }

          // Classic встроенный режим: AppBar + ListView (без кнопки «назад»)
          return Column(
            children: [
              AppBar(
                title: appBarTitle,
                actions: appBarActions,
                automaticallyImplyLeading: false,
                centerTitle: true,
              ),
              Expanded(child: listView),
            ],
          );
        },
      );
    }

    // Самостоятельный экран (не встроенный)
    return Consumer<LiquidGlassProvider>(
      builder: (context, glassProvider, _) {
        final glassEnabled = glassProvider.enabled;

        if (glassEnabled) {
          final topPadding =
              MediaQuery.of(context).padding.top + kToolbarHeight;

          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: listView,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassAppBar(
                    title: appBarTitle,
                    actions: appBarActions,
                    centerTitle: true,
                    isLite: glassProvider.isLite,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: LiquidGlassBottomBar(
              selectedIndex: 0,
              onTabSelected: (index) {
                if (index != 0) {
                  Navigator.pop(context);
                }
              },
              isLite: glassProvider.isLite,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: appBarTitle,
            actions: appBarActions,
            centerTitle: true,
          ),
          body: listView,
          bottomNavigationBar: ClassicBottomBar(
            selectedIndex: 0,
            onTabSelected: (index) {
              if (index != 0) {
                Navigator.pop(context);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildCurrentAccountSection(ThemeData theme, AppLocalizations l10n, Account account) {
    return SettingsGroup(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              SwipeBackPageRoute(
                builder: (_) => const AccountsScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  key: ValueKey('settings_avatar_${account.userId}'),
                  radius: 28,
                  backgroundImage: avatarImageProvider(account.avatarUrl),
                  backgroundColor: const Color(0xFF0088CC),
                  child: account.avatarUrl == null
                  ? Text(
                      (account.displayName ?? account.username ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName ?? l10n.translate('accounts_unknown'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${account.username ?? account.userId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final l10n = context.l10n;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('menu_logout')),
        content: Text(l10n.translate('accounts_logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.translate('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.translate('menu_logout')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      
      if (!context.mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        SwipeBackPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showClearDataDialog(BuildContext context) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('clear_data_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('clear_data_message')),
            const SizedBox(height: 12),
            Text(
              l10n.translate('clear_data_warning'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.translate('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _clearAllData(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.translate('clear_data_button')),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context) async {
    final l10n = context.l10n;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _accountManager.clearAll();

      final settingsService = SettingsService();
      await settingsService.clearAllSettings();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.translate('clear_data_success'))),
      );

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          SwipeBackPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.translate('clear_data_error').replaceAll('{error}', e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
