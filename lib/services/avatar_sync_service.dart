import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_manager.dart';
import 'auth_service.dart';

/// Сервис локального сохранения и бесшовной фоновой загрузки аватарок.
/// 
/// Позволяет немедленно применить несколько выбранных фото профиля локально подряд,
/// сохраняя их во внутреннее хранилище приложения и формируя очередь загрузки.
/// При появлении сети все отложенные фото последовательно загружаются на сервер.
class AvatarSyncService extends ChangeNotifier {
  static final AvatarSyncService _instance = AvatarSyncService._internal();
  factory AvatarSyncService() => _instance;
  AvatarSyncService._internal();

  final AccountManager _accountManager = AccountManager();
  final Set<String> _syncingUsers = {};

  static String _pendingKey(String userId) => 'pending_avatars_$userId';
  static String _historyKey(String userId) => 'local_avatar_history_$userId';

  /// Устанавливает новое фото профиля локально и добавляет его в очередь фоновой загрузки.
  /// Поддерживает добавление нескольких аватарок подряд.
  Future<String> setLocalAvatar(String userId, String sourcePath) async {
    debugPrint('[AvatarSyncService] Setting local avatar for userId=$userId from path=$sourcePath');
    final prefs = await SharedPreferences.getInstance();

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source avatar file does not exist: $sourcePath');
    }

    // 1. Сохраняем файл в постоянную директорию приложения
    final appDir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${appDir.path}/avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }

    final localFileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final permanentFile = File('${avatarsDir.path}/$localFileName');
    await sourceFile.copy(permanentFile.path);

    final permanentPath = permanentFile.path;
    debugPrint('[AvatarSyncService] Saved permanent avatar copy to: $permanentPath');

    // 2. Добавляем путь в очередь отложенной загрузки
    final pendingList = prefs.getStringList(_pendingKey(userId)) ?? [];
    if (!pendingList.contains(permanentPath)) {
      pendingList.add(permanentPath);
      await prefs.setStringList(_pendingKey(userId), pendingList);
    }

    // 3. Обновляем локальную историю аватарок (новейшая первая)
    final historyList = prefs.getStringList(_historyKey(userId)) ?? [];
    historyList.remove(permanentPath);
    historyList.insert(0, permanentPath);
    await prefs.setStringList(_historyKey(userId), historyList);

    // 4. Мгновенно обновляем текущий аватар в AccountManager
    await _accountManager.updateAccountProfile(
      userId,
      avatarUrl: permanentPath,
    );

    notifyListeners();

    // 5. Запускаем фоновую очередированную синхронизацию с сервером
    syncPendingAvatar(userId);

    return permanentPath;
  }

  /// Возвращает список всех несинхронизированных локальных путей аватарок.
  Future<List<String>> getPendingAvatarPaths(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingKey(userId)) ?? [];
    final existing = <String>[];
    for (final p in list) {
      if (await File(p).exists()) {
        existing.add(p);
      }
    }
    return existing;
  }

  /// Возвращает локальную историю аватарок пользователя.
  Future<List<String>> getLocalAvatarUrls(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey(userId)) ?? [];
    final validList = <String>[];
    for (final p in list) {
      if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('data:') || await File(p).exists()) {
        validList.add(p);
      }
    }
    return validList;
  }

  /// Удаляет аватар из локальной истории и очереди.
  Future<void> removeAvatar(String userId, String avatarUrlOrPath) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingList = prefs.getStringList(_pendingKey(userId)) ?? [];
    if (pendingList.remove(avatarUrlOrPath)) {
      await prefs.setStringList(_pendingKey(userId), pendingList);
    }
    final historyList = prefs.getStringList(_historyKey(userId)) ?? [];
    if (historyList.remove(avatarUrlOrPath)) {
      await prefs.setStringList(_historyKey(userId), historyList);
    }
    notifyListeners();
  }

  /// Последовательно синхронизирует все отложенные локальные аватары с сервером.
  Future<void> syncPendingAvatar(String userId) async {
    if (_syncingUsers.contains(userId)) {
      debugPrint('[AvatarSyncService] Sync already in progress for userId=$userId');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> pendingList = prefs.getStringList(_pendingKey(userId)) ?? [];

    if (pendingList.isEmpty) {
      return;
    }

    _syncingUsers.add(userId);
    debugPrint('[AvatarSyncService] Starting background queue upload for userId=$userId (count=${pendingList.length})');

    try {
      while (pendingList.isNotEmpty) {
        final pendingPath = pendingList.first;
        final pendingFile = File(pendingPath);

        if (!await pendingFile.exists()) {
          debugPrint('[AvatarSyncService] Pending file missing, skipping: $pendingPath');
          pendingList.removeAt(0);
          await prefs.setStringList(_pendingKey(userId), pendingList);
          continue;
        }

        debugPrint('[AvatarSyncService] Uploading avatar in queue: $pendingPath');
        final uploadResult = await AuthService.uploadAvatar(pendingPath);
        debugPrint('[AvatarSyncService] uploadAvatar result: $uploadResult');

        if (uploadResult['success'] == true) {
          final remoteAvatarUrl = uploadResult['avatar_url'] as String?;
          if (remoteAvatarUrl != null && remoteAvatarUrl.isNotEmpty) {
            // Удаляем успешно загруженный из очереди
            pendingList.removeAt(0);
            await prefs.setStringList(_pendingKey(userId), pendingList);

            // Обновляем историю: заменяем локальный путь на серверный URL
            final historyList = prefs.getStringList(_historyKey(userId)) ?? [];
            final idx = historyList.indexOf(pendingPath);
            if (idx != -1) {
              historyList[idx] = remoteAvatarUrl;
              await prefs.setStringList(_historyKey(userId), historyList);
            }

            // Если этот аватар был текущим в AccountManager, обновляем его
            final currentAcc = _accountManager.currentAccount;
            if (currentAcc != null && (currentAcc.avatarUrl == pendingPath || pendingList.isEmpty)) {
              await _accountManager.updateAccountProfile(
                userId,
                avatarUrl: remoteAvatarUrl,
              );
            }

            debugPrint('[AvatarSyncService] Successfully synced queued avatar for userId=$userId -> $remoteAvatarUrl');
            notifyListeners();
          } else {
            break;
          }
        } else {
          debugPrint('[AvatarSyncService] Queue upload postponed for userId=$userId: ${uploadResult['message']}');
          break; // При ошибке сети останавливаем цикл до следующего восстановительного триггера
        }
      }
    } catch (e) {
      debugPrint('[AvatarSyncService] Background queue upload exception for userId=$userId: $e');
    } finally {
      _syncingUsers.remove(userId);
    }
  }
}
