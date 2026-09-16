import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'notification_service.dart';
import 'push_service.dart';

class UserNotificationSync {
  UserNotificationSync._();
  static final UserNotificationSync instance = UserNotificationSync._();

  Timer? _timer;
  DateTime? _since;
  AuthService? _auth;

  void start(AuthService auth) {
    _auth = auth;
    _since = DateTime.now().toUtc();
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _poll());
    _registerPushToken(auth);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _auth = null;
    _since = null;
  }

  Future<void> _registerPushToken(AuthService auth) async {
    if (kIsWeb) return;
    await PushService.instance.registerWithAuth(auth);
  }

  final Set<String> _shownIds = {};

  Future<void> _poll() async {
    final auth = _auth;
    if (auth == null || !auth.isLoggedIn) return;
    try {
      final result = await auth.api.fetchNotifications();
      for (final n in result.notifications) {
        final isRead = n['is_read'] == 1 || n['is_read'] == true;
        if (isRead) continue;
        final id = n['id'] as String? ?? '';
        if (_shownIds.contains(id)) continue;
        _shownIds.add(id);

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
        } else if (type == 'announcement') {
          payload = 'notif:$id';
        }

        await NotificationService.instance.showInstant(
          title: n['title'] as String? ?? 'Ειδοποίηση',
          body: n['body'] as String? ?? '',
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Notification poll failed: $e');
    }
  }

  static String platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}
