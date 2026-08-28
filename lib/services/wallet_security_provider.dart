import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

enum WalletPasswordType {
  alphanumeric,
  numeric,
  pattern,
}

class WalletSecurityProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  
  bool _isInitialized = false;
  bool _isUnlocked = false;
  bool _useBiometrics = false;
  WalletPasswordType _passwordType = WalletPasswordType.numeric;
  String? _encryptionKey;

  bool get isInitialized => _isInitialized;
  bool get isUnlocked => _isUnlocked;
  bool get useBiometrics => _useBiometrics;
  WalletPasswordType get passwordType => _passwordType;
  String? get encryptionKey => _encryptionKey;

  WalletSecurityProvider() {
    _init();
  }

  Future<void> _init() async {
    final initialized = await _storage.read(key: 'wallet_initialized');
    _isInitialized = initialized == 'true';
    
    final biometrics = await _storage.read(key: 'wallet_use_biometrics');
    _useBiometrics = biometrics == 'true';

    final typeStr = await _storage.read(key: 'wallet_password_type');
    if (typeStr != null) {
      _passwordType = WalletPasswordType.values.firstWhere(
        (e) => e.toString() == typeStr,
        orElse: () => WalletPasswordType.numeric,
      );
    }
    
    notifyListeners();
  }

  Future<void> initialize(String password, WalletPasswordType type, bool useBiometrics) async {
    final key = _deriveKey(password);
    
    await _storage.write(key: 'wallet_initialized', value: 'true');
    await _storage.write(key: 'wallet_use_biometrics', value: useBiometrics.toString());
    await _storage.write(key: 'wallet_password_type', value: type.toString());
    
    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    await _storage.write(key: 'wallet_password_hash', value: passwordHash);

    if (useBiometrics) {
      await _storage.write(key: 'wallet_encryption_key', value: key);
    }

    _encryptionKey = key;
    _isInitialized = true;
    _isUnlocked = true;
    _useBiometrics = useBiometrics;
    _passwordType = type;
    
    notifyListeners();
  }

  Future<bool> unlockWithPassword(String password) async {
    final storedHash = await _storage.read(key: 'wallet_password_hash');
    final currentHash = sha256.convert(utf8.encode(password)).toString();
    
    if (storedHash == currentHash) {
      final key = _deriveKey(password);
      _encryptionKey = key;
      _isUnlocked = true;
      
      // Migration/Fix: If biometrics enabled but key missing, save it now
      if (_useBiometrics) {
        final storedKey = await _storage.read(key: 'wallet_encryption_key');
        if (storedKey == null) {
          await _storage.write(key: 'wallet_encryption_key', value: key);
        }
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_useBiometrics) {
      debugPrint('WalletSecurityProvider: Biometrics not enabled');
      return false;
    }

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      debugPrint(
          'WalletSecurityProvider: canCheck=$canCheck, isSupported=$isSupported');

      if (!canCheck || !isSupported) {
        debugPrint('WalletSecurityProvider: Biometrics not supported or not enrolled');
        return false;
      }

      await _auth.stopAuthentication(); // Clear stale sessions

      final availableBiometrics = await _auth.getAvailableBiometrics();
      debugPrint(
          'WalletSecurityProvider: availableBiometrics=$availableBiometrics');

      if (availableBiometrics.isEmpty) {
        debugPrint('WalletSecurityProvider: No biometrics enrolled on device');
        return false;
      }

      // Fingerprint check
      bool hasStrongAuth =
          availableBiometrics.contains(BiometricType.fingerprint) ||
              availableBiometrics.contains(BiometricType.strong);

      if (!hasStrongAuth && availableBiometrics.isNotEmpty) {
        debugPrint('WalletSecurityProvider: No explicit fingerprint found, but some biometrics exist. Trying anyway.');
        hasStrongAuth = true;
      }

      if (!hasStrongAuth) {
        debugPrint('WalletSecurityProvider: No strong biometric found');
        return false;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock your Wallets and Cards',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      debugPrint('WalletSecurityProvider: didAuthenticate=$didAuthenticate');

      if (didAuthenticate) {
        final storedKey = await _storage.read(key: 'wallet_encryption_key');
        if (storedKey != null) {
          _encryptionKey = storedKey;
          _isUnlocked = true;
          notifyListeners();
          return true;
        } else {
          debugPrint('WalletSecurityProvider: encryption key not found in storage');
        }
      }
    } catch (e) {
      debugPrint('WalletSecurityProvider: Biometric auth error: $e');
    }
    return false;
  }

  String _deriveKey(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return base64.encode(hash.bytes);
  }

  void lock() {
    _isUnlocked = false;
    _encryptionKey = null;
    notifyListeners();
  }

  String encryptData(String plainText) {
    if (_encryptionKey == null) throw Exception('Wallet not unlocked');
    final key = encrypt.Key.fromBase64(_encryptionKey!);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  String decryptData(String encryptedText) {
    if (_encryptionKey == null) throw Exception('Wallet not unlocked');
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) return encryptedText;
      final iv = encrypt.IV.fromBase64(parts[0]);
      final key = encrypt.Key.fromBase64(_encryptionKey!);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return encryptedText;
    }
  }

  Future<bool> canUseFingerprint() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      return available.contains(BiometricType.fingerprint) || available.contains(BiometricType.strong);
    } catch (_) {
      return false;
    }
  }
}
