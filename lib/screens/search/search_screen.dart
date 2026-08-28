import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../l10n/app_localizations.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Search results
  List<SearchResultUser> _users = [];
  List<SearchResultGroup> _groups = [];
  List<SearchResultChannel> _channels = [];
  List<SearchResultMessage> _messages = [];

  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingGroups = false;
  bool _isLoadingChannels = false;
  bool _isLoadingMessages = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text;
    if (newQuery != _searchQuery) {
      setState(() {
        _searchQuery = newQuery;
      });
      _performSearch();
    }
  }

  void _performSearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _users = [];
        _groups = [];
        _channels = [];
        _messages = [];
      });
      return;
    }
    _searchUsers();
    _searchGroups();
    _searchChannels();
    _searchMessages();
  }

  Future<void> _searchUsers() async {
    if (_searchQuery.isEmpty) return;
    setState(() => _isLoadingUsers = true);
    try {
      final results = await SearchService.searchUsers(query: _searchQuery);
      if (mounted) {
        setState(() {
          _users = results;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _searchGroups() async {
    if (_searchQuery.isEmpty) return;
    setState(() => _isLoadingGroups = true);
    try {
      final results = await SearchService.searchGroups(query: _searchQuery);
      if (mounted) {
        setState(() {
          _groups = results;
          _isLoadingGroups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  Future<void> _searchChannels() async {
    if (_searchQuery.isEmpty) return;
    setState(() => _isLoadingChannels = true);
    try {
      final results = await SearchService.searchChannels(query: _searchQuery);
      if (mounted) {
        setState(() {
          _channels = results;
          _isLoadingChannels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingChannels = false);
      }
    }
  }

  Future<void> _searchMessages() async {
    if (_searchQuery.isEmpty) return;
    setState(() => _isLoadingMessages = true);
    try {
      final results = await SearchService.searchMessages(query: _searchQuery);
      if (mounted) {
        setState(() {
          _messages = results;
          _isLoadingMessages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: l10n.translate('search_hint'),
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          autofocus: true,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: l10n.translate('search_users')),
            Tab(text: l10n.translate('search_groups')),
            Tab(text: l10n.translate('search_channels')),
            Tab(text: l10n.translate('search_messages')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(),
          _buildGroupsList(),
          _buildChannelsList(),
          _buildMessagesList(),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final l10n = context.l10n;
    
    if (_searchQuery.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('search_start_typing'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('search_no_users').replaceAll('{query}', _searchQuery),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
          ),
          title: Text(user.name),
          subtitle: Text('@${user.username}'),
          onTap: () => _onUserTap(user),
        );
      },
    );
  }

  Widget _buildGroupsList() {
    final l10n = context.l10n;
    
    if (_searchQuery.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('search_start_typing'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_isLoadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_groups.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('search_no_groups').replaceAll('{query}', _searchQuery),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return ListTile(
          leading: const Icon(Icons.group, size: 40),
          title: Text(group.name),
          subtitle: Text(
            group.description.isNotEmpty ? group.description : l10n.translate('search_no_description'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _onGroupTap(group),
        );
      },
    );
  }

  Widget _buildChannelsList() {
    final l10n = context.l10n;
    
    if (_searchQuery.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('search_start_typing'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_isLoadingChannels) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_channels.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('search_no_channels').replaceAll('{query}', _searchQuery),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _channels.length,
      itemBuilder: (context, index) {
        final channel = _channels[index];
        return ListTile(
          leading: const Icon(Icons.forum, size: 40),
          title: Text(channel.name),
          subtitle: Text(
            channel.description.isNotEmpty ? channel.description : l10n.translate('search_no_description'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _onChannelTap(channel),
        );
      },
    );
  }

  Widget _buildMessagesList() {
    final l10n = context.l10n;
    
    if (_searchQuery.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('search_start_typing'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('search_no_messages').replaceAll('{query}', _searchQuery),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return ListTile(
          leading: const Icon(Icons.message),
          title: Text(
            message.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${l10n.translate('search_from_user').replaceAll('{user}', message.userId)} • ${_formatDate(message.createdAt)}',
          ),
          onTap: () => _onMessageTap(message),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '${l10n.translate('date_today')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return l10n.translate('date_yesterday');
    } else if (difference.inDays < 7) {
      return l10n.translate('date_days_ago').replaceAll('{days}', difference.inDays.toString());
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  void _onUserTap(SearchResultUser user) {
    // Navigate to user profile or start a private chat
    Navigator.pop(context, {'type': 'user', 'data': user});
  }

  void _onGroupTap(SearchResultGroup group) {
    // Navigate to group chat
    Navigator.pop(context, {'type': 'group', 'data': group});
  }

  void _onChannelTap(SearchResultChannel channel) {
    // Navigate to channel
    Navigator.pop(context, {'type': 'channel', 'data': channel});
  }

  void _onMessageTap(SearchResultMessage message) {
    // Navigate to the message in its original context
    Navigator.pop(context, {'type': 'message', 'data': message});
  }
}
