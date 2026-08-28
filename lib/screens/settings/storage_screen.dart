import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/settings_service.dart';
import '../../services/auth_service.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';

/// Экран «Данные и хранилище» — реальный подсчёт, Keep Media, очистка кэша
class StorageScreen extends StatefulWidget {
  const StorageScreen({Key? key}) : super(key: key);

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final SettingsService _settingsService = SettingsService();
  late StorageSettings _autoDownloadSettings;
  bool _isLoading = true;

  // Real storage data from server
  String _totalUsed = '0 B';
  int _totalUsedBytes = 0;
  List<_MediaTypeStorage> _byType = [];
  List<_ChatStorage> _byChat = [];

  // Storage settings from server
  StorageServerSettings _storageSettings = const StorageServerSettings();
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _autoDownloadSettings = _settingsService.storageSettings;
    await _loadStorageInfo();
    await _loadStorageSettings();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStorageInfo() async {
    try {
      final token = await AuthService.getToken();
      final dio = Dio();
      final response = await dio.get(
        '${AppConfig.baseUrl}/api/settings/storage',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        setState(() {
          _totalUsed = response.data['total_human'] ?? '0 B';
          _totalUsedBytes = response.data['total_used'] ?? 0;
          _byType = (response.data['by_type'] as List?)
                  ?.map((e) => _MediaTypeStorage.fromJson(e))
                  .toList() ??
              [];
          _byChat = (response.data['by_chat'] as List?)
                  ?.map((e) => _ChatStorage.fromJson(e))
                  .toList() ??
              [];
        });
      }
    } catch (e) {
      debugPrint('StorageScreen: loadStorageInfo: $e');
    }
  }

  Future<void> _loadStorageSettings() async {
    try {
      final token = await AuthService.getToken();
      final dio = Dio();
      final response = await dio.get(
        '${AppConfig.baseUrl}/api/settings/storage/settings',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        setState(() {
          _storageSettings = StorageServerSettings.fromJson(response.data);
        });
      }
    } catch (e) {
      debugPrint('StorageScreen: loadStorageSettings: $e');
    }
  }

  Future<void> _saveStorageSettings(StorageServerSettings settings) async {
    try {
      final token = await AuthService.getToken();
      final dio = Dio();
      await dio.put(
        '${AppConfig.baseUrl}/api/settings/storage/settings',
        data: settings.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _storageSettings = settings);
    } catch (e) {
      debugPrint('StorageScreen: saveStorageSettings: $e');
    }
  }

