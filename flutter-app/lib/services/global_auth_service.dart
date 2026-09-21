import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _kGlobalToken  = 'global_auth_token';
const _kGlobalUser   = 'global_user_json';
const _kGlobalGyms   = 'global_gyms_json';

class GlobalGym {
  final String userId;
  final String businessId;
  final String businessName;
  final String appName;
  final String slug;
  final String businessType;
  final String primaryColor;
  final String? logoUrl;
  final String userStatus;

  const GlobalGym({
    required this.userId,
    required this.businessId,
    required this.businessName,
    required this.appName,
    required this.slug,
    required this.businessType,
    required this.primaryColor,
    this.logoUrl,
    required this.userStatus,
  });

  factory GlobalGym.fromJson(Map<String, dynamic> j) => GlobalGym(
    userId:       j['user_id'] as String,
    businessId:   j['business_id'] as String,
    businessName: j['business_name'] as String,
    appName:      j['app_name'] as String? ?? j['business_name'] as String,
    slug:         j['slug'] as String,
    businessType: j['business_type'] as String? ?? 'gym',
    primaryColor: j['primary_color'] as String? ?? '#B8F55E',
    logoUrl:      j['logo_url'] as String?,
    userStatus:   j['user_status'] as String? ?? 'active',
  );

  Map<String, dynamic> toJson() => {
    'user_id':       userId,
    'business_id':   businessId,
    'business_name': businessName,
    'app_name':      appName,
    'slug':          slug,
    'business_type': businessType,
    'primary_color': primaryColor,
    'logo_url':      logoUrl,
    'user_status':   userStatus,
  };
}

class GlobalUser {
  final String id;
  final String email;
  final String fullName;

  const GlobalUser({required this.id, required this.email, required this.fullName});

  factory GlobalUser.fromJson(Map<String, dynamic> j) => GlobalUser(
    id:       j['id'] as String,
    email:    j['email'] as String,
    fullName: j['full_name'] as String,
  );
  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'full_name': fullName};
}

class GlobalAuthService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _apiBase  = 'https://passionate-grace-production-98ad.up.railway.app/api';

  String? _token;
  GlobalUser? _user;
  List<GlobalGym> _gyms = [];

  String?      get token  => _token;
  GlobalUser?  get user   => _user;
  List<GlobalGym> get gyms => _gyms;
  bool get isLoggedIn => _token != null && _user != null;

  Future<void> init() async {
    try {
      _token = await _storage.read(key: _kGlobalToken);
      final uJson = await _storage.read(key: _kGlobalUser);
      final gJson = await _storage.read(key: _kGlobalGyms);
      if (_token != null && uJson != null) {
        _user  = GlobalUser.fromJson(jsonDecode(uJson) as Map<String, dynamic>);
        if (gJson != null) {
          final list = jsonDecode(gJson) as List;
          _gyms = list.map((e) => GlobalGym.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {
      await clear();
    }
  }

  Future<Map<String, dynamic>> loginPhone(String phone, String pin) async {
    final res = await http.post(
      Uri.parse('$_apiBase/global/auth/login-phone'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'pin': pin}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw body['error'] ?? 'Login failed';
    await _persist(body);
    return body;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_apiBase/global/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw body['error'] ?? 'Login failed';
    await _persist(body);
    return body;
  }

  Future<Map<String, dynamic>> register(String fullName, String email, String password, {String? phone}) async {
    final res = await http.post(
      Uri.parse('$_apiBase/global/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'full_name': fullName, 'email': email, 'password': password, 'phone': phone}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 && res.statusCode != 201) throw body['error'] ?? 'Register failed';
    await _persist(body);
    return body;
  }

  /// Refresh gyms list from server
  Future<void> refreshGyms() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/global/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['gyms'] as List?) ?? [];
        _gyms = list.map((e) => GlobalGym.fromJson(e as Map<String, dynamic>)).toList();
        await _storage.write(key: _kGlobalGyms, value: jsonEncode(_gyms.map((g) => g.toJson()).toList()));
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Get a per-gym JWT for a specific business
  Future<String> getGymToken(String businessId) async {
    if (_token == null) throw 'Not logged in';
    final res = await http.post(
      Uri.parse('$_apiBase/global/gym-token'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
      body: jsonEncode({'business_id': businessId}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw body['error'] ?? 'Failed to get gym token';
    return body['token'] as String;
  }

  /// Link an existing gym account by phone+PIN
  Future<void> linkGym(String businessId, String phone, String pin) async {
    if (_token == null) throw 'Not logged in';
    final res = await http.post(
      Uri.parse('$_apiBase/global/link-gym'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
      body: jsonEncode({'business_id': businessId, 'phone': phone, 'pin': pin}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw body['error'] ?? 'Link failed';
    await refreshGyms();
  }

  /// Called after a successful package purchase that auto-creates a global account
  Future<void> persistFromPurchase(Map<String, dynamic> body) => _persist(body);

  Future<void> _persist(Map<String, dynamic> body) async {
    _token = body['token'] as String;
    _user  = GlobalUser.fromJson(body['user'] as Map<String, dynamic>);
    _gyms  = ((body['gyms'] as List?) ?? [])
        .map((e) => GlobalGym.fromJson(e as Map<String, dynamic>))
        .toList();
    await _storage.write(key: _kGlobalToken, value: _token);
    await _storage.write(key: _kGlobalUser,  value: jsonEncode(_user!.toJson()));
    await _storage.write(key: _kGlobalGyms,  value: jsonEncode(_gyms.map((g) => g.toJson()).toList()));
    notifyListeners();
  }

  // Called after staff login — stores staff token + gym list
  Future<void> setStaffSession({
    required String token,
    required String fullName,
    required List<Map<String, dynamic>> gyms,
  }) async {
    _token = token;
    _user  = GlobalUser(id: '', email: '', fullName: fullName);
    _gyms  = gyms.map((g) => GlobalGym(
      userId:       g['staff_id'] as String? ?? '',
      businessId:   g['business_id'] as String,
      businessName: g['business_name'] as String? ?? '',
      appName:      g['app_name'] as String? ?? g['business_name'] as String? ?? '',
      slug:         g['slug'] as String,
      businessType: g['business_type'] as String? ?? 'gym',
      primaryColor: g['primary_color'] as String? ?? '#B8F55E',
      logoUrl:      g['logo_url'] as String?,
      userStatus:   'active',
    )).toList();

    await _storage.write(key: _kGlobalToken, value: token);
    await _storage.write(key: _kGlobalUser,  value: jsonEncode({'id': '', 'email': '', 'full_name': fullName}));
    await _storage.write(key: _kGlobalGyms,  value: jsonEncode(_gyms.map((g) => g.toJson()).toList()));
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null; _user = null; _gyms = [];
    await _storage.delete(key: _kGlobalToken);
    await _storage.delete(key: _kGlobalUser);
    await _storage.delete(key: _kGlobalGyms);
    notifyListeners();
  }
}
