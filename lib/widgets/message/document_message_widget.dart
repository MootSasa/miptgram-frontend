import 'dart:io' show Platform, File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;

enum DownloadStatus { idle, downloading, downloaded, failed }

class DocumentMessageWidget extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final double fileSize; // in bytes

  const DocumentMessageWidget({
    Key? key,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
  }) : super(key: key);

  @override
  State<DocumentMessageWidget> createState() => _DocumentMessageWidgetState();
}

class _DocumentMessageWidgetState extends State<DocumentMessageWidget> {
  DownloadStatus _status = DownloadStatus.idle;
  double _progress = 0.0;
  String? _downloadedFilePath;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _status == DownloadStatus.downloaded ? _showFileOptions : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, size: 40, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(widget.fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_status == DownloadStatus.downloading) {
      return SizedBox(
        width: 80,
        height: 30,
        child: Stack(
          children: [
            CircularProgressIndicator(
              value: _progress,
              strokeWidth: 2.0,
            ),
            Center(
              child: Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_status == DownloadStatus.failed) {
      return ElevatedButton.icon(
        onPressed: _startDownload,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          textStyle: const TextStyle(fontSize: 12),
        ),
      );
    } else if (_status == DownloadStatus.downloaded) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    } else {
      return ElevatedButton.icon(
        onPressed: _startDownload,
        icon: const Icon(Icons.download, size: 16),
        label: const Text('Download'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          textStyle: const TextStyle(fontSize: 12),
        ),
      );
    }
  }

  Future<void> _startDownload() async {
      setState(() {
        _status = DownloadStatus.downloading;
        _progress = 0.0;
      });
  
      try {
        if (kIsWeb) {
          await _downloadWeb();
        } else {
          await _downloadWithProgress();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = DownloadStatus.failed;
            _progress = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: ${e.toString()}')),
          );
        }
      }
    }
  
    Future<void> _downloadWeb() async {
      // For web, trigger download via anchor tag
      web.HTMLAnchorElement()
        ..href = widget.fileUrl
        ..setAttribute('download', widget.fileName)
        ..click();
  
      // Show notification that download started
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download started for ${widget.fileName}')),
        );
        // Reset state since we can't track progress in web
        setState(() {
          _status = DownloadStatus.idle;
          _progress = 0.0;
        });
      }
    }

  Future<void> _downloadWithProgress() async {
    final request = http.Request('GET', Uri.parse(widget.fileUrl));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    final contentLength = response.contentLength;
    final dir = await _getSaveDirectory();
    final file = File('${dir.path}/${widget.fileName}');

    final sink = file.openWrite();
    int totalBytes = 0;

    await for (final List<int> chunk in response.stream) {
      totalBytes += chunk.length;
      final progress = contentLength != null
          ? totalBytes / contentLength
          : 0.0; // Indeterminate if no content length

      if (mounted) {
        setState(() {
          _progress = progress;
        });
      }

      sink.add(chunk);
    }

    await sink.close();

    if (mounted) {
      setState(() {
        _status = DownloadStatus.downloaded;
        _progress = 1.0;
        _downloadedFilePath = file.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл скачан. Нажмите на файл, чтобы открыть.')),
      );
    }
  }

  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        throw Exception('Could not get external storage directory');
      }
      return dir;
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      // For Linux, Windows, macOS
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        throw Exception('Could not get downloads directory');
      }
      return dir;
    }
  }

  Future<void> _openDownloadedFile() async {
    if (_downloadedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not downloaded yet')),
      );
      return;
    }

    try {
      final result = await OpenFile.open(_downloadedFilePath);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  void _showFileOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Открыть файл'),
              onTap: () {
                Navigator.pop(context);
                _openDownloadedFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Поделиться'),
              onTap: () {
                Navigator.pop(context);
                _shareFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text('Показать в папке: $_downloadedFilePath'),
              onTap: () {
                Navigator.pop(context);
                _showInFolder();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Share the downloaded file using the system share sheet
  Future<void> _shareFile() async {
    if (_downloadedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала скачайте файл')),
      );
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: widget.fileName,
          files: [XFile(_downloadedFilePath!)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при отправке: $e')),
        );
      }
    }
  }

  /// Show the downloaded file in the system file manager
  Future<void> _showInFolder() async {
    if (_downloadedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала скачайте файл')),
      );
      return;
    }
    try {
      // open_file can open the file, but to show in folder we use
      // the system's file manager via open_file with "folder" mode
      final result = await OpenFile.open(_downloadedFilePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}