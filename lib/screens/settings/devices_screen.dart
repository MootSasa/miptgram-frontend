import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../l10n/app_localizations.dart';
import '../../services/account_manager.dart';
import '../../services/auth_service.dart';
import '../../config/app_config.dart';

/// Screen displaying all active device sessions for the current account.
/// Allows users to view, rename, and terminate sessions on other devices.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<DeviceSession> _sessions = [];
  bool _isLoading = true;
  String? _error;
  final AccountManager _accountManager = AccountManager();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final currentDeviceId = _accountManager.currentDeviceId ?? '';

    try {
      final result = await AuthService.getActiveSessions();

      if (result['success'] == true) {
        final serverSessions = result['sessions'] as List<dynamic>? ?? [];
        final sessions = <DeviceSession>[];

        for (final serverSession in serverSessions) {
          final sessionId = serverSession['id']?.toString() ?? '';
          final deviceId = serverSession['device_id']?.toString() ?? '';
          final deviceTypeStr = serverSession['device_type']?.toString() ?? 'unknown';
          final deviceType = _parseDeviceType(deviceTypeStr);

          DateTime lastActive;
          try {
            lastActive = DateTime.parse(serverSession['last_active']?.toString() ?? '');
          } catch (_) {
            lastActive = DateTime.now();
          }

          String deviceName = serverSession['device_name']?.toString() ?? 'Unknown Device';
          String os = 'Unknown';
          String osVersion = 'Unknown';
          final userAgent = serverSession['user_agent']?.toString() ?? '';
          if (userAgent.isNotEmpty) {
            final osInfo = _parseUserAgent(userAgent);
            os = osInfo['os'] ?? 'Unknown';
            osVersion = osInfo['osVersion'] ?? 'Unknown';
          }

          final isCurrentDevice = deviceId == currentDeviceId;

          sessions.add(DeviceSession(
            id: sessionId,
            deviceId: deviceId,
            userId: serverSession['user_id']?.toString() ?? '',
            deviceName: deviceName,
            deviceType: deviceType,
            os: os,
            osVersion: osVersion,
            lastActive: lastActive,
            isCurrent: isCurrentDevice,
            location: serverSession['ip_address']?.toString(),
          ));
        }

        if (mounted) {
          setState(() {
            _sessions = sessions;
            _isLoading = false;
          });
        }
      } else {
        final localSessions = _accountManager.getDeviceSessionsForAccount(
          _accountManager.currentAccount?.userId ?? '',
        );
        if (mounted) {
          setState(() {
            _sessions = localSessions;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      final localSessions = _accountManager.getDeviceSessionsForAccount(
        _accountManager.currentAccount?.userId ?? '',
      );
      if (mounted) {
        setState(() {
          _sessions = localSessions;
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, String> _parseUserAgent(String userAgent) {
    final result = <String, String>{'os': 'Unknown', 'osVersion': 'Unknown'};
    if (userAgent.contains('Android')) {
      result['os'] = 'Android';
      final match = RegExp(r'Android (\d+(?:\.\d+)?)').firstMatch(userAgent);
      if (match != null) result['osVersion'] = match.group(1) ?? 'Unknown';
    } else if (userAgent.contains('iPhone') || userAgent.contains('iPad')) {
      result['os'] = 'iOS';
      final match = RegExp(r'OS (\d+(?:\.\d+)?)').firstMatch(userAgent);
      if (match != null) result['osVersion'] = match.group(1) ?? 'Unknown';
    } else if (userAgent.contains('Windows')) {
      result['os'] = 'Windows';
      final match = RegExp(r'Windows NT (\d+(?:\.\d+)?)').firstMatch(userAgent);
      if (match != null) result['osVersion'] = match.group(1) ?? 'Unknown';
    } else if (userAgent.contains('Mac OS X')) {
      result['os'] = 'macOS';
      final match = RegExp(r'Mac OS X (\d+(?:[._]\d+)*)').firstMatch(userAgent);
      if (match != null) result['osVersion'] = match.group(1)?.replaceAll('_', '.') ?? 'Unknown';
    } else if (userAgent.contains('Linux')) {
      result['os'] = 'Linux';
    }
    return result;
  }

  DeviceType _parseDeviceType(String? type) {
    switch (type?.toLowerCase()) {
      case 'android': return DeviceType.android;
      case 'ios': return DeviceType.ios;
      case 'web': return DeviceType.web;
      case 'windows': return DeviceType.windows;
      case 'macos': return DeviceType.macos;
      case 'linux': return DeviceType.linux;
      default: return DeviceType.unknown;
    }
  }

  Future<void> _handleLogout(String sessionId, String deviceId) async {
    final l10n = context.l10n;

    // Check if this is the current device — extra confirmation
    final isCurrent = _sessions.any((s) => s.deviceId == deviceId && s.isCurrent);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('devices_terminate_title')),
        content: Text(isCurrent
            ? l10n.translate('devices_terminate_current_warning')
            : l10n.translate('devices_terminate_message')),
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
            child: Text(l10n.translate('devices_terminate')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        final success = await AuthService.logoutDevice(deviceId);
        if (!mounted) return;
        if (success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.translate('devices_terminate_success'))),
          );
          await _loadSessions();
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.translate('devices_terminate_error')), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.translate('devices_error').replaceAll('{error}', e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Terminate all other sessions except the current device
  Future<void> _handleTerminateOthers() async {
    final l10n = context.l10n;
    final currentDeviceId = _accountManager.currentDeviceId ?? '';
    final otherCount = _sessions.where((s) => !s.isCurrent).length;

    if (otherCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('devices_no_other_sessions'))),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('devices_terminate_all_title')),
        content: Text(l10n.translate('devices_terminate_all_message')
            .replaceAll('{count}', otherCount.toString())),
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
            child: Text(l10n.translate('devices_terminate_all')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        final token = await AuthService.getToken();
        final dio = Dio();
        final response = await dio.post(
          '${AppConfig.baseUrl}/api/auth/terminate-others',
          data: {'current_device_id': currentDeviceId},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (!mounted) return;
        if (response.data['success'] == true) {
          final count = response.data['terminated_count'] ?? 0;
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.translate('devices_terminate_all_success')
                .replaceAll('{count}', count.toString()))),
          );
          await _loadSessions();
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.translate('devices_terminate_error')), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Show rename dialog for a device
  Future<void> _handleRename(DeviceSession session) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: session.deviceName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('devices_rename_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: l10n.translate('devices_rename_label'),
            hintText: session.deviceName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(l10n.translate('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.translate('devices_rename_save')),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        final token = await AuthService.getToken();
        final dio = Dio();
        final response = await dio.put(
          '${AppConfig.baseUrl}/api/auth/sessions/${session.deviceId}/rename',
          data: {'device_name': newName},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (!mounted) return;
        if (response.data['success'] == true) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.translate('devices_rename_success'))),
          );
          await _loadSessions();
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(l10n.translate('devices_rename_error')), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    final l10n = context.l10n;

    if (difference.inMinutes < 1) {
      return l10n.translate('devices_just_now');
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${l10n.translate('devices_minutes_ago')}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${l10n.translate('devices_hours_ago')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${l10n.translate('devices_days_ago')}';
    } else {
      return '${lastActive.day}.${lastActive.month}.${lastActive.year}';
    }
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.android:
      case DeviceType.ios:
        return Icons.smartphone;
      case DeviceType.web:
        return Icons.web;
      case DeviceType.windows:
      case DeviceType.macos:
      case DeviceType.linux:
        return Icons.computer;
      case DeviceType.unknown:
        return Icons.device_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('devices_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: l10n.translate('devices_refresh'),
          ),
        ],
      ),
      body: _buildBody(theme, l10n),
    );
  }

  Widget _buildBody(ThemeData theme, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(l10n.translate('devices_error').replaceAll('{error}', _error!),
                style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSessions, child: Text(l10n.translate('devices_retry'))),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(l10n.translate('devices_no_sessions'),
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
          ],
        ),
      );
    }

    final currentSession = _sessions.where((s) => s.isCurrent).firstOrNull;
    final otherSessions = _sessions.where((s) => !s.isCurrent).toList();

    return ListView(
      children: [
        if (currentSession != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.translate('devices_this_device'),
                style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
          _DeviceSessionTile(
            session: currentSession,
            deviceIcon: _getDeviceIcon(currentSession.deviceType),
            formattedTime: _formatLastActive(currentSession.lastActive),
            isCurrent: true,
            onLogout: null,
            onRename: () => _handleRename(currentSession),
          ),
          const Divider(height: 32),
        ],
        if (otherSessions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.translate('devices_other_sessions'),
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _handleTerminateOthers,
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(l10n.translate('devices_terminate_all_short')),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
          ...otherSessions.map((session) => _DeviceSessionTile(
            session: session,
            deviceIcon: _getDeviceIcon(session.deviceType),
            formattedTime: _formatLastActive(session.lastActive),
            isCurrent: false,
            onLogout: () => _handleLogout(session.id, session.deviceId),
            onRename: () => _handleRename(session),
          )),
        ],
        // Info section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.translate('devices_info_title'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(l10n.translate('devices_info_description'),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceSessionTile extends StatelessWidget {
  final DeviceSession session;
  final IconData deviceIcon;
  final String formattedTime;
  final bool isCurrent;
  final VoidCallback? onLogout;
  final VoidCallback? onRename;

  const _DeviceSessionTile({
    required this.session,
    required this.deviceIcon,
    required this.formattedTime,
    required this.isCurrent,
    this.onLogout,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isCurrent
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(deviceIcon,
            color: isCurrent
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(session.deviceName,
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${session.os} ${session.osVersion}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Row(children: [
            Icon(Icons.access_time, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(formattedTime,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (session.location != null && session.location!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(session.location!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ]),
        ],
      ),
      trailing: isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(l10n.translate('devices_active_now'),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
            )
          : Row(mainAxisSize: MainAxisSize.min, children: [
              // Rename button
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: onRename,
                tooltip: l10n.translate('devices_rename_title'),
                color: Colors.grey,
              ),
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: onLogout,
                tooltip: l10n.translate('devices_terminate'),
                color: Colors.red,
              ),
            ]),
      // Long press to rename for current device
      onLongPress: isCurrent ? onRename : null,
    );
  }
}
