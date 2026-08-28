import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/app_config.dart';

/// SearchResultUser represents a user in search results.
class SearchResultUser {
  final String id;
  final String name;
  final String email;
  final String username;
  final String? avatarUrl;

  SearchResultUser({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    this.avatarUrl,
  });

  factory SearchResultUser.fromJson(Map<String, dynamic> json) {
    return SearchResultUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

/// SearchResultGroup represents a group in search results.
class SearchResultGroup {
  final String id;
  final String name;
  final String description;

  SearchResultGroup({
    required this.id,
    required this.name,
    required this.description,
  });

  factory SearchResultGroup.fromJson(Map<String, dynamic> json) {
    return SearchResultGroup(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

/// SearchResultChannel represents a channel in search results.
class SearchResultChannel {
  final String id;
  final String name;
  final String description;
  final String groupId;

  SearchResultChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.groupId,
  });

  factory SearchResultChannel.fromJson(Map<String, dynamic> json) {
    return SearchResultChannel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      groupId: json['group_id'] ?? '',
    );
  }
}

/// SearchResultMessage represents a message in search results.
class SearchResultMessage {
  final String id;
  final String content;
  final String userId;
  final String channelId;
  final String groupId;
  final DateTime createdAt;

  SearchResultMessage({
    required this.id,
    required this.content,
    required this.userId,
    required this.channelId,
    required this.groupId,
    required this.createdAt,
  });

  factory SearchResultMessage.fromJson(Map<String, dynamic> json) {
    return SearchResultMessage(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      userId: json['user_id'] ?? '',
      channelId: json['channel_id'] ?? '',
      groupId: json['group_id'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

/// SearchService provides search functionality for users, groups, channels, and messages.
class SearchService {
  // Base URL is now managed by AppConfig

  /// Searches for users matching the query.
  /// 
  /// [query] - The search query string.
  /// [limit] - Maximum number of results to return (default: 20).
  /// Returns a list of [SearchResultUser] objects.
  static Future<List<SearchResultUser>> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final token = await AuthService.getToken();
      if (AppConfig.enableDebugLogging) {
        debugPrint('SearchService: Searching for "$query" with token: ${token != null ? "present" : "null"}');
      }
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/search/users?query=${Uri.encodeComponent(query)}&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
  
      if (AppConfig.enableDebugLogging) {
        debugPrint('SearchService: Response ${response.statusCode}: ${response.body}');
      }
  
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['users'] != null) {
          return (data['users'] as List)
              .map((json) => SearchResultUser.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Searches for groups matching the query.
  /// 
  /// [query] - The search query string.
  /// [limit] - Maximum number of results to return (default: 20).
  /// Returns a list of [SearchResultGroup] objects.
  static Future<List<SearchResultGroup>> searchGroups({
    required String query,
    int limit = 20,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/search/groups?query=${Uri.encodeComponent(query)}&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['groups'] != null) {
          return (data['groups'] as List)
              .map((json) => SearchResultGroup.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error searching groups: $e');
      return [];
    }
  }

  /// Searches for channels matching the query.
  /// 
  /// [query] - The search query string.
  /// [limit] - Maximum number of results to return (default: 20).
  /// Returns a list of [SearchResultChannel] objects.
  static Future<List<SearchResultChannel>> searchChannels({
    required String query,
    int limit = 20,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/search/channels?query=${Uri.encodeComponent(query)}&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['channels'] != null) {
          return (data['channels'] as List)
              .map((json) => SearchResultChannel.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error searching channels: $e');
      return [];
    }
  }

  /// Searches for messages matching the query.
  /// 
  /// [query] - The search query string.
  /// [limit] - Maximum number of results to return (default: 20).
  /// Returns a list of [SearchResultMessage] objects.
  static Future<List<SearchResultMessage>> searchMessages({
    required String query,
    int limit = 20,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/search/messages?query=${Uri.encodeComponent(query)}&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['messages'] != null) {
          return (data['messages'] as List)
              .map((json) => SearchResultMessage.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error searching messages: $e');
      return [];
    }
  }
}
