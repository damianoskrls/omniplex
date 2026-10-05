import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../l10n/tr.dart';


typedef NotificationTapHandler = void Function(String? payload);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  NotificationTapHandler? onTap;
  bool _ready = false;
  String? _pendingLaunchPayload;

  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Athens'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        onTap?.call(details.payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            'bookup_push',
            tr('Push ειδοποιήσεις'),
            description: tr('Ειδοποιήσεις από το γυμναστήριο'),
            importance: Importance.high,
          ),
        );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingLaunchPayload = launchDetails?.notificationResponse?.payload;
    }

    _ready = true;
  }

  /// Call after [onTap] is wired (e.g. from [BookUpApp.initState]).
  void consumePendingLaunchTap(NotificationTapHandler handler) {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    if (payload != null && payload.isNotEmpty) handler(payload);
  }

  Future<void> scheduleBookingReminders({
    required int notificationId,
    required String bookingId,
    required String serviceName,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<String> preparationTips,
  }) async {
    if (!_ready) return;

    final prepTime = startsAt.subtract(const Duration(hours: 1));
    if (prepTime.isAfter(DateTime.now())) {
      final tipsPreview = preparationTips.take(2).join(' · ');
      await _schedule(
        id: notificationId,
        when: prepTime,
        title: tr('Προετοιμασία — $serviceName'),
        body: tipsPreview.isNotEmpty ? tipsPreview : tr('Έτοιμασου για την προπόνησή σου!'),
        payload: 'prep:$bookingId',
      );
    }

    if (endsAt.isAfter(DateTime.now())) {
      await _schedule(
        id: notificationId + 100000,
        when: endsAt,
        title: tr('Τέλος προπόνησης — $serviceName'),
        body: tr('Πάτα για recovery tips και αξιολόγηση.'),
        payload: 'complete:$bookingId',
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'bookup_bookings',
            tr('Κρατήσεις'),
            channelDescription: tr('Υπενθυμίσεις και tips προπόνησης'),
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Notification schedule failed: $e');
    }
  }

  Future<void> showInstant({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'bookup_push',
          tr('Push ειδοποιήσεις'),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Resets the iOS app icon badge count to zero.
  Future<void> clearBadge() async {
    if (!_ready) return;
    try {
      // Show a silent invisible notification with badge=0 then immediately cancel it.
      const id = 99999;
      await _plugin.show(
        id,
        '',
        '',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            presentBadge: true,
            badgeNumber: 0,
          ),
        ),
      );
      await _plugin.cancel(id);
    } catch (_) {}
  }
}
