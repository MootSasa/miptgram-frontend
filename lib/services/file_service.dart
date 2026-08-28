import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Service for handling file operations with MinIO backend
class FileService {
  final Dio _dio;
  final String baseUrl;

  FileService({
    String? baseUrl,
  })  : baseUrl = baseUrl ?? AppConfig.baseUrl,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ));

  /// Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Upload a file to the server
  ///
  /// [file] - The file to upload
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  Future<UploadResult> uploadFile(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final fileName = path.basename(file.path);
    final fileLength = await file.length();
    
    // Determine mime type from file extension
    final mimeType = _getMimeType(fileName);
    
    final formData = FormData.fromMap({
      'file': MultipartFile.fromStream(
        () => file.openRead(),
        fileLength,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    });

    try {
      final headers = await _getHeaders();
      final response = await _dio.post(
        '$baseUrl/api/files/upload',
        data: formData,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return UploadResult.fromJson(response.data);
      } else {
        throw FileUploadException(
          response.data['message'] ?? 'Upload failed',
        );
      }
    } on DioException catch (e) {
      throw FileUploadException(
        e.response?.data?['message'] ?? 'Upload failed: ${e.message}',
      );
    }
  }

  /// Get a presigned URL for direct upload to MinIO
  Future<PresignedUrlResult> getPresignedUploadUrl(
    String fileName,
    String contentType,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.post(
        '$baseUrl/api/files/upload-presigned',
        data: {
          'file_name': fileName,
          'content_type': contentType,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return PresignedUrlResult.fromJson(response.data);
      } else {
        throw FileUploadException(
          response.data['message'] ?? 'Failed to get upload URL',
        );
      }
    } on DioException catch (e) {
      throw FileUploadException(
        e.response?.data?['message'] ?? 'Failed to get upload URL: ${e.message}',
      );
    }
  }

  /// Upload file directly to MinIO using presigned URL
  Future<void> uploadToPresignedUrl(
    String presignedUrl,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final fileStream = file.openRead();
    final fileLength = await file.length();
    final fileName = path.basename(file.path);
    final mimeType = _getMimeType(fileName);

    try {
      await _dio.put(
        presignedUrl,
        data: fileStream,
        options: Options(
          headers: {
            'Content-Type': mimeType,
            'Content-Length': fileLength.toString(),
          },
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );
    } on DioException catch (e) {
      throw FileUploadException('Direct upload failed: ${e.message}');
    }
  }

  /// Get a presigned URL for downloading a file
  Future<String> getPresignedDownloadUrl(String objectName) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '$baseUrl/api/files/download-presigned/$objectName',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['download_url'];
      } else {
        throw FileDownloadException(
          response.data['message'] ?? 'Failed to get download URL',
        );
      }
    } on DioException catch (e) {
      throw FileDownloadException(
        e.response?.data?['message'] ?? 'Failed to get download URL: ${e.message}',
      );
    }
  }

  /// Download a file from the server
  Future<File> downloadFile(
    String objectName,
    String savePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final headers = await _getHeaders();
      await _dio.download(
        '$baseUrl/api/files/download/$objectName',
        savePath,
        options: Options(headers: headers),
        onReceiveProgress: (received, total) {
          if (onProgress != null && total > 0) {
            onProgress(received / total);
          }
        },
      );
      return File(savePath);
    } on DioException catch (e) {
      throw FileDownloadException('Download failed: ${e.message}');
      }
    }
  
    /// Download a file to the default downloads directory
    /// Returns the path where the file was saved
    Future<String> downloadToDownloads(
      String objectName,
      String fileName, {
      String? customDownloadPath,
      void Function(double progress)? onProgress,
    }) async {
      try {
        // Get download directory
        String downloadDir;
        if (customDownloadPath != null && customDownloadPath.isNotEmpty) {
          downloadDir = customDownloadPath;
        } else {
          // Use default downloads directory
          final defaultDir = await _getDefaultDownloadDirectory();
          downloadDir = defaultDir;
        }
  
        // Ensure directory exists
        final dir = Directory(downloadDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
  
        // Generate unique filename if file already exists
        String finalPath = path.join(downloadDir, fileName);
        final file = File(finalPath);
        if (await file.exists()) {
          final ext = path.extension(fileName);
          final nameWithoutExt = path.basenameWithoutExtension(fileName);
          int counter = 1;
          while (await File(finalPath).exists()) {
            finalPath = path.join(downloadDir, '${nameWithoutExt}_$counter$ext');
            counter++;
          }
        }
  
        // Download file
        await downloadFile(objectName, finalPath, onProgress: onProgress);
        return finalPath;
      } catch (e) {
        throw FileDownloadException('Failed to download to downloads: $e');
      }
    }
  
    /// Get default download directory based on platform
    Future<String> _getDefaultDownloadDirectory() async {
      // For mobile platforms, use the app's documents directory
      // For desktop, use the system Downloads folder
      if (Platform.isAndroid || Platform.isIOS) {
        // Use app documents directory
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          return directory.path;
        }
        // Fallback to app documents
        final appDir = Directory.systemTemp;
        return path.join(appDir.path, 'Downloads');
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        return path.join(home, 'Downloads');
      } else if (Platform.isMacOS) {
        final home = Platform.environment['HOME'] ?? '';
        return path.join(home, 'Downloads');
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        return path.join(userProfile, 'Downloads');
      }
      // Fallback
      return Directory.systemTemp.path;
    }
  
    /// Open a file with the system's default application
    Future<void> openFile(String filePath) async {
      try {
        final file = File(filePath);
        if (!await file.exists()) {
          throw FileOpenException('File does not exist: $filePath');
        }
  
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          throw FileOpenException('Failed to open file: ${result.message}');
        }
      } catch (e) {
        if (e is FileOpenException) rethrow;
        throw FileOpenException('Failed to open file: $e');
      }
    }
  
    /// Download and open a file
    /// Downloads the file to downloads directory and opens it
    Future<String> downloadAndOpen(
      String objectName,
      String fileName, {
      String? customDownloadPath,
      void Function(double progress)? onProgress,
    }) async {
      // Download file
      final filePath = await downloadToDownloads(
        objectName,
        fileName,
        customDownloadPath: customDownloadPath,
        onProgress: onProgress,
      );
  
      // Open file
      await openFile(filePath);
  
      return filePath;
    }

  /// Delete a file from the server
  Future<void> deleteFile(String objectName) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.delete(
        '$baseUrl/api/files/$objectName',
        options: Options(headers: headers),
      );

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw FileDeleteException(
          response.data['message'] ?? 'Delete failed',
        );
      }
    } on DioException catch (e) {
      throw FileDeleteException(
        e.response?.data?['message'] ?? 'Delete failed: ${e.message}',
      );
    }
  }

  /// Upload an avatar image
  Future<String> uploadAvatar(File file) async {
    final fileName = path.basename(file.path);
    final fileLength = await file.length();
    final mimeType = _getMimeType(fileName);

    final formData = FormData.fromMap({
      'avatar': MultipartFile.fromStream(
        () => file.openRead(),
        fileLength,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    });

    try {
      final headers = await _getHeaders();
      final response = await _dio.post(
        '$baseUrl/api/files/upload-avatar',
        data: formData,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['avatar_url'];
      } else {
        throw FileUploadException(
          response.data['message'] ?? 'Avatar upload failed',
        );
      }
    } on DioException catch (e) {
      throw FileUploadException(
        e.response?.data?['message'] ?? 'Avatar upload failed: ${e.message}',
      );
    }
  }

  /// Get mime type from file extension
  String _getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    final mimeTypes = {
      // Images
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.heic': 'image/heic',
      '.heif': 'image/heif',
      '.svg': 'image/svg+xml',
      '.bmp': 'image/bmp',
      '.tiff': 'image/tiff',
      '.tif': 'image/tiff',
      // Videos
      '.mp4': 'video/mp4',
      '.webm': 'video/webm',
      '.mov': 'video/quicktime',
      '.avi': 'video/x-msvideo',
      '.3gp': 'video/3gpp',
      '.mkv': 'video/x-matroska',
      // Audio
      '.mp3': 'audio/mpeg',
      '.ogg': 'audio/ogg',
      '.wav': 'audio/wav',
      '.m4a': 'audio/mp4',
      '.aac': 'audio/aac',
      '.opus': 'audio/opus',
      '.flac': 'audio/flac',
      '.amr': 'audio/amr',
      // Documents
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      // Archives
      '.zip': 'application/zip',
      '.rar': 'application/x-rar-compressed',
      '.7z': 'application/x-7z-compressed',
      '.gz': 'application/gzip',
      '.tar': 'application/gzip',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }
}

