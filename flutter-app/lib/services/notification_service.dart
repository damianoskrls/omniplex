import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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
          const AndroidNotificationChannel(
            'bookup_push',
            'Push ειδοποιήσεις',
            description: 'Ειδοποιήσεις από το γυμναστήριο',
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
        title: 'Προετοιμασία — $serviceName',
        body: tipsPreview.isNotEmpty ? tipsPreview : 'Έτοιμασου για την προπόνησή σου!',
        payload: 'prep:$bookingId',
      );
    }

    if (endsAt.isAfter(DateTime.now())) {
      await _schedule(
        id: notificationId + 100000,
        when: endsAt,
        title: 'Τέλος προπόνησης — $serviceName',
        body: 'Πάτα για recovery tips και αξιολόγηση.',
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
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bookup_bookings',
            'Κρατήσεις',
            channelDescription: 'Υπενθυμίσεις και tips προπόνησης',
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bookup_instant',
          'Ειδοποιήσεις',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
