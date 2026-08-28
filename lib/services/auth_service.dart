import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../config/app_config.dart';
import 'account_manager.dart';
import 'database/app_database.dart';

/// AuthService handles authentication operations including login, logout,
/// and token management. Integrates with AccountManager for multi-account support.
class AuthService {
  // Base URL is now managed by AppConfig

  /// Registers a new user with username, email, password and display name.
  /// Returns a map containing the auth token and user info on success.
  /// Throws an exception on failure.
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'display_name': displayName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Save to AccountManager
          await _saveToAccountManager(
            data['auth_token'],
            data['user_id'],
            username: username,
            displayName: displayName,
          );
          // Ensure Saved Messages chat exists locally
          try {
            await AppDatabase().ensureSavedChatExists(data['user_id']);
          } catch (e) {
            debugPrint('AuthService: Error creating saved chat: $e');
          }
          return {
            'success': true,
            'authToken': data['auth_token'],
            'userId': data['user_id'],
            'message': data['message'] ?? 'Registration successful',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Registration failed',
          };
        }
      } else {
        // Handle different error codes
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': _getErrorMessage(response.statusCode, data['message']),
        };
      }
    } catch (e) {
      // Network error and other exception
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Logs in a user with username/email and password.
  /// Returns a map containing the auth token and user info on success.
  /// Throws an exception on failure.
  static Future<Map<String, dynamic>> login({
  	required String usernameOrEmail,
  	required String password,
  }) async {
  try {
  	// Get device info for session tracking
  	final accountManager = AccountManager();
  	final deviceInfo = await accountManager.getCurrentDeviceInfo();
  	final deviceId = accountManager.currentDeviceId ??
  		'device_${DateTime.now().millisecondsSinceEpoch}';
 
  	final response = await http.post(
  	Uri.parse('${AppConfig.baseUrl}/api/auth/login'),
  	headers: {
  		'Content-Type': 'application/json',
  		'X-Device-ID': deviceId,
  		'X-Device-Name': deviceInfo.deviceName,
  		'X-Device-Type': deviceInfo.deviceType.name,
  	},
  	body: jsonEncode({
  		'username_or_email': usernameOrEmail,
  		'password': password,
  		'device_id': deviceId,
  		'device_name': deviceInfo.deviceName,
  		'device_type': deviceInfo.deviceType.name,
  	}),
  	);
 
  	if (response.statusCode == 200) {
  	final data = jsonDecode(response.body);
  	if (data['success'] == true) {
  		// Save to AccountManager
  		await _saveToAccountManager(
  		data['auth_token'],
  		data['user_id'],
  		username: data['user']?['username'],
  		displayName: data['user']?['display_name'],
  		avatarUrl: data['user']?['avatar_url'],
  		name: data['user']?['name'],
  		surname: data['user']?['surname'],
  		email: data['user']?['email'],
  		phone: data['user']?['phone'],
  		);
  		// Ensure Saved Messages chat exists locally
  		try {
  			await AppDatabase().ensureSavedChatExists(data['user_id']);
  		} catch (e) {
  			debugPrint('AuthService: Error creating saved chat: $e');
  		}
  		return {
  		'success': true,
  		'authToken': data['auth_token'],
  		'userId': data['user_id'],
  		'message': data['message'] ?? 'Login successful',
  		'user': data['user'],
  		};
  	} else {
  		return {
  		'success': false,
  		'message': data['message'] ?? 'Login failed',
  		};
  	}
  	} else {
  	// Handle different error codes
  	final data = jsonDecode(response.body);
  	return {
  		'success': false,
  		'message': _getErrorMessage(response.statusCode, data['message']),
  	};
  	}
  } catch (e) {
  	// Network error or other exception
  	return {
  	'success': false,
  	'message': 'Network error: ${e.toString()}',
  	};
  }
  }

  /// Logs out the current user by invalidating the session.
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      // Log error but don't throw - we want to clear local state anyway
      debugPrint('Logout error: $e');
    } finally {
      // Clear current account from AccountManager
      final accountManager = AccountManager();
      if (accountManager.currentAccount != null) {
        await accountManager.removeAccount(accountManager.currentAccount!.userId);
      }
    }
  }

  /// Logout from a specific device session.
  static Future<bool> logoutDevice(String deviceId) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/logout-device'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'device_id': deviceId}),
      );

      if (response.statusCode == 200) {
        // Remove from local storage
        await AccountManager().removeDeviceSession(deviceId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Logout device error: $e');
      return false;
    }
  }

  /// Initiates password recovery for a given email.
  static Future<Map<String, dynamic>> recoverPassword({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/recover'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] == true,
        'message': data['message'] ?? 'Recovery email sent if account exists',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Gets the stored auth token from AccountManager.
  static Future<String?> getToken() async {
    final accountManager = AccountManager();
    return accountManager.currentAccount?.token;
  }

  /// Logs in as a test user without network (offline/demo mode).
  /// Creates a fake account in AccountManager and returns success.
  static Future<Map<String, dynamic>> loginAsTestUser() async {
    const testUserId = 'test_user_001';
    const testToken = 'test_token_offline_mode';
    const testUsername = 'admin';
    const testDisplayName = 'Test Admin';

    final accountManager = AccountManager();

    // Remove existing test account to avoid duplicate exception
    if (accountManager.hasAccount(testUserId)) {
      await accountManager.removeAccount(testUserId);
    }

    final account = Account(
      userId: testUserId,
      token: testToken,
      username: testUsername,
      displayName: testDisplayName,
      lastLogin: DateTime.now(),
      email: 'admin@miptgram.local',
      phone: null,
      name: 'Test',
      surname: 'Admin',
    );

    await accountManager.addAccount(account);
    await accountManager.setCurrentAccount(testUserId);
    await accountManager.registerDeviceSession(testUserId);

    // Ensure Saved Messages chat exists locally
    try {
      await AppDatabase().ensureSavedChatExists(testUserId);
    } catch (e) {
      debugPrint('AuthService: Error creating saved chat: $e');
    }

    return {
      'success': true,
      'authToken': testToken,
      'userId': testUserId,
      'message': 'Test login successful (offline mode)',
    };
  }

  /// Gets the stored user ID from AccountManager.
  static Future<String?> getUserId() async {
    final accountManager = AccountManager();
    return accountManager.currentAccount?.userId;
  }

  /// Checks if the user is logged in.
  static Future<bool> isLoggedIn() async {
    final accountManager = AccountManager();
    return accountManager.hasSavedAccount;
  }

  /// Gets the current user's profile data from the server.
  /// Returns a map containing user data on success.
  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update account profile
          final accountManager = AccountManager();
          await accountManager.updateAccountProfile(
            accountManager.currentAccount!.userId,
            username: data['user']?['username'],
            displayName: data['user']?['display_name'],
            avatarUrl: data['user']?['avatar_url'],
            name: data['user']?['name'],
            surname: data['user']?['surname'],
            email: data['user']?['email'],
            phone: data['user']?['phone'],
          );
          return {
            'success': true,
            'user': data['user'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to get user data',
          };
        }
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': _getErrorMessage(response.statusCode, data['message']),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Gets another user's public profile by user ID.
  /// Returns a map containing user data on success.
  /// Only public fields are returned (no email or phone).
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/user/profile/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'user': data['user'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to get user profile',
          };
        }
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': _getErrorMessage(response.statusCode, data['message']),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Gets all active sessions for the current user.
  static Future<Map<String, dynamic>> getActiveSessions() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/auth/sessions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'sessions': data['sessions'] ?? [],
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': _getErrorMessage(response.statusCode, data['message']),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Private helpers

  static Future<void> _saveToAccountManager(
    String token,
    String userId, {
    String? username,
    String? displayName,
    String? avatarUrl,
    String? name,
    String? surname,
    String? email,
    String? phone,
  }) async {
    final accountManager = AccountManager();

    // Check if account already exists
    if (accountManager.hasAccount(userId)) {
      // Update existing account
      await accountManager.updateAccountToken(userId, token);
      await accountManager.updateAccountProfile(
        userId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        name: name,
        surname: surname,
        email: email,
        phone: phone,
      );
      await accountManager.setCurrentAccount(userId);
    } else {
      // Add new account
      final account = Account(
        userId: userId,
        token: token,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        lastLogin: DateTime.now(),
        name: name,
        surname: surname,
        email: email,
        phone: phone,
      );
      await accountManager.addAccount(account);
    }

    // Register device session
      await accountManager.registerDeviceSession(userId);
    }
  
    /// Upload avatar image to server.
    /// Returns a map containing the avatar URL on success.
    /// Uses MinIO storage for avatar upload.
    static Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
      try {
        debugPrint('[uploadAvatar] Step 1: Getting token...');
        final token = await getToken();
        if (token == null) {
          debugPrint('[uploadAvatar] Step 1-fail: token is null');
          return {
            'success': false,
            'message': 'Not authenticated',
          };
        }
        debugPrint('[uploadAvatar] Step 1-ok: token obtained (length=${token.length})');
  
        debugPrint('[uploadAvatar] Step 2: Checking file exists at $filePath');
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('[uploadAvatar] Step 2-fail: file not found');
          return {
            'success': false,
            'message': 'File not found',
          };
        }
        final fileSize = await file.length();
        debugPrint('[uploadAvatar] Step 2-ok: file exists, size=$fileSize bytes');
  
        final fileName = path.basename(filePath);
  
        // Use the new MinIO-based avatar upload endpoint
        debugPrint('[uploadAvatar] Step 3: Creating MultipartRequest to ${AppConfig.baseUrl}/api/files/upload-avatar');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.baseUrl}/api/files/upload-avatar'),
        );
  
        request.headers['Authorization'] = 'Bearer $token';
        debugPrint('[uploadAvatar] Step 4: Adding MultipartFile fromPath...');
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            filePath,
            filename: fileName,
          ),
        );
        debugPrint('[uploadAvatar] Step 4-ok: MultipartFile added');
  
        debugPrint('[uploadAvatar] Step 5: Sending request (timeout=60s)...');
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            debugPrint('[uploadAvatar] Step 5-timeout: request timed out');
            throw Exception('Upload timed out after 60 seconds');
          },
        );
        debugPrint('[uploadAvatar] Step 5-ok: Streamed response received, statusCode=${streamedResponse.statusCode}');
  
        debugPrint('[uploadAvatar] Step 6: Reading response from stream (timeout=30s)...');
        final response = await http.Response.fromStream(streamedResponse)
            .timeout(const Duration(seconds: 30), onTimeout: () {
          debugPrint('[uploadAvatar] Step 6-timeout: reading stream timed out');
          throw Exception('Reading response timed out after 30 seconds');
        });
        debugPrint('[uploadAvatar] Step 6-ok: Response body length=${response.body.length}, statusCode=${response.statusCode}');
  
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugPrint('[uploadAvatar] Response data: $data');
          if (data['success'] == true) {
            // Update account avatar URL
            final accountManager = AccountManager();
            if (accountManager.currentAccount != null) {
              await accountManager.updateAccountProfile(
                accountManager.currentAccount!.userId,
                avatarUrl: data['avatar_url'],
              );
            }
            return {
              'success': true,
              'avatar_url': data['avatar_url'],
              'avatar_id': data['avatar_id'],  // Pass through avatar_id from backend
              'message': data['message'] ?? 'Avatar uploaded successfully',
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Failed to upload avatar',
            };
          }
        } else {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'message': _getErrorMessage(response.statusCode, data['message']),
          };
        }
      } catch (e) {
        return {
          'success': false,
          'message': 'Network error: ${e.toString()}',
        };
      }
    }
  
    /// Updates the user profile with new data.
  /// Returns a map containing success status and message.
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String surname,
    required String username,
    required String email,
    required String phone,
    String? avatarUrl,
    bool requiresServerValidation = false,
  }) async {
    final accountManager = AccountManager();
    final currentAcc = accountManager.currentAccount;

    // Проверяем, изменились ли никнейм или телефон относительно текущего сохраненного профиля
    final isUsernameChanged = currentAcc != null &&
        username.trim() != (currentAcc.username ?? '').trim();
    final isPhoneChanged = currentAcc != null &&
        phone.trim() != (currentAcc.phone ?? '').trim();

    final isUniqueFieldChanged =
        requiresServerValidation || isUsernameChanged || isPhoneChanged;

    // Если изменяются УНИКАЛЬНЫЕ поля (никнейм/телефон), ТРЕБУЕТСЯ прямое подтверждение сервера!
    if (isUniqueFieldChanged) {
      try {
        final token = await getToken();
        if (token == null) {
          return {
            'success': false,
            'requiresServer': true,
            'message': 'Not authenticated on server',
          };
        }

        final response = await http.put(
          Uri.parse('${AppConfig.baseUrl}/api/user/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': name,
            'surname': surname,
            'username': username,
            'email': email,
            'phone': phone,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            // Сервер подтвердил свободу уникальных полей и успешно обновил профиль
            if (currentAcc != null) {
              await accountManager.updateAccountProfile(
                currentAcc.userId,
                username: username,
                displayName: '$name $surname',
                avatarUrl: avatarUrl,
                name: name,
                surname: surname,
                email: email,
                phone: phone,
              );
            }
            await accountManager.clearPendingProfileSync();
            return {
              'success': true,
              'synced': true,
              'message': data['message'] ?? 'Profile updated successfully',
              'user': data['user'],
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Failed to update profile',
            };
          }
        } else {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'message': _getErrorMessage(response.statusCode, data['message']),
          };
        }
      } catch (e) {
        // Запрос не удался/офлайн: изменение никнейма или телефона ЗАПРЕЩЕНО без подтверждения сервера!
        return {
          'success': false,
          'requiresServer': true,
          'message':
              'Server connection required to verify username/phone availability',
        };
      }
    }

    // Если изменялись только обычные поля (Имя, Фамилия, Био и т.д.):
    // 1. Гарантированно сохраняем локально и применяем изменения сразу
    if (currentAcc != null) {
      await accountManager.updateAccountProfile(
        currentAcc.userId,
        username: username,
        displayName: '$name $surname',
        avatarUrl: avatarUrl,
        name: name,
        surname: surname,
        email: email,
        phone: phone,
      );
    }

    try {
      final token = await getToken();
      if (token == null) {
        await accountManager.savePendingProfileSync({
          'name': name,
          'surname': surname,
          'username': username,
          'email': email,
          'phone': phone,
        });
        return {
          'success': true,
          'synced': false,
          'message': 'Not authenticated on server',
        };
      }

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'surname': surname,
          'username': username,
          'email': email,
          'phone': phone,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await accountManager.clearPendingProfileSync();
          return {
            'success': true,
            'synced': true,
            'message': data['message'] ?? 'Profile updated successfully',
            'user': data['user'],
          };
        }
      }

      await accountManager.savePendingProfileSync({
        'name': name,
        'surname': surname,
        'username': username,
        'email': email,
        'phone': phone,
      });

      return {
        'success': true,
        'synced': false,
        'message': 'Server error. Profile saved locally.',
      };
    } catch (e) {
      await accountManager.savePendingProfileSync({
        'name': name,
        'surname': surname,
        'username': username,
        'email': email,
        'phone': phone,
      });

      return {
        'success': true,
        'synced': false,
        'message': 'Network offline. Saved locally.',
      };
    }
  }

  /// Deletes the user's primary avatar by removing the newest one.
  /// Uses the new DELETE /api/user/avatars/:avatarId endpoint.
  /// Returns a map containing success status and message.
  static Future<Map<String, dynamic>> deleteAvatar({int? avatarId}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      if (avatarId != null) {
        // Delete specific avatar by ID
        final response = await http.delete(
          Uri.parse('${AppConfig.baseUrl}/api/user/avatars/$avatarId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            // Refresh profile to get updated avatar_url
            final accountManager = AccountManager();
            if (accountManager.currentAccount != null) {
              await accountManager.updateAccountProfile(
                accountManager.currentAccount!.userId,
                avatarUrl: '',
              );
            }
            return {
              'success': true,
              'message': data['message'] ?? 'Avatar deleted successfully',
            };
          } else {
            return {
              'success': false,
              'message': data['message'] ?? 'Failed to delete avatar',
            };
          }
        } else {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'message': _getErrorMessage(response.statusCode, data['message']),
          };
        }
      }

      // Fallback: old method — clear avatar_url via profile update
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'avatar_url': '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update account profile to remove avatar
          final accountManager = AccountManager();
          if (accountManager.currentAccount != null) {
            await accountManager.updateAccountProfile(
              accountManager.currentAccount!.userId,
              avatarUrl: '',
            );
          }
          return {
            'success': true,
            'message': data['message'] ?? 'Avatar deleted successfully',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to delete avatar',
          };
        }
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': _getErrorMessage(response.statusCode, data['message']),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static String _getErrorMessage(int statusCode, String? serverMessage) {
    switch (statusCode) {
      case 400:
        return serverMessage ?? 'Invalid request';
      case 401:
        return 'Invalid credentials';
      case 403:
        return 'Account is locked or disabled';
      case 404:
        return 'User not found';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