/// Result of a file upload operation
class UploadResult {
  final int fileId;
  final String objectName;
  final String url;
  final String fileName;
  final String mimeType;
  final int size;

  UploadResult({
    required this.fileId,
    required this.objectName,
    required this.url,
    required this.fileName,
    required this.mimeType,
    required this.size,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      fileId: json['file_id'] ?? 0,
      objectName: json['object_name'] ?? '',
      url: json['url'] ?? '',
      fileName: json['file_name'] ?? '',
      mimeType: json['mime_type'] ?? '',
      size: json['size'] ?? 0,
    );
  }
}

/// Result of getting a presigned URL
class PresignedUrlResult {
  final String uploadUrl;
  final String objectName;
  final int expiresIn;

  PresignedUrlResult({
    required this.uploadUrl,
    required this.objectName,
    required this.expiresIn,
  });

  factory PresignedUrlResult.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResult(
      uploadUrl: json['upload_url'] ?? '',
      objectName: json['object_name'] ?? '',
      expiresIn: json['expires_in'] ?? 0,
    );
  }
}

/// Exception thrown during file upload
class FileUploadException implements Exception {
  final String message;
  FileUploadException(this.message);
  
  @override
  String toString() => 'FileUploadException: $message';
}

/// Exception thrown during file download
class FileDownloadException implements Exception {
  final String message;
  FileDownloadException(this.message);
  
  @override
  String toString() => 'FileDownloadException: $message';
}

/// Exception thrown during file deletion
class FileDeleteException implements Exception {
  final String message;
  FileDeleteException(this.message);

  @override
  String toString() => 'FileDeleteException: $message';
}

/// Exception thrown during file open
class FileOpenException implements Exception {
  final String message;
  FileOpenException(this.message);

  @override
  String toString() => 'FileOpenException: $message';
}
