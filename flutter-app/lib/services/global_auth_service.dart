import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../l10n/tr.dart';


const _kGlobalToken      = 'global_auth_token';
const _kGlobalUser       = 'global_user_json';
const _kGlobalGyms       = 'global_gyms_json';
const _kPreferredRole    = 'global_preferred_role';

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
  final String userType; // 'member' | 'staff'
  final String? staffId;
  final String? staffKind; // trainer | nutritionist | physiotherapist
  final List<({String id, String name})> locations;

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
    this.userType = 'member',
    this.staffId,
    this.staffKind,
    this.locations = const [],
  });

  bool get isStaff => userType == 'staff';
  bool get isNutritionist => staffKind == 'nutritionist';

  factory GlobalGym.fromJson(Map<String, dynamic> j) => GlobalGym(
    userId:       j['user_id'] as String? ?? '',
    businessId:   j['business_id'] as String,
    businessName: j['business_name'] as String,
    appName:      j['app_name'] as String? ?? j['business_name'] as String,
    slug:         j['slug'] as String,
    businessType: j['business_type'] as String? ?? 'gym',
    primaryColor: j['primary_color'] as String? ?? '#B8F55E',
    logoUrl:      j['logo_url'] as String?,
    userStatus:   j['user_status'] as String? ?? 'active',
    userType:     j['user_type'] as String? ?? 'member',
    staffId:      j['staff_id'] as String?,
    staffKind:    j['staff_kind'] as String?,
    locations:    ((j['locations'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => (
          id: row['id']?.toString() ?? '',
          name: row['name']?.toString() ?? '',
        ))
        .where((row) => row.id.isNotEmpty && row.name.isNotEmpty)
        .toList(),
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
    'user_type':     userType,
    'staff_id':      staffId,
    'staff_kind':    staffKind,
    'locations':     locations.map((row) => {'id': row.id, 'name': row.name}).toList(),
  };
}

class GlobalUser {
  final String id;
  final String email;
  final String fullName;
  final String phone;

  const GlobalUser({required this.id, required this.email, required this.fullName, this.phone = ''});

  factory GlobalUser.fromJson(Map<String, dynamic> j) => GlobalUser(
    id:       j['id'] as String? ?? '',
    email:    j['email'] as String? ?? '',
    fullName: j['full_name'] as String? ?? '',
    phone:    j['phone'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'full_name': fullName, 'phone': phone};
}

class GlobalAuthService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _apiBase  = 'https://passionate-grace-production-98ad.up.railway.app/api';

  String? _token;
  GlobalUser? _user;
  List<GlobalGym> _gyms = [];
  String? _preferredRole; // 'member' | 'staff'

  String?         get token         => _token;
  GlobalUser?     get user          => _user;
  List<GlobalGym> get gyms          => _gyms;
  String?         get preferredRole => _preferredRole;
  bool get isLoggedIn => _token != null && _user != null;

  Future<void> init() async {
    if (isLoggedIn) return;
    try {
      final token = await _storage.read(key: _kGlobalToken);
      final uJson = await _storage.read(key: _kGlobalUser);
      final gJson = await _storage.read(key: _kGlobalGyms);
      _preferredRole = await _storage.read(key: _kPreferredRole);
      if (token != null && uJson != null) {
        _token = token;
        _user  = GlobalUser.fromJson(jsonDecode(uJson) as Map<String, dynamic>);
        if (gJson != null) {
          final list = jsonDecode(gJson) as List;
          _gyms = list.map((e) => GlobalGym.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('global auth read failed: $e');
    }
  }

  /// The gym login is still valid, but the OmniPlex session was lost.
  /// Ask the API to issue it again from that gym token.
  Future<bool> restoreFromGymToken(String gymToken) async {
    if (isLoggedIn) return true;
    if (gymToken.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/global/auth/from-gym'),
        headers: {'Authorization': 'Bearer $gymToken'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body);
      if (body is! Map) return false;
      await _persist(Map<String, dynamic>.from(body));
      return isLoggedIn;
    } catch (e) {
      debugPrint('restore OmniPlex session failed: $e');
      return false;
    }
  }

  Future<void> setPreferredRole(String role) async {
    _preferredRole = role;
    await _storage.write(key: _kPreferredRole, value: role);
    notifyListeners();
  }

  /// Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    final res = await http.post(
      Uri.parse('$_apiBase/global/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    ).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw body['error'] ?? tr('Αποτυχία αποστολής SMS');
  }

  /// Verify OTP and login/register
  Future<Map<String, dynamic>> verifyOtp(String phone, String code, {String? fullName}) async {
    final res = await http.post(
      Uri.parse('$_apiBase/global/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code, if (fullName != null) 'full_name': fullName}),
    ).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw body['error'] ?? tr('Λάθος κωδικός');
    await _persist(body);
    return body;
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
        if (body['user'] is Map) {
          _user = GlobalUser.fromJson(body['user'] as Map<String, dynamic>);
          await _storage.write(key: _kGlobalUser, value: jsonEncode(_user!.toJson()));
        }
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

  Future<Map<String, dynamic>> claimGym(String businessId) async {
    if (_token == null) throw 'Not logged in';
    final res = await http.post(
      Uri.parse('$_apiBase/global/gyms/claim'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
      body: jsonEncode({'business_id': businessId}),
    );
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) throw tr('Η προσθήκη απέτυχε');
    if (res.statusCode != 200) throw body['error'] ?? tr('Η προσθήκη απέτυχε');
    if (body['user'] is Map) {
      _user = GlobalUser.fromJson(body['user'] as Map<String, dynamic>);
      await _storage.write(key: _kGlobalUser, value: jsonEncode(_user!.toJson()));
    }
    if (body['gyms'] is List) {
      _gyms = (body['gyms'] as List)
          .map((e) => GlobalGym.fromJson(e as Map<String, dynamic>))
          .toList();
      await _storage.write(key: _kGlobalGyms, value: jsonEncode(_gyms.map((g) => g.toJson()).toList()));
    }
    notifyListeners();
    return body;
  }

  Future<Map<String, dynamic>> submitJoinRequest({
    required String businessId,
    required String role,
    String? specialty,
    String? fullName,
    String? phone,
    String? email,
    String? locationId,
  }) async {
    if (_token == null) throw 'Not logged in';
    final res = await http.post(
      Uri.parse('$_apiBase/global/join-requests'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
      body: jsonEncode({
        'business_id': businessId,
        'role': role,
        if (specialty != null) 'specialty': specialty,
        if (fullName != null) 'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (locationId != null) 'location_id': locationId,
      }),
    );
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) throw tr('Το αίτημα δεν στάλθηκε');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw body['message'] ?? body['error'] ?? tr('Το αίτημα δεν στάλθηκε');
    }
    return body;
  }

  /// Get a per-gym trainer JWT for a staff-linked global user
  Future<String> getTrainerToken(String businessId, {String? asKind}) async {
    if (_token == null) throw 'Not logged in';
    final res = await http.post(
      Uri.parse('$_apiBase/global/trainer-token'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
      body: jsonEncode({
        'business_id': businessId,
        if (asKind != null) 'as': asKind,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw body['error'] ?? 'Failed to get trainer token';
    return body['token'] as String;
  }

  /// Remove one gym link. [role] is `member` or `staff` so a trainer
  /// link and a member link at the same gym can be removed separately.
  Future<void> removeGym(String businessId, {String role = 'member'}) async {
    if (_token == null) throw 'Not logged in';
    final res = await http.delete(
      Uri.parse('$_apiBase/global/gyms/$businessId').replace(queryParameters: {'role': role}),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw body['error'] ?? 'Failed to remove gym';
    }
    await refreshGyms();
  }

  /// Called after a successful package purchase that auto-creates a global account
  Future<void> persistFromPurchase(Map<String, dynamic> body) => _persist(body);

  /// Update full_name and/or email after new-user registration
  Future<void> updateProfile({String? fullName, String? email}) async {
    if (_token == null) return;
    final body = <String, String>{};
    if (fullName != null && fullName.trim().isNotEmpty) body['full_name'] = fullName.trim();
    if (email != null && email.trim().isNotEmpty)       body['email']     = email.trim();
    if (body.isEmpty) return;
    final res = await http.put(
      Uri.parse('$_apiBase/global/profile'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
      body: jsonEncode(body),
    );
    final resBody = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw resBody['error'] ?? tr('Αποτυχία ενημέρωσης προφίλ');
    if (resBody['user'] != null) {
      _user = GlobalUser.fromJson(resBody['user'] as Map<String, dynamic>);
      await _storage.write(key: _kGlobalUser, value: jsonEncode(_user!.toJson()));
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchInbox() async {
    if (_token == null) return null;
    final res = await http.get(
      Uri.parse('$_apiBase/global/me/notifications'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return Map<String, dynamic>.from(body);
  }

  /// Register FCM token for push notifications (call after login)
  Future<void> registerFcmToken(String fcmToken, {String platform = 'unknown'}) async {
    if (_token == null) return;
    try {
      await http.post(
        Uri.parse('$_apiBase/global/fcm-token'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode({'fcm_token': fcmToken, 'platform': platform}),
      );
    } catch (e) {
      debugPrint('FCM global register failed: $e');
    }
  }

  Future<void> _persist(Map<String, dynamic> body) async {
    final token = body['token']?.toString() ?? '';
    if (token.isEmpty) throw tr('Η σύνδεση δεν αποθηκεύτηκε');
    final userRaw = body['user'];
    final user = userRaw is Map
        ? GlobalUser.fromJson(Map<String, dynamic>.from(userRaw))
        : const GlobalUser(id: '', email: '', fullName: '');
    final gyms = <GlobalGym>[];
    final rawGyms = body['gyms'];
    if (rawGyms is List) {
      for (final raw in rawGyms) {
        if (raw is! Map) continue;
        try {
          gyms.add(GlobalGym.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
    }
    _token = token;
    _user = user;
    _gyms = gyms;
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

  Future<void> deleteAccount() async {
    if (_token == null) throw tr('Δεν είσαι συνδεδεμένος');
    final res = await http.delete(
      Uri.parse('$_apiBase/global/me'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (res.statusCode != 200) {
      dynamic body;
      try { body = jsonDecode(res.body); } catch (_) {}
      final message = body is Map ? body['error']?.toString() : null;
      throw message?.isNotEmpty == true ? message! : tr('Η διαγραφή δεν ολοκληρώθηκε');
    }
    await clear();
  }

  Future<void> clear() async {
    _token = null; _user = null; _gyms = []; _preferredRole = null;
    await _storage.delete(key: _kGlobalToken);
    await _storage.delete(key: _kGlobalUser);
    await _storage.delete(key: _kGlobalGyms);
    await _storage.delete(key: _kPreferredRole);
    notifyListeners();
  }
}
