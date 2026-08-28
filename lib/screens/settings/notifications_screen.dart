import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_settings_provider.dart';
import '../../services/liquid_glass_provider.dart';
import '../../services/settings_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/chat/liquid_glass_app_bar.dart';
import '../../widgets/settings/settings_group.dart';
import '../../utils/haptic_utils.dart';

/// Экран настроек уведомлений — полная реализация.
///
/// Поддерживает Liquid Glass и Classic режимы дизайна.
/// Секции: главный переключатель, приватные чаты, группы, каналы,
/// звонки, поведение, сброс per-chat настроек.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Инициализация провайдера при первом открытии
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationSettingsProvider>();
      provider.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

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
                    child: _buildSettingsList(context, l10n, theme),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LiquidGlassAppBar(
                    title: Text(l10n.translate('notifications_title')),
                    centerTitle: true,
                    isLite: glassProvider.isLite,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.translate('notifications_title')),
            centerTitle: true,
          ),
          body: _buildSettingsList(context, l10n, theme),
        );
      },
    );
  }

  Widget _buildSettingsList(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Consumer<NotificationSettingsProvider>(
      builder: (context, provider, _) {
        final settings = provider.globalSettings;

        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // === Главный переключатель ===
            SettingsGroup(
              title: l10n.translate('notifications_main_section'),
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active,
                      color: Color(0xFF0088CC)),
                  title: Text(l10n.translate('notifications_enabled')),
                  subtitle: Text(l10n.translate('notifications_enabled_desc')),
                  value: settings.notificationsEnabled,
                  onChanged: (value) {
                    HapticUtils.selection();
                    provider.updateGlobalSettings(notificationsEnabled: value);
                  },
                ),
              ],
            ),

            // Если уведомления выключены — показываем только главный переключатель
            if (!settings.notificationsEnabled) ...[
              const SizedBox(height: 32),
              Center(
                child: Icon(Icons.notifications_off,
                    size: 64, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  l10n.translate('notifications_disabled_hint'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            if (settings.notificationsEnabled) ...[
              // === Приватные чаты ===
              SettingsGroup(
                title: l10n.translate('notifications_private_chats'),
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.person, color: Color(0xFF0088CC)),
                    title: Text(l10n.translate('notifications_private_messages')),
                    value: settings.privateChatNotifications,
                    onChanged: (value) {
                      HapticUtils.selection();
                      provider.updateGlobalSettings(
                          privateChatNotifications: value);
                    },
                  ),
                  if (settings.privateChatNotifications) ...[
                    SwitchListTile(
                      title: Text(l10n.translate('notifications_preview')),
                      subtitle: Text(l10n.translate('notifications_preview_desc')),
                      value: settings.privateChatPreview,
                      onChanged: (value) {
                        HapticUtils.selection();
                        provider.updateGlobalSettings(privateChatPreview: value);
                      },
                    ),
                    ListTile(
                      title: Text(l10n.translate('notifications_sound')),
                      subtitle: Text(settings.privateChatSound
                          ? l10n.translate('notifications_sound_on')
                          : l10n.translate('notifications_sound_off')),
                      trailing: Switch(
                        value: settings.privateChatSound,
                        onChanged: (value) {
                          HapticUtils.selection();
                          provider.updateGlobalSettings(privateChatSound: value);
                        },
                      ),
                    ),
                    ListTile(
                      title: Text(l10n.translate('notifications_vibration')),
                      subtitle: Text(
                          _vibrationLabel(settings.privateChatVibration, l10n)),
                      onTap: () => _showVibrationPicker(
                        context,
                        settings.privateChatVibration,
                        (pattern) => provider.updateGlobalSettings(
                            privateChatVibration: pattern),
                      ),
                    ),
                  ],
                ],
              ),

              // === Групповые чаты ===
              SettingsGroup(
                title: l10n.translate('notifications_group_chats'),
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.group, color: Color(0xFF0088CC)),
                    title: Text(l10n.translate('notifications_group_messages')),
                    value: settings.groupChatNotifications,
                    onChanged: (value) {
                      HapticUtils.selection();
                      provider.updateGlobalSettings(groupChatNotifications: value);
                    },
                  ),
                  if (settings.groupChatNotifications) ...[
                    SwitchListTile(
                      title: Text(l10n.translate('notifications_preview')),
                      value: settings.groupChatPreview,
                      onChanged: (value) {
                        HapticUtils.selection();
                        provider.updateGlobalSettings(groupChatPreview: value);
                      },
                    ),
                    ListTile(
                      title: Text(l10n.translate('notifications_sound')),
                      subtitle: Text(settings.groupChatSound
                          ? l10n.translate('notifications_sound_on')
                          : l10n.translate('notifications_sound_off')),
                      trailing: Switch(
                        value: settings.groupChatSound,
                        onChanged: (value) {
                          HapticUtils.selection();
                          provider.updateGlobalSettings(groupChatSound: value);
                        },
                      ),
                    ),
                    ListTile(
                      title: Text(l10n.translate('notifications_vibration')),
                      subtitle: Text(
                          _vibrationLabel(settings.groupChatVibration, l10n)),
                      onTap: () => _showVibrationPicker(
                        context,
                        settings.groupChatVibration,
                        (pattern) => provider.updateGlobalSettings(
                            groupChatVibration: pattern),
                      ),
                    ),
                    SwitchListTile(
                      title: Text(l10n.translate('notifications_mentions')),
                      subtitle: Text(l10n.translate('notifications_mentions_desc')),
                      value: settings.mentionsNotifications,
                      onChanged: (value) {
                        HapticUtils.selection();
                        provider.updateGlobalSettings(
                            mentionsNotifications: value);
                      },
                    ),
                  ],
                ],
              ),

              // === Каналы ===
              SettingsGroup(
                title: l10n.translate('notifications_channels'),
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.campaign, color: Color(0xFF0088CC)),
                    title: Text(l10n.translate('notifications_channel_messages')),
                    value: settings.channelNotifications,
                    onChanged: (value) {
                      HapticUtils.selection();
                      provider.updateGlobalSettings(channelNotifications: value);
                    },
                  ),
                  if (settings.channelNotifications) ...[
                    SwitchListTile(
                      title: Text(l10n.translate('notifications_preview')),
                      value: settings.channelPreview,
                      onChanged: (value) {
                        HapticUtils.selection();
                        provider.updateGlobalSettings(channelPreview: value);
                      },
                    ),
                    ListTile(
                      title: Text(l10n.translate('notifications_sound')),
                      subtitle: Text(settings.channelSound
                          ? l10n.translate('notifications_sound_on')
                          : l10n.translate('notifications_sound_off')),
                      trailing: Switch(
                        value: settings.channelSound,
                        onChanged: (value) {
                          HapticUtils.selection();
                          provider.updateGlobalSettings(channelSound: value);
                        },
                      ),
                    ),
                    ListTile(
                      title: Text(l10n.translate('notifications_vibration')),
                      subtitle:
                          Text(_vibrationLabel(settings.channelVibration, l10n)),
                      onTap: () => _showVibrationPicker(
                        context,
                        settings.channelVibration,
                        (pattern) => provider.updateGlobalSettings(
                            channelVibration: pattern),
                      ),
                    ),
                  ],
                ],
              ),

              // === Звонки ===
              SettingsGroup(
                title: l10n.translate('notifications_calls'),
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.call, color: Color(0xFF0088CC)),
                    title: Text(l10n.translate('notifications_call_notifications')),
                    value: settings.callNotifications,
                    onChanged: (value) {
                      HapticUtils.selection();
                      provider.updateGlobalSettings(callNotifications: value);
                    },
                  ),
                  if (settings.callNotifications) ...[
                    SwitchListTile(
                      title: Text(l10n.translate('notifications_sound')),
                      value: settings.callSound,
                      onChanged: (value) {
                        HapticUtils.selection();
                        provider.updateGlobalSettings(callSound: value);
                      },
                    ),
                    SwitchListTile(
                      title: Text(l10n.translate('notifications_vibration')),
                      value: settings.callVibration,
                      onChanged: (value) {
                        HapticUtils.selection();
                        provider.updateGlobalSettings(callVibration: value);
                      },
                    ),
                  ],
                ],
              ),

              // === Поведение ===
              SettingsGroup(
                title: l10n.translate('notifications_behavior'),
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.badge, color: Color(0xFF0088CC)),
                    title: Text(l10n.translate('notifications_badge')),
                    subtitle: Text(l10n.translate('notifications_badge_desc')),
                    value: settings.badgeEnabled,
                    onChanged: (value) {
                      HapticUtils.selection();
                      provider.updateGlobalSettings(badgeEnabled: value);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.picture_in_picture_alt,
                        color: Color(0xFF0088CC)),
                    title: Text(l10n.translate('notifications_popup')),
                    subtitle: Text(l10n.translate('notifications_popup_desc')),
                    value: settings.popupEnabled,
                    onChanged: (value) {
                      HapticUtils.selection();
                      provider.updateGlobalSettings(popupEnabled: value);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility, color: Color(0xFF0088CC)),
                    title: Text(l10n.translate('notifications_content_preview')),
                    subtitle:
                        Text(l10n.translate('notifications_content_preview_desc')),
                    value: settings.contentPreview,
                    onChanged: (value) {
                      HapticUtils.selection();
                      provider.updateGlobalSettings(contentPreview: value);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_off_outlined,
                        color: Color(0xFF0088CC)),
                    title: Text(l10n.translate('notifications_include_muted')),
                    subtitle:
                        Text(l10n.translate('notifications_include_muted_desc')),
                    value: settings.includeMutedChats,
                    onChanged: (value) {
                      HapticUtils.selection();
                      provider.updateGlobalSettings(includeMutedChats: value);
                    },
                  ),
                ],
              ),

              // === Сброс ===
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1),
              ),
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.orange),
                title: Text(
                  l10n.translate('notifications_reset_all'),
                  style: const TextStyle(color: Colors.orange),
                ),
                subtitle: Text(l10n.translate('notifications_reset_all_desc')),
                onTap: () => _showResetDialog(context, provider, l10n),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: const Color(0xFF0088CC),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _vibrationLabel(VibrationPattern pattern, AppLocalizations l10n) {
    switch (pattern) {
      case VibrationPattern.default_:
        return l10n.translate('vibration_default');
      case VibrationPattern.none:
        return l10n.translate('vibration_none');
      case VibrationPattern.short:
        return l10n.translate('vibration_short');
      case VibrationPattern.long:
        return l10n.translate('vibration_long');
      case VibrationPattern.doubleShort:
        return l10n.translate('vibration_double_short');
      case VibrationPattern.tripleShort:
        return l10n.translate('vibration_triple_short');
    }
  }

  void _showVibrationPicker(
    BuildContext context,
    VibrationPattern current,
    ValueChanged<VibrationPattern> onChanged,
  ) {
    final l10n = context.l10n;
    HapticUtils.tap();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.translate('notifications_vibration'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ...VibrationPattern.values.map((pattern) => ListTile(
                    title: Text(_vibrationLabel(pattern, l10n)),
                    trailing: pattern == current
                        ? const Icon(Icons.check, color: Color(0xFF0088CC))
                        : null,
                    onTap: () {
                      HapticUtils.selection();
                      onChanged(pattern);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showResetDialog(
    BuildContext context,
    NotificationSettingsProvider provider,
    AppLocalizations l10n,
  ) {
    HapticUtils.tap();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('notifications_reset_all')),
        content: Text(l10n.translate('notifications_reset_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.resetAllChatSettings();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content:
                      Text(l10n.translate('notifications_reset_done')),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.translate('notifications_reset_button')),
          ),
        ],
      ),
    );
  }
}
