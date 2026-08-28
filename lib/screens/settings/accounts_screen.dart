import '../../utils/image_utils.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/account_manager.dart';
import '../../services/auth_service.dart';
import '../../services/websocket_service.dart';
import '../auth/login_screen.dart';
import '../main/main_screen.dart';
import '../../utils/swipe_back_route.dart';

/// Screen for managing multiple accounts.
/// Allows users to:
/// - View all logged in accounts
/// - Switch between accounts
/// - Add new accounts
/// - Remove accounts
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AccountManager _accountManager = AccountManager();
  List<Account> _accounts = [];
  Account? _currentAccount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  void _loadAccounts() {
    setState(() {
      _accounts = _accountManager.accounts;
      _currentAccount = _accountManager.currentAccount;
    });
  }

  Future<void> _switchAccount(Account account) async {
    if (account.userId == _currentAccount?.userId) return;

    setState(() => _isLoading = true);

    try {
      await _accountManager.setCurrentAccount(account.userId);

      // Verify the token is still valid
      final isValid = await _verifyToken(account.token);

      if (!mounted) return;

      if (isValid) {
        // Update WebSocket with new user ID and reconnect
        final wsService = WebSocketService();
        await wsService.updateUserId(account.userId);

        if (!mounted) return;
        // Navigate to main screen with new account
        Navigator.of(context).pushAndRemoveUntil(
          SwipeBackPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        // Token expired, need to re-login
        _showReLoginDialog(account);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.translate('accounts_switch_error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _verifyToken(String token) async {
    try {
      // Try to get current user info with the token
      final result = await AuthService.getCurrentUser();
      return result['success'] == true;
    } catch (e) {
      return false;
    }
  }

  void _showReLoginDialog(Account account) {
    final l10n = context.l10n;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('accounts_session_expired')),
        content: Text(
          l10n.translate('accounts_session_expired_message')
              .replaceAll('{username}', account.username ?? account.userId),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeAccount(account);
            },
            child: Text(l10n.translate('accounts_remove')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToLogin(forAccount: account);
            },
            child: Text(l10n.translate('auth_login')),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAccount(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.translate('accounts_remove_title')),
        content: Text(
          context.l10n.translate('accounts_remove_message')
              .replaceAll('{username}', account.username ?? account.userId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.translate('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.translate('accounts_remove')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _accountManager.removeAccount(account.userId);
      _loadAccounts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.translate('accounts_removed')),
          ),
        );
      }

      // If no accounts left, go to login
      if (_accounts.isEmpty && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          SwipeBackPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _navigateToLogin({Account? forAccount}) {
    Navigator.of(context).push(
      SwipeBackPageRoute(
        builder: (_) => const LoginScreen(),
        settings: RouteSettings(
          arguments: forAccount != null 
              ? {'switchingAccount': true, 'userId': forAccount.userId}
              : null,
        ),
      ),
    ).then((_) {
      // Refresh accounts when returning
      _loadAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('accounts_title')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(theme, l10n),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToLogin(),
        tooltip: l10n.translate('settings_add_account'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, AppLocalizations l10n) {
    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('accounts_no_accounts'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToLogin(),
              icon: const Icon(Icons.add),
              label: Text(l10n.translate('settings_add_account')),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Info card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.translate('accounts_info'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Accounts list
        ..._accounts.map((account) => _AccountTile(
          account: account,
          isCurrent: account.userId == _currentAccount?.userId,
          onTap: () => _switchAccount(account),
          onLongPress: () => _showAccountOptions(account),
        )),
        
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  void _showAccountOptions(Account account) {
    final l10n = context.l10n;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.translate('accounts_switch')),
              onTap: () {
                Navigator.of(context).pop();
                _switchAccount(account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                l10n.translate('accounts_remove'),
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _removeAccount(account);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final Account account;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AccountTile({
    required this.account,
    required this.isCurrent,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            key: ValueKey('account_avatar_${account.userId}'),
            radius: 24,
            backgroundImage: account.avatarUrl != null
            ? avatarImageProvider(account.avatarUrl)
            : null,
            child: account.avatarUrl == null
            ? Text(
                (account.displayName ?? account.username ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontSize: 24),
              )
            : null,
          ),
          if (isCurrent)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        account.displayName ?? account.username ?? l10n.translate('accounts_unknown'),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '@${account.username ?? account.userId}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l10n.translate('accounts_active'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: isCurrent ? null : onTap,
      onLongPress: onLongPress,
    );
  }
}
