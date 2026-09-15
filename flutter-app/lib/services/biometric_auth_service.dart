import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthService {
  BiometricAuthService._();

  static final BiometricAuthService instance = BiometricAuthService._();

  // Keys are scoped per businessId so different gyms don't share biometric settings.
  String _tokenKey(String businessId)         => 'bookup_secure_token_$businessId';
  String _biometricEnabledKey(String businessId) => 'bookup_biometric_enabled_$businessId';

  final _storage    = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth  = LocalAuthentication();

  Future<bool> isDeviceSupported()  => _localAuth.isDeviceSupported();

  Future<bool> canCheckBiometrics() async {
    try { return await _localAuth.canCheckBiometrics; }
    catch (_) { return false; }
  }

  Future<bool> isBiometricEnabled(String businessId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey(businessId)) ?? false;
  }

  Future<void> setBiometricEnabled(String businessId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey(businessId), enabled);
    if (!enabled) await _storage.delete(key: _tokenKey(businessId));
  }

  Future<void> saveToken(String businessId, String token) async {
    await _storage.write(key: _tokenKey(businessId), value: token);
  }

  Future<String?> readToken(String businessId) =>
      _storage.read(key: _tokenKey(businessId));

  Future<void> clearToken(String businessId) =>
      _storage.delete(key: _tokenKey(businessId));

  Future<bool> hasStoredToken(String businessId) async {
    final token = await readToken(businessId);
    return token != null && token.isNotEmpty;
  }

  /// Remove ALL biometric data for a businessId (on switch-business / full logout).
  Future<void> clearAll(String businessId) async {
    await clearToken(businessId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricEnabledKey(businessId));
  }

  Future<String> biometricLabel() async {
    final types = await _localAuth.getAvailableBiometrics();
    if (types.contains(BiometricType.face))
      return Platform.isIOS ? 'Face ID' : 'Face Unlock';
    if (types.contains(BiometricType.fingerprint))
      return Platform.isIOS ? 'Touch ID' : 'Δακτυλικό';
    return 'Βιομετρικά';
  }

  Future<IconData> biometricIcon() async {
    final types = await _localAuth.getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return Icons.face_rounded;
    return Icons.fingerprint;
  }

  Future<bool> authenticate({String reason = 'Επιβεβαίωσε την ταυτότητά σου για είσοδο'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth:    true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
