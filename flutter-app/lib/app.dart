import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/tenant_config.dart';
import 'models/booking.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/workout_complete_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/user_notification_sync.dart';
import 'screens/staff_home_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class BookUpApp extends StatefulWidget {
  const BookUpApp({super.key, required this.config, required this.auth});

  final TenantConfig config;
  final AuthService auth;

  @override
  State<BookUpApp> createState() => _BookUpAppState();
}

class _BookUpAppState extends State<BookUpApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.onTap = _handleNotificationTap;
    PushService.instance.onTap = _handleNotificationTap;
    widget.auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingNotificationTaps());
    if (widget.auth.isLoggedIn) {
      UserNotificationSync.instance.start(widget.auth);
      PushService.instance.registerWithAuth(widget.auth);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.auth.removeListener(_onAuthChanged);
    UserNotificationSync.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  void _onAuthChanged() {
    if (widget.auth.isLoggedIn) {
      UserNotificationSync.instance.start(widget.auth);
      PushService.instance.registerWithAuth(widget.auth);
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingNotificationTaps());
    } else {
      UserNotificationSync.instance.stop();
    }
  }

  void _consumePendingNotificationTaps() {
    if (!widget.auth.isLoggedIn) return;
    NotificationService.instance.consumePendingLaunchTap(_handleNotificationTap);
    final pending = PushService.instance.consumePendingTap();
    if (pending != null) _handleNotificationTap(pending);
  }

  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null || !widget.auth.isLoggedIn) return;
    final parts = payload.split(':');
    if (parts.length < 2) return;
    final action = parts[0];
    final bookingId = parts[1];

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    if (action == 'complete') {
      try {
        final booking = await widget.auth.api.fetchBookingDetail(bookingId);
        nav.push(
          MaterialPageRoute(
            builder: (_) => WorkoutCompleteScreen(booking: booking, api: widget.auth.api),
          ),
        );
      } catch (_) {}
    } else if (action == 'notif') {
      nav.popUntil((route) => route.isFirst);
      HomeScreen.openNotifications();
    } else if (action == 'messages') {
      nav.popUntil((route) => route.isFirst);
      HomeScreen.openMessages(threadId: parts.length > 1 && parts[1] != 'open' ? parts[1] : null);
    } else if (action == 'community') {
      nav.popUntil((route) => route.isFirst);
      final postId = parts.length > 1 ? parts[1] : null;
      HomeScreen.openCommunityPost(postId);
    } else if (action == 'prep' || action == 'open') {
      nav.popUntil((route) => route.isFirst);
      HomeScreen.selectTab(1);
    }
  }

  void openWorkoutComplete(Booking booking) {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(booking: booking, api: widget.auth.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.config),
        ChangeNotifierProvider.value(value: widget.auth),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: widget.config.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.fromConfig(widget.config),
        home: Consumer<AuthService>(
          builder: (context, auth, _) {
            if (auth.loading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFB8F55E)),
                ),
              );
            }
            if (auth.reconnecting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F0F12),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFB8F55E)),
                      SizedBox(height: 20),
                      Text('Σύνδεση στον server...',
                          style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
              );
            }
            if (auth.isLoggedIn) {
              if (auth.user!.isStaff) return const StaffHomeScreen();
              return const HomeScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
