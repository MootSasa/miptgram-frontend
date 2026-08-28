import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../services/wallpaper_provider.dart';

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({Key? key}) : super(key: key);

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPreview();
  }

  Future<void> _loadInitialPreview() async {
    final provider = context.read<WallpaperProvider>();
    if (provider.wallpaperPath != null) {
      final file = File(provider.wallpaperPath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    
    setState(() {
      _imageBytes = bytes;
    });
  }

  Future<void> _setWallpaper() async {
    if (_imageBytes == null) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<WallpaperProvider>();
      
      // Get the application documents directory for persistent storage
      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      
      // Create wallpapers directory if it doesn't exist
      if (!await wallpaperDir.exists()) {
        await wallpaperDir.create(recursive: true);
      }

      // Generate a unique filename for the wallpaper
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final wallpaperFile = File('${wallpaperDir.path}/chat_wallpaper_$timestamp.png');

      // Write the new wallpaper
      await wallpaperFile.writeAsBytes(_imageBytes!);

      // Update provider
      await provider.setWallpaper(wallpaperFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallpaper set successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error setting wallpaper: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set wallpaper: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeWallpaper() async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<WallpaperProvider>();
      await provider.removeWallpaper();

      if (mounted) {
        setState(() {
          _imageBytes = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallpaper removed successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error removing wallpaper: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove wallpaper: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallpaperPath = context.watch<WallpaperProvider>().wallpaperPath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpaper'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Image preview
                  Expanded(
                    child: _imageBytes != null
                        ? Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No wallpaper selected',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  // Pick image button
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose from Gallery'),
                  ),
                  const SizedBox(height: 16),
                  // Set wallpaper button
                  ElevatedButton(
                    onPressed: _imageBytes == null ? null : _setWallpaper,
                    child: const Text('Set as Wallpaper'),
                  ),
                  if (wallpaperPath != null) ...[
                    const SizedBox(height: 16),
                    // Remove wallpaper button
                    TextButton.icon(
                      onPressed: _removeWallpaper,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Remove Wallpaper',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
