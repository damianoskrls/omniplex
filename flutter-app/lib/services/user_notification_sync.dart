import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'global_auth_service.dart';
import 'notification_service.dart';
import 'push_service.dart';
import '../l10n/tr.dart';


// Notification types that are only relevant around the booking time.
// If the booking is in the past by more than this threshold, skip the popup.
const _staleTypes = {
  'checkin_reminder',
  'workout_complete',
  'booking_reminder_24h',
  'prep_reminder',
};
const _staleThreshold = Duration(hours: 4);

const _prefsKey = 'notif_shown_ids_v2';

class UserNotificationSync {
  UserNotificationSync._();
  static final UserNotificationSync instance = UserNotificationSync._();

  Timer? _timer;
  Timer? _globalTimer;
  DateTime? _since;
  AuthService? _auth;
  GlobalAuthService? _global;

  // Persisted across app restarts via SharedPreferences.
  final Set<String> _shownIds = {};
  bool _shownIdsLoaded = false;

  void start(AuthService auth) {
    PushService.instance.claimNotification = take;
    _auth = auth;
    _since = DateTime.now().toUtc();
    _timer?.cancel();
    _loadShownIds().then((_) {
      _poll();
      _timer = Timer.periodic(const Duration(seconds: 45), (_) => _poll());
    });
    _registerPushToken(auth);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _auth = null;
    _since = null;
  }

  /// Keeps alerting while the OmniPlex session is logged in, inside a gym or not.
  void watchGlobal(GlobalAuthService global) {
    PushService.instance.claimNotification = take;
    _global = global;
    _globalTimer?.cancel();
    _loadShownIds().then((_) {
      _pollGlobal();
      _globalTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pollGlobal());
    });
  }

  void pollNow() {
    _poll();
    _pollGlobal();
  }

  Future<void> ensureShownIds() => _loadShownIds();

  bool take(String id) {
    if (id.isEmpty || _shownIds.contains(id)) return false;
    _shownIds.add(id);
    _persistShownIds();
    return true;
  }

  Future<void> _registerPushToken(AuthService auth) async {
    if (kIsWeb) return;
    await PushService.instance.registerWithAuth(auth);
  }

  Future<void> _loadShownIds() async {
    if (_shownIdsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey) ?? [];
      _shownIds.addAll(saved);
    } catch (_) {}
    _shownIdsLoaded = true;
  }

  Future<void> _persistShownIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only the last 200 ids to avoid unbounded growth.
      final ids = _shownIds.toList();
      final trimmed = ids.length > 200 ? ids.sublist(ids.length - 200) : ids;
      await prefs.setStringList(_prefsKey, trimmed);
    } catch (_) {}
  }

  bool _isStale(Map<String, dynamic> n) {
    final type = n['type'] as String? ?? '';
    if (!_staleTypes.contains(type)) return false;

    // Try to find when the relevant booking was.
    // The notification may carry booking_starts_at directly or we fall back to created_at.
    final payload = n['payload'];
    String? startsAt;
    if (payload is Map) {
      startsAt = payload['booking_starts_at'] as String? ?? payload['starts_at'] as String?;
    }
    // Fallback: created_at is roughly when the booking was (for checkin_reminder it's close).
    startsAt ??= n['created_at'] as String?;

    if (startsAt == null) return false;
    try {
      final dt = DateTime.parse(startsAt).toUtc();
      return DateTime.now().toUtc().difference(dt) > _staleThreshold;
    } catch (_) {
      return false;
    }
  }

  Future<void> _poll() async {
    final auth = _auth;
    if (auth == null || !auth.isLoggedIn) return;
    try {
      final result = await auth.api.fetchNotifications();
      for (final n in result.notifications) {
        final isRead = n['is_read'] == 1 || n['is_read'] == true;
        if (isRead) continue;

        final id = n['id'] as String? ?? '';
        if (!take(id)) continue;

        // Skip time-sensitive notifications about past events.
        if (_isStale(n)) {
          _shownIds.add(id);
          continue;
        }

        final type = n['type'] as String? ?? 'notice';
        final bookingId = n['booking_id'] as String?;
        String payload = 'notif:$id';
        if (type == 'workout_complete' && bookingId != null) {
          payload = 'complete:$bookingId';
        } else if (type == 'checkin_reminder' && bookingId != null) {
          payload = 'complete:$bookingId';
        } else if (type == 'community_mention' || type == 'community_comment') {
          final rawPayload = n['payload'];
          String? postId;
          if (rawPayload is Map) postId = rawPayload['post_id'] as String?;
          payload = postId != null ? 'community:$postId' : 'community:';
        } else if (bookingId != null) {
          payload = 'prep:$bookingId';
        } else if (type == 'message') {
          payload = messagePayload(n);
        } else if (type == 'announcement') {
          payload = 'notif:$id';
        }

        await NotificationService.instance.showInstant(
          title: tr(n['title'] as String? ?? tr('Ειδοποίηση')),
          body: n['body'] as String? ?? '',
          payload: payload,
        );
      }
      await _persistShownIds();
    } catch (e) {
      debugPrint('Notification poll failed: $e');
    }
  }

  Future<void> _pollGlobal() async {
    final global = _global;
    if (global == null || !global.isLoggedIn) return;
    try {
      final body = await global.fetchInbox();
      if (body == null) return;
      final items = ((body['notifications'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final n in items) {
        final unread = n['is_read'] != 1 && n['is_read'] != true;
        if (!unread) continue;
        if (_isStale(n)) continue;
        final id = n['id']?.toString() ?? '';
        final created = _createdAt(n);
        if (created != null && DateTime.now().difference(created) > const Duration(minutes: 15)) {
          take(id);
          continue;
        }
        if (!take(id)) continue;
        final type = n['type']?.toString() ?? 'notice';
        final payload = type == 'message' ? messagePayload(n) : 'notif:$id';
        await NotificationService.instance.showInstant(
          title: tr(n['title'] as String? ?? tr('Ειδοποίηση')),
          body: n['body'] as String? ?? '',
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Global notification poll failed: $e');
    }
  }

  String messagePayload(Map<String, dynamic> n) {
    final raw = _payloadMap(n['payload']);
    final threadId = raw['thread_id']?.toString() ?? '';
    return threadId.isNotEmpty ? 'messages:$threadId' : 'messages:open';
  }

  DateTime? _createdAt(Map<String, dynamic> n) {
    final raw = n['created_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
  }

  Map<String, dynamic> _payloadMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  static String platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}
