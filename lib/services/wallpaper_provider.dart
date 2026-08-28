import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperProvider extends ChangeNotifier {
  static const String _wallpaperPathKey = 'chat_wallpaper_path';
  String? _wallpaperPath;

  String? get wallpaperPath => _wallpaperPath;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _wallpaperPath = prefs.getString(_wallpaperPathKey);
    
    if (_wallpaperPath != null) {
      if (!await File(_wallpaperPath!).exists()) {
        _wallpaperPath = null;
        await prefs.remove(_wallpaperPathKey);
      }
    }
    notifyListeners();
  }

  Future<void> setWallpaper(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wallpaperPathKey, path);
    _wallpaperPath = path;
    notifyListeners();
  }

  Future<void> removeWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    if (_wallpaperPath != null) {
      final file = File(_wallpaperPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await prefs.remove(_wallpaperPathKey);
    _wallpaperPath = null;
    notifyListeners();
  }
}
