import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/privacy_settings_provider.dart';
import '../../services/settings_service.dart';
import '../../widgets/settings/settings_group.dart';
import 'passcode_screen.dart';
import 'blocked_users_screen.dart';
import 'devices_screen.dart';

/// Экран «Безопасность» — 2FA, блокировка приложения, заблокированные, сессии
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('security_title'))),
      body: Consumer<PrivacySettingsProvider>(
        builder: (context, provider, _) {
          final tfa = provider.twoFactor;
          final lock = provider.appLock;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Двухэтапная аутентификация
              SettingsGroup(
                title: l10n.translate('security_2fa_section'),
                children: [
                  ListTile(
                    leading: Icon(Icons.lock,
                        color: tfa.enabled ? Colors.green : Colors.grey),
                    title: Text(l10n.translate('security_2fa')),
                    subtitle: Text(tfa.enabled
                        ? l10n.translate('security_2fa_enabled')
                        : l10n.translate('security_2fa_disabled')),
                    trailing: Switch(
                      value: tfa.enabled,
                      onChanged: (v) async {
                        if (v) {
                          _show2FADialog(context);
                        } else {
                          await provider.disable2FA();
                        }
                      },
                    ),
                  ),
                  if (tfa.enabled)
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(l10n.translate('security_recovery_email')),
                      subtitle: Text(tfa.recoveryEmail.isEmpty
                          ? l10n.translate('security_not_set')
                          : tfa.recoveryEmail),
                      onTap: () =>
                          _showRecoveryEmailDialog(context, tfa.recoveryEmail),
                    ),
                ],
              ),

              // Блокировка приложения
              SettingsGroup(
                title: l10n.translate('security_app_lock_section'),
                children: [
                  ListTile(
                    leading: Icon(Icons.phone_android,
                        color: lock.hasPin ? Colors.blue : Colors.grey),
                    title: Text(l10n.translate('security_pin_code')),
                    subtitle: Text(lock.hasPin
                        ? l10n.translate('security_pin_set')
                        : l10n.translate('security_pin_not_set')),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PasscodeScreen())),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(l10n.translate('security_biometrics')),
                    value: lock.biometricsEnabled,
                    onChanged: (v) {
                      provider.saveAppLock(AppLockSettings(
                        hasPin: lock.hasPin,
                        biometricsEnabled: v,
                        autoLockTimeout: lock.autoLockTimeout,
                      ));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: Text(l10n.translate('security_auto_lock')),
                    subtitle: Text(_autoLockLabel(l10n, lock.autoLockTimeout)),
                    onTap: () => _showAutoLockPicker(context, lock),
                  ),
                ],
              ),

              // Заблокированные пользователи
              SettingsGroup(
                title: l10n.translate('security_blocked_section'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: Text(l10n.translate('security_blocked_users')),
                    subtitle: Text('${provider.blockedUsers.length}'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BlockedUsersScreen())),
                  ),
                ],
              ),

              // Активные сессии
              SettingsGroup(
                title: l10n.translate('security_sessions_section'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text(l10n.translate('security_active_sessions')),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DevicesScreen())),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  String _autoLockLabel(AppLocalizations l10n, String timeout) => switch (timeout) {
    'immediately' => l10n.translate('security_auto_lock_immediately'),
    '1min' => l10n.translate('security_auto_lock_1min'),
    '5min' => l10n.translate('security_auto_lock_5min'),
    '15min' => l10n.translate('security_auto_lock_15min'),
    '1hour' => l10n.translate('security_auto_lock_1hour'),
    _ => timeout,
  };

  void _show2FADialog(BuildContext context) {
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Двухэтапная аутентификация'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Пароль')),
          const SizedBox(height: 8),
          TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Recovery email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена')),
          TextButton(onPressed: () async {
            // Hash password (in production use proper hashing)
            await context.read<PrivacySettingsProvider>().enable2FA(
                passwordController.text, emailController.text);
            Navigator.pop(ctx);
          }, child: Text('Включить')),
        ],
      ),
    );
  }

  void _showRecoveryEmailDialog(BuildContext context, String currentEmail) {
    final controller = TextEditingController(text: currentEmail);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Recovery email'),
        content: TextField(controller: controller, keyboardType: TextInputType.emailAddress),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена')),
          TextButton(onPressed: () async {
            await context.read<PrivacySettingsProvider>().enable2FA('', controller.text);
            Navigator.pop(ctx);
          }, child: Text('Сохранить')),
        ],
      ),
    );
  }

  void _showAutoLockPicker(BuildContext context, AppLockSettings lock) {
    final l10n = context.l10n;
    final options = ['immediately', '1min', '5min', '15min', '1hour'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) => ListTile(
          title: Text(_autoLockLabel(l10n, opt)),
          trailing: lock.autoLockTimeout == opt ? const Icon(Icons.check) : null,
          onTap: () {
            context.read<PrivacySettingsProvider>().saveAppLock(AppLockSettings(
              hasPin: lock.hasPin, biometricsEnabled: lock.biometricsEnabled, autoLockTimeout: opt));
            Navigator.pop(ctx);
          },
        )).toList(),
      ),
    );
  }
}
