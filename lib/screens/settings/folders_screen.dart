import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../l10n/app_localizations.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({Key? key}) : super(key: key);

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<String> _folders = [];
  final TextEditingController _folderNameController = TextEditingController();
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    _folders = _settingsService.folders;
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  void _showAddFolderDialog() {
    final l10n = context.l10n;
    
    _folderNameController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('folders_new_folder')),
        content: TextField(
          controller: _folderNameController,
          decoration: InputDecoration(
            hintText: l10n.translate('folders_folder_name'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.translate('folders_cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final folderName = _folderNameController.text.trim();
              if (folderName.isNotEmpty) {
                await _settingsService.addFolder(folderName);
                await _loadFolders();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(l10n.translate('folders_add')),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(String folderName) {
    final l10n = context.l10n;
    
    _folderNameController.text = folderName;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('folders_rename_folder')),
        content: TextField(
          controller: _folderNameController,
          decoration: InputDecoration(
            hintText: l10n.translate('folders_new_folder_name'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.translate('folders_cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _folderNameController.text.trim();
              if (newName.isNotEmpty && newName != folderName) {
                await _settingsService.renameFolder(folderName, newName);
                await _loadFolders();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(l10n.translate('folders_rename')),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderConfirmation(String folderName) {
    final l10n = context.l10n;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('folders_delete_folder')),
        content: Text(l10n.translate('folders_delete_confirm').replaceAll('{folder}', folderName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.translate('folders_cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settingsService.removeFolder(folderName);
              await _loadFolders();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.translate('folders_delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('folders_title')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? Center(
                  child: Text(
                    l10n.translate('folders_empty'),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _folders.length,
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folder),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'rename') {
                            _showRenameFolderDialog(folder);
                          } else if (value == 'delete') {
                            _showDeleteFolderConfirmation(folder);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              leading: const Icon(Icons.edit),
                              title: Text(l10n.translate('folders_rename')),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: const Icon(Icons.delete),
                              title: Text(l10n.translate('folders_delete')),
                              textColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFolderDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
