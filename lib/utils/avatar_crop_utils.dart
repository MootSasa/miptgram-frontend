import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../l10n/app_localizations.dart';

/// Утилита для обрезки и сжатия аватаров
class AvatarCropUtils {
  /// Максимальный размер аватара в пикселях
  static const int maxAvatarSize = 1024;

  /// Качество сжатия (0-100)
  static const int compressionQuality = 90;

  /// Максимальный размер файла в байтах (2 MB)
  static const int maxFileSizeBytes = 2 * 1024 * 1024;

  /// Обрезает изображение до квадратной формы
  /// 
  /// [imagePath] - путь к исходному изображению
  /// Возвращает путь к обрезанному изображению или null если обрезка отменена
  static Future<CroppedFile?> cropAvatar({
    required String imagePath,
    required BuildContext context,
  }) async {
    debugPrint('[cropAvatar] Step 1: Starting crop for $imagePath');
    final l10n = AppLocalizations.of(context);

    debugPrint('[cropAvatar] Step 2: Calling ImageCropper().cropImage()...');
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      maxWidth: maxAvatarSize,
      maxHeight: maxAvatarSize,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: compressionQuality,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: l10n?.translate('avatar_crop_title') ?? 'Обрезка аватара',
          toolbarColor: const Color(0xFF0088CC),
          statusBarColor: const Color(0xFF006699),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF0088CC),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          showCropGrid: true,
          cropGridColor: Colors.white.withValues(alpha: 0.5),
          cropFrameColor: Colors.white,
          hideBottomControls: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
        ),
        IOSUiSettings(
          title: l10n?.translate('avatar_crop_title') ?? 'Обрезка аватара',
          aspectRatioLockEnabled: true,
          // Добавляем настройки для iOS
          showActivitySheetOnDone: true,
          showCancelConfirmationDialog: true,
          rotateButtonsHidden: false,
          rotateClockwiseButtonHidden: false,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    debugPrint('[cropAvatar] Step 3: cropImage() returned - croppedFile=${croppedFile?.path}');
    return croppedFile;
  }

  /// Сжимает изображение до оптимального размера
  /// 
  /// [imagePath] - путь к исходному изображению
  /// Возвращает путь к сжатому изображению
  static Future<String> compressAvatar(String imagePath) async {
    debugPrint('[compressAvatar] Step 1: Starting compression for $imagePath');
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(
      dir.path,
      'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    // Первичное сжатие
    debugPrint('[compressAvatar] Step 2: First compression pass...');
    final XFile? firstCompressed = await FlutterImageCompress.compressAndGetFile(
      imagePath,
      targetPath,
      quality: compressionQuality,
      minWidth: maxAvatarSize,
      minHeight: maxAvatarSize,
      format: CompressFormat.jpeg,
    );

    if (firstCompressed == null) {
      debugPrint('[compressAvatar] Step 2-warn: First compression returned null, using original');
      return imagePath;
    }

    String compressedPath = firstCompressed.path;
    File file = File(compressedPath);
    int fileSize = await file.length();
    debugPrint('[compressAvatar] Step 2-ok: First compression done, size=$fileSize bytes');

    int quality = compressionQuality;
    while (fileSize > maxFileSizeBytes && quality > 10) {
      quality -= 10;
      
      final newTargetPath = path.join(
        dir.path,
        'avatar_${DateTime.now().millisecondsSinceEpoch}_q$quality.jpg',
      );

      final XFile? newCompressedFile = await FlutterImageCompress.compressAndGetFile(
        compressedPath,
        newTargetPath,
        quality: quality,
        minWidth: maxAvatarSize,
        minHeight: maxAvatarSize,
        format: CompressFormat.jpeg,
      );

      if (newCompressedFile != null) {
        // Удаляем старый сжатый файл
        await file.delete();
        compressedPath = newCompressedFile.path;
        file = File(compressedPath);
        fileSize = await file.length();
      } else {
        break;
      }
    }

    return compressedPath;
  }

  /// Полный пайплайн обработки аватара: обрезка + сжатие
  /// 
  /// [imagePath] - путь к исходному изображению
  /// [context] - контекст для локализации
  /// Возвращает путь к обработанному изображению или null если отменено
  static Future<String?> processAvatar({
    required String imagePath,
    required BuildContext context,
  }) async {
    debugPrint('[processAvatar] Step 1: Starting full pipeline for $imagePath');
    // Шаг 1: Обрезка изображения
    final croppedFile = await cropAvatar(
      imagePath: imagePath,
      context: context,
    );

    if (croppedFile == null) {
      debugPrint('[processAvatar] Step 1-cancel: cropAvatar returned null (user cancelled?)');
      return null;
    }

    debugPrint('[processAvatar] Step 2: Crop done, starting compression for ${croppedFile.path}');
    // Шаг 2: Сжатие изображения
    final compressedPath = await compressAvatar(croppedFile.path);

    debugPrint('[processAvatar] Step 3: Pipeline complete, result=$compressedPath');
    return compressedPath;
  }

  /// Получает размер файла в человекочитаемом формате
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
