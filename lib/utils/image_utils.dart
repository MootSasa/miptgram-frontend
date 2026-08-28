import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Validates and returns a valid avatar URL or local file path, or null if invalid
///
/// This function checks if the URL is a valid HTTP/HTTPS URL, data: URL, or local file path
/// to prevent "No host specified in URI" errors when using NetworkImage
String? getValidAvatarUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  // data: URLs are valid (base64 encoded avatars)
  if (url.startsWith('data:')) return url;
  
  // Local file path or file:// URI
  if (url.startsWith('file://')) {
    final file = File(Uri.parse(url).toFilePath());
    if (file.existsSync()) return url;
  } else if (url.startsWith('/') || url.contains(':\\') || url.contains(':/')) {
    final file = File(url);
    if (file.existsSync()) return url;
  }
  
  try {
    final uri = Uri.parse(url);
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return url;
    }
    // Fallback: check if local file path without scheme
    final file = File(url);
    if (file.existsSync()) return url;
    return null;
  } catch (e) {
    // Check if it's a valid local file path even if URI parsing failed
    try {
      final file = File(url);
      if (file.existsSync()) return url;
    } catch (_) {}
    return null;
  }
}

/// Creates an ImageProvider from an avatar URL or local file path.
/// Supports network URLs (http/https), local file paths, and data: URLs (base64).
/// Returns null if the URL is invalid.
ImageProvider? avatarImageProvider(String? url) {
  if (url == null || url.isEmpty) return null;

  // Handle data: URLs (base64 encoded avatars stored in DB)
  if (url.startsWith('data:')) {
    try {
      final commaIndex = url.indexOf(',');
      if (commaIndex == -1) return null;
      final base64Str = url.substring(commaIndex + 1);
      final bytes = base64Decode(base64Str);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  // Handle local file paths or file:// URIs
  if (url.startsWith('file://')) {
    try {
      final file = File(Uri.parse(url).toFilePath());
      if (file.existsSync()) return FileImage(file);
    } catch (_) {}
  }
  
  final localFile = File(url);
  if (localFile.existsSync()) {
    return FileImage(localFile);
  }

  // Regular network URL
  final validUrl = getValidAvatarUrl(url);
  if (validUrl == null) return null;
  return NetworkImage(validUrl);
}

/// Creates a CircleAvatar with proper error handling for avatar URLs and local file paths
/// 
/// If the URL is invalid or empty, displays initials instead
Widget buildAvatar({
  required String? avatarUrl,
  required String name,
  double radius = 20,
  Color backgroundColor = const Color(0xFF0088CC),
}) {
  final provider = avatarImageProvider(avatarUrl);
  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    backgroundImage: provider,
    child: provider == null
        ? Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          )
        : null,
  );
}