  Future<void> _clearCache({String? mediaType, String? chatId}) async {
    final l10n = context.l10n;
    setState(() => _isClearing = true);

    try {
      final token = await AuthService.getToken();
      final dio = Dio();
      await dio.post(
        '${AppConfig.baseUrl}/api/settings/storage/clear',
        data: {
          if (mediaType != null) 'media_type': mediaType,
          if (chatId != null) 'chat_id': chatId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('storage_clear_success'))),
        );
        await _loadStorageInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _showClearAllDialog() {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('storage_clear_cache_title')),
        content: Text(l10n.translate('storage_clear_cache_message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.translate('storage_cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache();
            },
            child: Text(l10n.translate('storage_clear'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog(_ChatStorage chat) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('storage_clear_chat_cache_title').replaceAll('{chat}', chat.chatName)),
        content: Text(l10n.translate('storage_clear_chat_cache_message')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.translate('storage_cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache(chatId: chat.chatId);
            },
            child: Text(l10n.translate('storage_clear'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearByTypeDialog(_MediaTypeStorage media) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('storage_clear_type_title').replaceAll('{type}', _mediaTypeLabel(l10n, media.mediaType))),
        content: Text(l10n.translate('storage_clear_type_message').replaceAll('{size}', media.sizeHuman)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.translate('storage_cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache(mediaType: media.mediaType);
            },
            child: Text(l10n.translate('storage_clear'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showKeepMediaPicker(String field, String currentValue) {
    final l10n = context.l10n;
    final options = ['forever', '1year', '6months', '1month', '1week'];
    final labels = {
      'forever': l10n.translate('storage_keep_forever'),
      '1year': l10n.translate('storage_keep_1year'),
      '6months': l10n.translate('storage_keep_6months'),
      '1month': l10n.translate('storage_keep_1month'),
      '1week': l10n.translate('storage_keep_1week'),
    };
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) => ListTile(
          title: Text(labels[opt] ?? opt),
          trailing: currentValue == opt ? const Icon(Icons.check) : null,
          onTap: () {
            final newSettings = _storageSettings.copyWithField(field, opt);
            _saveStorageSettings(newSettings);
            Navigator.pop(ctx);
          },
        )).toList(),
      ),
    );
  }

  Future<void> _selectDownloadPath() async {
    final l10n = context.l10n;
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      await _settingsService.updateDownloadPath(selectedDirectory);
      setState(() => _autoDownloadSettings = _settingsService.storageSettings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('storage_download_path_set')}: $selectedDirectory')),
        );
      }
    }
  }

  Future<void> _updateAutoDownload({
    bool? photosWifi, bool? videosWifi, bool? filesWifi, bool? audioWifi,
    bool? photosCellular, bool? videosCellular, bool? filesCellular, bool? audioCellular,
    bool? photosRoaming, bool? videosRoaming, bool? filesRoaming, bool? audioRoaming,
  }) async {
    await _settingsService.updateAutoDownloadSettings(
      photosWifi: photosWifi, videosWifi: videosWifi, filesWifi: filesWifi, audioWifi: audioWifi,
      photosCellular: photosCellular, videosCellular: videosCellular, filesCellular: filesCellular, audioCellular: audioCellular,
      photosRoaming: photosRoaming, videosRoaming: videosRoaming, filesRoaming: filesRoaming, audioRoaming: audioRoaming,
    );
    setState(() => _autoDownloadSettings = _settingsService.storageSettings);
  }

  IconData _mediaTypeIcon(String type) => switch (type) {
    'photos' => Icons.photo,
    'videos' => Icons.videocam,
    'files' => Icons.insert_drive_file,
    'audio' => Icons.audiotrack,
    'stickers' => Icons.emoji_emotions,
    _ => Icons.folder,
  };

  String _mediaTypeLabel(AppLocalizations l10n, String type) => switch (type) {
    'photos' => l10n.translate('storage_photos'),
    'videos' => l10n.translate('storage_videos'),
    'files' => l10n.translate('storage_files'),
    'audio' => l10n.translate('storage_audio'),
    'stickers' => l10n.translate('storage_stickers'),
    _ => type,
  };

  String _keepLabel(AppLocalizations l10n, String value) => switch (value) {
    'forever' => l10n.translate('storage_keep_forever'),
    '1year' => l10n.translate('storage_keep_1year'),
    '6months' => l10n.translate('storage_keep_6months'),
    '1month' => l10n.translate('storage_keep_1month'),
    '1week' => l10n.translate('storage_keep_1week'),
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('storage_title'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
              ListView(children: [
                // === Storage Usage ===
                _sectionHeader(l10n.translate('storage_storage')),
                ListTile(
                  title: Text(l10n.translate('storage_total_used')),
                  trailing: Text(_totalUsed, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ),
                // By type
                for (final mt in _byType)
                  ListTile(
                    leading: Icon(_mediaTypeIcon(mt.mediaType)),
                    title: Text(_mediaTypeLabel(l10n, mt.mediaType)),
                    subtitle: Text('${mt.fileCount} ${l10n.translate('storage_files_count')}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(mt.sizeHuman),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _showClearByTypeDialog(mt)),
                    ]),
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(l10n.translate('storage_clear_cache')),
                  onTap: _showClearAllDialog,
                ),

                const Divider(height: 32),

                // === Keep Media ===
                _sectionHeader(l10n.translate('storage_keep_media_section')),
                _keepMediaTile(l10n, l10n.translate('storage_photos'), 'keep_photos', _storageSettings.keepPhotos),
                _keepMediaTile(l10n, l10n.translate('storage_videos'), 'keep_videos', _storageSettings.keepVideos),
                _keepMediaTile(l10n, l10n.translate('storage_files'), 'keep_files', _storageSettings.keepFiles),
                _keepMediaTile(l10n, l10n.translate('storage_audio'), 'keep_audio', _storageSettings.keepAudio),
                _keepMediaTile(l10n, l10n.translate('storage_stickers'), 'keep_stickers', _storageSettings.keepStickers),

                const Divider(height: 32),

                // === Additional Settings ===
                _sectionHeader(l10n.translate('storage_additional_section')),
                SwitchListTile(
                  title: Text(l10n.translate('storage_compress_images')),
                  subtitle: Text(l10n.translate('storage_compress_images_desc')),
                  value: _storageSettings.compressImages,
                  onChanged: (v) => _saveStorageSettings(_storageSettings.copyWithField('compress_images', v)),
                ),
                SwitchListTile(
                  title: Text(l10n.translate('storage_auto_download_stickers')),
                  value: _storageSettings.autoDownloadStickers,
                  onChanged: (v) => _saveStorageSettings(_storageSettings.copyWithField('auto_download_stickers', v)),
                ),
                SwitchListTile(
                  title: Text(l10n.translate('storage_suggest_stickers')),
                  value: _storageSettings.suggestStickers,
                  onChanged: (v) => _saveStorageSettings(_storageSettings.copyWithField('suggest_stickers', v)),
                ),
                SwitchListTile(
                  title: Text(l10n.translate('storage_suggest_emoji')),
                  value: _storageSettings.suggestEmoji,
                  onChanged: (v) => _saveStorageSettings(_storageSettings.copyWithField('suggest_emoji', v)),
                ),

                const Divider(height: 32),

                // === Chats ===
                _sectionHeader(l10n.translate('storage_chats')),
                for (final chat in _byChat)
                  ListTile(
                    leading: const Icon(Icons.chat),
                    title: Text(chat.chatName),
                    subtitle: Text('${chat.fileCount} ${l10n.translate('storage_files_count')}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(chat.sizeHuman),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _showClearChatDialog(chat)),
                    ]),
                  ),

                const Divider(height: 32),

                // === Auto-download ===
                ExpansionTile(
                  title: Text(l10n.translate('storage_auto_download')),
                  children: [
                    _autoDownloadSection(l10n, l10n.translate('storage_on_wifi'), wifi: true),
                    _autoDownloadSection(l10n, l10n.translate('storage_on_cellular'), cellular: true),
                    _autoDownloadSection(l10n, l10n.translate('storage_on_roaming'), roaming: true),
                  ],
                ),

                // Download path
                ListTile(
                  title: Text(l10n.translate('storage_download_path')),
                  subtitle: Text(_autoDownloadSettings.downloadPath ?? l10n.translate('storage_download_path_default')),
                  trailing: const Icon(Icons.folder),
                  onTap: _selectDownloadPath,
                ),
              ]),
              if (_isClearing)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ]),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _keepMediaTile(AppLocalizations l10n, String title, String field, String value) {
    return ListTile(
      title: Text(title),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_keepLabel(l10n, value), style: TextStyle(color: Colors.grey[600])),
        const Icon(Icons.chevron_right),
      ]),
      onTap: () => _showKeepMediaPicker(field, value),
    );
  }

  Widget _autoDownloadSection(AppLocalizations l10n, String title, {bool wifi = false, bool cellular = false, bool roaming = false}) {
    return ExpansionTile(
      title: Text(title),
      children: [
        ListTile(title: Text(l10n.translate('storage_photos')), trailing: Switch(
          value: wifi ? _autoDownloadSettings.autoDownloadPhotosOnWifi : cellular ? _autoDownloadSettings.autoDownloadPhotosOnCellular : _autoDownloadSettings.autoDownloadPhotosOnRoaming,
          onChanged: (v) => _updateAutoDownload(photosWifi: wifi ? v : null, photosCellular: cellular ? v : null, photosRoaming: roaming ? v : null),
        )),
        ListTile(title: Text(l10n.translate('storage_videos')), trailing: Switch(
          value: wifi ? _autoDownloadSettings.autoDownloadVideosOnWifi : cellular ? _autoDownloadSettings.autoDownloadVideosOnCellular : _autoDownloadSettings.autoDownloadVideosOnRoaming,
          onChanged: (v) => _updateAutoDownload(videosWifi: wifi ? v : null, videosCellular: cellular ? v : null, videosRoaming: roaming ? v : null),
        )),
        ListTile(title: Text(l10n.translate('storage_files')), trailing: Switch(
          value: wifi ? _autoDownloadSettings.autoDownloadFilesOnWifi : cellular ? _autoDownloadSettings.autoDownloadFilesOnCellular : _autoDownloadSettings.autoDownloadFilesOnRoaming,
          onChanged: (v) => _updateAutoDownload(filesWifi: wifi ? v : null, filesCellular: cellular ? v : null, filesRoaming: roaming ? v : null),
        )),
        ListTile(title: Text(l10n.translate('storage_audio')), trailing: Switch(
          value: wifi ? _autoDownloadSettings.autoDownloadAudioOnWifi : cellular ? _autoDownloadSettings.autoDownloadAudioOnCellular : _autoDownloadSettings.autoDownloadAudioOnRoaming,
          onChanged: (v) => _updateAutoDownload(audioWifi: wifi ? v : null, audioCellular: cellular ? v : null, audioRoaming: roaming ? v : null),
        )),
      ],
    );
  }
}

