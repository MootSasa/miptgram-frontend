import 'package:flutter/material.dart';

class CreateChatScreen extends StatelessWidget {
  const CreateChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
      ),
      body: ListView(
        children: [
          _buildChatOption(
            context,
            icon: Icons.person_outline,
            title: 'Private Chat',
            subtitle: 'Chat with one other person',
            onTap: () {
              // Navigate to private chat creation (e.g., contact selection)
              Navigator.of(context).pushNamed('/private_chat/create');
            },
          ),
          _buildChatOption(
            context,
            icon: Icons.people_outline,
            title: 'Group Chat',
            subtitle: 'Chat with multiple people',
            onTap: () {
              // Navigate to group chat creation
              Navigator.of(context).pushNamed('/group_chat/create');
            },
          ),
          _buildChatOption(
            context,
            icon: Icons.campaign_outlined,
            title: 'Channel',
            subtitle: 'Broadcast to unlimited followers',
            onTap: () {
              // Navigate to channel creation
              Navigator.of(context).pushNamed('/channel/create');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 28),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}