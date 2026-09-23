import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/tenant_config.dart';
import 'models/booking.dart';
import 'screens/omni_member_shell_screen.dart';
import 'screens/login_screen.dart';
import 'screens/discovery_landing_screen.dart';
import 'services/global_auth_service.dart';
import 'screens/my_orders_screen.dart';
import 'screens/workout_complete_screen.dart';
import 'services/auth_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/user_notification_sync.dart';
import 'screens/staff_home_screen.dart';
import 'screens/admin_shell_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/splash_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class BookUpApp extends StatefulWidget {
  const BookUpApp({super.key, required this.config, required this.auth, this.globalAuth});

  final TenantConfig config;
  final AuthService auth;
  final GlobalAuthService? globalAuth;

  @override
  State<BookUpApp> createState() => _BookUpAppState();
}

class _BookUpAppState extends State<BookUpApp> with WidgetsBindingObserver {
  bool _gymSplashActive = false;
  bool _wasLoggedIn = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = widget.auth.isLoggedIn;
    WidgetsBinding.instance.addObserver(this);
    LanguageService.instance.addListener(_onLocaleChanged);
    NotificationService.instance.onTap = _handleNotificationTap;
    PushService.instance.onTap = _handleNotificationTap;
    widget.auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingNotificationTaps());
    if (widget.auth.isLoggedIn) {
      UserNotificationSync.instance.start(widget.auth);
      PushService.instance.registerWithAuth(widget.auth);
    }
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LanguageService.instance.removeListener(_onLocaleChanged);
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
    final isNowLoggedIn = widget.auth.isLoggedIn;
    if (isNowLoggedIn && !_wasLoggedIn) {
      // Just logged in → show gym splash briefly
      setState(() => _gymSplashActive = true);
      _splashTimer?.cancel();
      _splashTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _gymSplashActive = false);
      });
      UserNotificationSync.instance.start(widget.auth);
      PushService.instance.registerWithAuth(widget.auth);
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingNotificationTaps());
    } else if (!isNowLoggedIn) {
      _splashTimer?.cancel();
      setState(() => _gymSplashActive = false);
      UserNotificationSync.instance.stop();
    }
    _wasLoggedIn = isNowLoggedIn;
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
      OmniMemberShellScreen.openNotifications();
    } else if (action == 'messages') {
      nav.popUntil((route) => route.isFirst);
      OmniMemberShellScreen.openMessages(threadId: parts.length > 1 && parts[1] != 'open' ? parts[1] : null);
    } else if (action == 'community') {
      nav.popUntil((route) => route.isFirst);
    } else if (action == 'order') {
      nav.popUntil((route) => route.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
    } else if (action == 'prep' || action == 'open') {
      nav.popUntil((route) => route.isFirst);
      OmniMemberShellScreen.selectTab(1);
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
      child: Builder(
        builder: (ctx) {
          AppColors.setTenantPrimary(AppColors.fromHex(widget.config.primaryColor));
          return AppColorsTheme(
            primary: AppColors.fromHex(widget.config.primaryColor),
            accent:  AppColors.fromHex(widget.config.accentColor),
            child: MaterialApp(
              navigatorKey: appNavigatorKey,
              title: widget.config.appName,
              debugShowCheckedModeBanner: false,
              locale: LanguageService.instance.locale,
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
                    if (_gymSplashActive) {
                      return const SplashScreen();
                    }
                    if (auth.user!.isAdmin) return const AdminShellScreen();
                    if (auth.user!.isStaff) return const StaffHomeScreen();
                    return const OmniMemberShellScreen();
                  }
                  // Not logged in — show gym discovery with login option
                  return DiscoveryLandingScreen(
                    globalAuth: widget.globalAuth ?? GlobalAuthService(),
                    onLoggedIn: () {
                      // After global login/register, push tenant PIN login
                      // so the user can enter their gym with phone+PIN.
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LoginScreen(
                          globalAuth: widget.globalAuth,
                        )),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