// ============ Data Models ============

class _MediaTypeStorage {
  final String mediaType;
  final int sizeBytes;
  final int fileCount;
  final String sizeHuman;

  _MediaTypeStorage({required this.mediaType, required this.sizeBytes, required this.fileCount, required this.sizeHuman});

  factory _MediaTypeStorage.fromJson(Map<String, dynamic> json) => _MediaTypeStorage(
    mediaType: json['media_type'] ?? '',
    sizeBytes: json['size_bytes'] ?? 0,
    fileCount: json['file_count'] ?? 0,
    sizeHuman: json['size_human'] ?? '0 B',
  );
}

class _ChatStorage {
  final String chatId;
  final String chatName;
  final int sizeBytes;
  final int fileCount;
  final String sizeHuman;

  _ChatStorage({required this.chatId, required this.chatName, required this.sizeBytes, required this.fileCount, required this.sizeHuman});

  factory _ChatStorage.fromJson(Map<String, dynamic> json) => _ChatStorage(
    chatId: json['chat_id'] ?? '',
    chatName: json['chat_name'] ?? '',
    sizeBytes: json['size_bytes'] ?? 0,
    fileCount: json['file_count'] ?? 0,
    sizeHuman: json['size_human'] ?? '0 B',
  );
}

class StorageServerSettings {
  final String keepPhotos;
  final String keepVideos;
  final String keepFiles;
  final String keepAudio;
  final String keepStickers;
  final bool compressImages;
  final int imageCompressionQuality;
  final bool autoDownloadStickers;
  final bool suggestStickers;
  final bool suggestEmoji;

