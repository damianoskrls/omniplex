import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_background.dart';
import '../firebase_options.dart';
import 'auth_service.dart';
import 'notification_service.dart';

typedef PushTapHandler = void Function(String payload);

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _ready = false;
  PushTapHandler? onTap;
  AuthService? _auth;
  String? _pendingTapPayload;

  bool get isReady => _ready;

  Future<bool> init() async {
    if (kIsWeb || _ready) return _ready;
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint('FCM: Firebase δεν είναι ρυθμισμένο — τρέξε flutterfire configure');
      return false;
    }

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);
      messaging.onTokenRefresh.listen(_onTokenRefresh);

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        final payload = payloadFromData(initial.data);
        if (payload.isNotEmpty) _pendingTapPayload = payload;
      }

      _ready = true;
      return true;
    } catch (e) {
      debugPrint('FCM init failed: $e');
      return false;
    }
  }

  Future<void> registerWithAuth(AuthService auth) async {
    _auth = auth;
    if (!_ready || !auth.isLoggedIn) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await auth.api.registerDeviceToken(token, platform: _platformLabel());
      debugPrint('FCM token registered');
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  /// Call before switching gyms so the old gym stops sending pushes to this device.
  Future<void> unregisterFromCurrentGym(AuthService auth) async {
    if (!_ready || !auth.isLoggedIn) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await auth.api.unregisterDeviceToken(token);
      debugPrint('FCM token unregistered from gym ${auth.api.bizId}');
    } catch (e) {
      debugPrint('FCM token unregistration failed (non-critical): $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    final auth = _auth;
    if (auth == null || !auth.isLoggedIn) return;
    try {
      await auth.api.registerDeviceToken(token, platform: _platformLabel());
      debugPrint('FCM token refreshed & registered');
    } catch (e) {
      debugPrint('FCM token refresh registration failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String? ?? 'Ειδοποίηση';
    final body = notification?.body ?? message.data['body'] as String? ?? '';
    final payload = payloadFromData(message.data);
    NotificationService.instance.showInstant(title: title, body: body, payload: payload);
  }

  void _onOpenedFromBackground(RemoteMessage message) {
    _handleRemoteMessage(message, fromTap: true);
  }

  void _handleRemoteMessage(RemoteMessage message, {required bool fromTap}) {
    if (!fromTap) return;
    final payload = payloadFromData(message.data);
    if (payload.isEmpty) return;
    _dispatchTap(payload);
  }

  void _dispatchTap(String payload) {
    final handler = onTap;
    if (handler != null) {
      handler(payload);
    } else {
      _pendingTapPayload = payload;
    }
  }

  /// Call after [onTap] is wired (e.g. from [BookUpApp.initState]).
  String? consumePendingTap() {
    final payload = _pendingTapPayload;
    _pendingTapPayload = null;
    return payload;
  }

  static String payloadFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final bookingId = data['booking_id']?.toString() ?? '';
    final notifId = data['notification_id']?.toString() ?? '';
    final postId = data['post_id']?.toString() ?? '';
    final threadId = data['thread_id']?.toString() ?? '';

    if (type == 'workout_complete' && bookingId.isNotEmpty) {
      return 'complete:$bookingId';
    }
    if (type == 'checkin_reminder' && bookingId.isNotEmpty) {
      return 'complete:$bookingId';
    }
    if ((type == 'community_mention' || type == 'community_comment') && postId.isNotEmpty) {
      return 'community:$postId';
    }
    if (type == 'message' || data['action']?.toString() == 'open_messages') {
      return threadId.isNotEmpty ? 'messages:$threadId' : 'messages:open';
    }
    if (bookingId.isNotEmpty) {
      return 'prep:$bookingId';
    }
    if (notifId.isNotEmpty) {
      return 'notif:$notifId';
    }
    return '';
  }

  static String _platformLabel() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}
