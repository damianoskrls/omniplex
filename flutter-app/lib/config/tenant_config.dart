import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TenantConfig {
  TenantConfig({
    required this.businessId,
    required this.slug,
    required this.appName,
    required this.bundleId,
    required this.apiBaseUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    this.logoUrl,
    required this.featureOnlineBooking,
    required this.featureLoyaltyPoints,
    required this.featureMemberships,
    required this.featureNutrition,
    this.featureMarketplace = false,
    this.featureOnlinePayments = false,
    required this.labels,
  });

  final String businessId;
  final String slug;
  final String appName;
  final String bundleId;
  final String apiBaseUrl;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String? logoUrl;
  final bool featureOnlineBooking;
  final bool featureLoyaltyPoints;
  final bool featureMemberships;
  final bool featureNutrition;
  final bool featureMarketplace;
  final bool featureOnlinePayments;
  final Map<String, String> labels;

  String label(String key, String fallback) => labels[key] ?? fallback;

  static const _prefKeyConfig = 'tenant_config_json';
  static const _prefKeySlug   = 'tenant_slug';
  static const _prefKeyApiUrl = 'tenant_api_url';

  /// Load from local assets (legacy / static build mode).
  static Future<TenantConfig> load() async {
    final raw = await rootBundle.loadString('assets/tenant_config.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    const envOverride = String.fromEnvironment('BOOKUP_API_URL');
    final configuredUrl = envOverride.isNotEmpty
        ? envOverride
        : (json['api_base_url'] as String? ?? 'http://localhost:3001');
    json['api_base_url'] = await _resolveApiBaseUrl(configuredUrl);
    return TenantConfig.fromJson(json);
  }

  /// Dynamic mode: fetch config from API by slug and cache it.
  /// Returns cached config immediately and refreshes in background on subsequent calls.
  static Future<TenantConfig> loadFromApi({
    required String slug,
    required String apiBaseUrl,
  }) async {
    final resolved = await _resolveApiBaseUrl(apiBaseUrl);
    final prefs = await SharedPreferences.getInstance();

    // Try fetching fresh config
    try {
      final url = '$resolved/api/tenants/public/$slug';
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        json['api_base_url'] = resolved;
        // Cache for next launch
        await prefs.setString(_prefKeyConfig, jsonEncode(json));
        await prefs.setString(_prefKeySlug, slug);
        await prefs.setString(_prefKeyApiUrl, resolved);
        return TenantConfig.fromJson(json);
      }
    } catch (_) {
      // Fall through to cached
    }

    // Use cached config if fetch fails
    final cached = prefs.getString(_prefKeyConfig);
    if (cached != null) {
      final json = jsonDecode(cached) as Map<String, dynamic>;
      json['api_base_url'] = resolved;
      return TenantConfig.fromJson(json);
    }

    throw Exception('Δεν βρέθηκε config για "$slug". Έλεγξε το slug και τη σύνδεση.');
  }

  /// Returns the cached slug/apiUrl if a tenant was previously configured, null otherwise.
  static Future<({String slug, String apiUrl})?> getCachedTenant() async {
    final prefs = await SharedPreferences.getInstance();
    final slug = prefs.getString(_prefKeySlug);
    final apiUrl = prefs.getString(_prefKeyApiUrl);
    if (slug != null && apiUrl != null) return (slug: slug, apiUrl: apiUrl);
    return null;
  }

  /// Clear cached tenant (for "switch business" flow).
  static Future<void> clearCachedTenant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyConfig);
    await prefs.remove(_prefKeySlug);
    await prefs.remove(_prefKeyApiUrl);
  }

  /// Refresh config in background without blocking.
  static Future<void> refreshInBackground({
    required String slug,
    required String apiBaseUrl,
  }) async {
    try {
      await loadFromApi(slug: slug, apiBaseUrl: apiBaseUrl);
    } catch (_) {
      // silent — background refresh, don't surface errors
    }
  }

  /// Quick check that the device can reach admin-api.
  static Future<String?> verifyApiReachable(String apiBaseUrl) async {
    if (kIsWeb) return null;
    final base = apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.tryParse('$base/api/health');
    if (uri == null) return 'Μη έγκυρο api_base_url: $apiBaseUrl';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 4));
      await response.drain();
      client.close();
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return 'Ο server απάντησε με σφάλμα (${response.statusCode}).';
    } on TimeoutException {
      return _unreachableMessage(apiBaseUrl);
    } on SocketException {
      return _unreachableMessage(apiBaseUrl);
    } catch (e) {
      return _unreachableMessage(apiBaseUrl);
    }
  }

  static String _unreachableMessage(String apiBaseUrl) {
    return 'Δεν συνδέεται στο $apiBaseUrl\n\n'
        '• iPhone και Mac στο ίδιο Wi‑Fi (όχι μόνο 5G)\n'
        '• Στο Mac: ipconfig getifaddr en0 → βάλε το IP στο tenant_config.json\n'
        '• Ρυθμίσεις iPhone → Handstand → Τοπικό Δίκτυο: Ενεργό\n'
        '• Δοκίμασε στο Safari: $apiBaseUrl/api/health\n'
        '• Μετά αλλαγή config: stop + flutter run (όχι hot reload)';
  }

  /// On Android emulator, host machine is reachable at 10.0.2.2 (not LAN IP).
  static Future<String> _resolveApiBaseUrl(String configured) async {
    if (kIsWeb || !Platform.isAndroid) return configured;

    final uri = Uri.tryParse(configured);
    if (uri == null || uri.host.isEmpty) return configured;

    final port = uri.port == 0 ? 3001 : uri.port;
    try {
      final socket = await Socket.connect(
        '10.0.2.2',
        port,
        timeout: const Duration(milliseconds: 400),
      );
      await socket.close();
      return uri.replace(host: '10.0.2.2').toString();
    } catch (_) {
      return configured;
    }
  }

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    final overrides = json['label_overrides'];
    return TenantConfig(
      businessId: json['business_id'] as String? ?? json['id'] as String,
      slug: json['slug'] as String? ?? '',
      appName: json['app_name'] as String? ?? 'Handstand',
      bundleId: json['bundle_id'] as String? ?? 'com.bookup.app',
      apiBaseUrl: json['api_base_url'] as String? ?? 'http://localhost:3001',
      primaryColor: json['primary_color'] as String? ?? '#6200EE',
      secondaryColor: json['secondary_color'] as String? ?? '#03DAC6',
      accentColor: json['accent_color'] as String? ?? '#FF6D00',
      logoUrl: json['logo_url'] as String?,
      featureOnlineBooking: _flag(json['feature_online_booking']),
      featureLoyaltyPoints: _flag(json['feature_loyalty_points']),
      featureMemberships: _flag(json['feature_memberships']),
      featureNutrition: _flag(json['feature_nutrition']),
      featureMarketplace: _flag(json['feature_marketplace']),
      featureOnlinePayments: _flag(json['feature_online_payments']),
      labels: overrides is Map
          ? overrides.map((k, v) => MapEntry(k.toString(), v.toString()))
          : {},
    );
  }

  static bool _flag(dynamic value) => value == 1 || value == true;
}