  const StorageServerSettings({
    this.keepPhotos = 'forever',
    this.keepVideos = 'forever',
    this.keepFiles = 'forever',
    this.keepAudio = 'forever',
    this.keepStickers = 'forever',
    this.compressImages = true,
    this.imageCompressionQuality = 80,
    this.autoDownloadStickers = true,
    this.suggestStickers = true,
    this.suggestEmoji = true,
  });

  factory StorageServerSettings.fromJson(Map<String, dynamic> json) => StorageServerSettings(
    keepPhotos: json['keep_photos'] ?? 'forever',
    keepVideos: json['keep_videos'] ?? 'forever',
    keepFiles: json['keep_files'] ?? 'forever',
    keepAudio: json['keep_audio'] ?? 'forever',
    keepStickers: json['keep_stickers'] ?? 'forever',
    compressImages: json['compress_images'] ?? true,
    imageCompressionQuality: json['image_compression_quality'] ?? 80,
    autoDownloadStickers: json['auto_download_stickers'] ?? true,
    suggestStickers: json['suggest_stickers'] ?? true,
    suggestEmoji: json['suggest_emoji'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'keep_photos': keepPhotos,
    'keep_videos': keepVideos,
    'keep_files': keepFiles,
    'keep_audio': keepAudio,
    'keep_stickers': keepStickers,
    'compress_images': compressImages,
    'image_compression_quality': imageCompressionQuality,
    'auto_download_stickers': autoDownloadStickers,
    'suggest_stickers': suggestStickers,
    'suggest_emoji': suggestEmoji,
  };

  StorageServerSettings copyWithField(String field, dynamic value) {
    return StorageServerSettings(
      keepPhotos: field == 'keep_photos' ? value as String : keepPhotos,
      keepVideos: field == 'keep_videos' ? value as String : keepVideos,
      keepFiles: field == 'keep_files' ? value as String : keepFiles,
      keepAudio: field == 'keep_audio' ? value as String : keepAudio,
      keepStickers: field == 'keep_stickers' ? value as String : keepStickers,
      compressImages: field == 'compress_images' ? value as bool : compressImages,
      imageCompressionQuality: field == 'image_compression_quality' ? value as int : imageCompressionQuality,
      autoDownloadStickers: field == 'auto_download_stickers' ? value as bool : autoDownloadStickers,
      suggestStickers: field == 'suggest_stickers' ? value as bool : suggestStickers,
      suggestEmoji: field == 'suggest_emoji' ? value as bool : suggestEmoji,
    );
  }
}
