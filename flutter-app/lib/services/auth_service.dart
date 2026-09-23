import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tenant_config.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'biometric_auth_service.dart';

class AuthService extends ChangeNotifier {
  AuthService(this.config) : api = ApiService(config);

  final TenantConfig config;
  final ApiService api;

  // Shorthand — keeps biometric calls scoped to THIS gym
  String get _bizId => config.businessId;

  AppUser? _user;
  bool _loading      = true;
  bool _locked       = false;
  bool _biometricAvailable = false;
  bool _reconnecting = false;
  int  _retryCount   = 0;

  AppUser? get user                => _user;
  bool     get isLoggedIn          => _user != null;
  String?  get staffId             => (_user?.isStaff == true) ? _user?.id : null;
  bool     get loading             => _loading;
  bool     get isLocked            => _locked;
  bool     get biometricAvailable  => _biometricAvailable;
  bool     get canUnlockWithBiometrics => _locked && _biometricAvailable;
  bool     get reconnecting        => _reconnecting;

  static const _legacyTokenKey = 'bookup_token';

  Future<void> init() async {
    try {
      await _initInternal().timeout(const Duration(seconds: 10));
    } catch (_) {
      api.token = null;
      _user     = null;
      _locked   = false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _initInternal() async {
    final bio = BiometricAuthService.instance;
    try {
      _biometricAvailable =
          await bio.isDeviceSupported() && await bio.canCheckBiometrics();
    } catch (_) {
      _biometricAvailable = false;
    }

    // Migrate legacy global token to business-scoped key (one-time)
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_legacyTokenKey);
    if (legacyToken != null) {
      await bio.saveToken(_bizId, legacyToken);
      await prefs.remove(_legacyTokenKey);
    }

    final biometricEnabled = await bio.isBiometricEnabled(_bizId);
    final token            = await bio.readToken(_bizId);

    if (token != null) {
      api.token = token;
      if (biometricEnabled) {
        _locked = true;
      } else {
        try {
          _user = await _fetchMe(token);
        } on ApiException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 403) {
            await bio.clearToken(_bizId);
            api.token = null;
          } else {
            _reconnecting = true;
            _scheduleReconnect();
          }
        } catch (_) {
          _reconnecting = true;
          _scheduleReconnect();
        }
      }
    }
  }

  void _scheduleReconnect() {
    if (_retryCount >= 5) {
      _reconnecting = false;
      notifyListeners();
      return;
    }
    _retryCount++;
    final delay = Duration(seconds: _retryCount * 3);
    Future.delayed(delay, () async {
      if (_user != null || api.token == null) {
        _reconnecting = false;
        notifyListeners();
        return;
      }
      try {
        _user = await _fetchMe(api.token ?? '');
        _reconnecting = false;
        _retryCount   = 0;
        notifyListeners();
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          await BiometricAuthService.instance.clearToken(_bizId);
          api.token     = null;
          _reconnecting = false;
          _retryCount   = 0;
          notifyListeners();
        } else {
          _scheduleReconnect();
        }
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  // Decode JWT role without verifying signature (client-side only)
  static String? _jwtRole(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return map['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<AppUser> _fetchMe(String token) {
    final role = _jwtRole(token);
    if (role == 'staff') return api.staffMe();
    if (role == 'client_admin') return _adminUserFromToken(token);
    return api.me();
  }

  Future<AppUser> _adminUserFromToken(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length < 2) throw Exception('bad token');
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return AppUser(
        id: 'admin-${map['businessId'] ?? ''}',
        fullName: map['name'] as String? ?? 'Admin',
        email: map['email'] as String? ?? '',
        businessId: map['businessId'] as String? ?? '',
        role: UserRole.admin,
      );
    } catch (_) {
      return AppUser(
        id: 'admin',
        fullName: 'Admin',
        email: '',
        businessId: config.businessId,
        role: UserRole.admin,
      );
    }
  }

  Future<void> login(String phone, String pin) async {
    _user = await api.login(phone: phone, pin: pin);
    await _persistToken();
    _locked       = false;
    _reconnecting = false;
    _retryCount   = 0;
    notifyListeners();
  }

  Future<void> staffLogin(String email, String password) async {
    _user = await api.staffLogin(email: email, password: password);
    await _persistToken();
    _locked       = false;
    _reconnecting = false;
    _retryCount   = 0;
    notifyListeners();
  }

  Future<void> adminLogin(String email, String password) async {
    final data = await api.adminLogin(email: email, password: password);
    final token = data['token'] as String?;
    if (token == null) throw Exception('No token in admin login response');
    api.token = token;
    _user = AppUser.fromAdminJson(data);
    await _persistToken();
    _locked       = false;
    _reconnecting = false;
    _retryCount   = 0;
    notifyListeners();
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_biometricAvailable) return false;
    final bio = BiometricAuthService.instance;
    final ok  = await bio.authenticate(
        reason: 'Είσοδος με ${await bio.biometricLabel()}');
    if (!ok) return false;

    final token = await bio.readToken(_bizId);
    if (token == null) return false;

    api.token = token;
    try {
      _user = await api.me();
      _locked = false;
      notifyListeners();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<bool> enableBiometricLogin() async {
    if (!_biometricAvailable || !isLoggedIn || api.token == null) return false;
    final bio = BiometricAuthService.instance;
    final ok  = await bio.authenticate(
        reason: 'Ενεργοποίηση εισόδου με ${await bio.biometricLabel()}');
    if (!ok) return false;
    await bio.saveToken(_bizId, api.token!);
    await bio.setBiometricEnabled(_bizId, true);
    notifyListeners();
    return true;
  }

  Future<void> disableBiometricLogin() async {
    await BiometricAuthService.instance.setBiometricEnabled(_bizId, false);
    notifyListeners();
  }

  Future<bool> isBiometricLoginEnabled() =>
      BiometricAuthService.instance.isBiometricEnabled(_bizId);

  Future<void> registerRequest({
    required String fullName,
    required String phone,
    required String pin,
  }) async {
    await api.registerRequest(fullName: fullName, phone: phone, pin: pin);
  }

  Future<void> refreshUser() async {
    if (!isLoggedIn) return;
    _user = await api.me();
    notifyListeners();
  }

  Future<void> logout() async {
    _user         = null;
    _reconnecting = false;
    _retryCount   = 0;
    api.token     = null;

    final bio = BiometricAuthService.instance;
    final keepBiometricSession =
        await bio.isBiometricEnabled(_bizId) &&
        await bio.hasStoredToken(_bizId);
    if (keepBiometricSession) {
      _locked = true;
    } else {
      _locked = false;
      await bio.clearToken(_bizId);
    }

    notifyListeners();
  }

  Future<void> _persistToken() async {
    if (api.token == null) return;
    await BiometricAuthService.instance.saveToken(_bizId, api.token!);
  }
}
