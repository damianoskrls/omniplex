import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'app_nav.dart';
import 'config/tenant_config.dart';
import 'l10n/app_strings.dart';
import 'screens/business_selector_screen.dart';
import 'screens/discovery_landing_screen.dart';
import 'screens/global_auth_gate_screen.dart';
import 'screens/global_dashboard_screen.dart';
import 'screens/global_member_home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/biometric_auth_service.dart';
import 'services/global_auth_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'widgets/splash_screen.dart' show SplashScreen, GymSplashScreen;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.instance.load();
  LanguageService.instance.addListener(() {
    updateLanguageBridge(LanguageService.instance.locale.languageCode);
  });
  updateLanguageBridge(LanguageService.instance.locale.languageCode);
  runApp(AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  AppBootstrap() : super(key: _globalKey);

  static final _globalKey = GlobalKey<_AppBootstrapState>();

  /// Call this to reset to the business selector (e.g. "switch business").
  static void switchBusiness() => _globalKey.currentState?._resetToSelector();

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  static const _minSplash = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    AppNav.leaveGym = _resetToSelector;
    AppNav.enterAsRole = _enterAsRole;
    LanguageService.instance.addListener(_onLanguageChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  TenantConfig? _config;
  AuthService? _auth;
  String? _error;
  bool _needsTenantSelection = false;
  bool _showOnboarding = false;
  bool _showAuthGate   = false;
  bool _showGlobalDashboard = false;
  bool _showExplore    = false; // guest explore without login
  bool _switchingRole  = false;
  final _globalAuth = GlobalAuthService();
  String _selectorApiBase = 'https://passionate-grace-production-98ad.up.railway.app';

  Future<void> _bootstrap() async {
    final splashStarted = DateTime.now();
    try {
      await _bootstrapInternal(splashStarted).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Η εκκίνηση καθυστερεί πολύ'),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'Η εκκίνηση καθυστερεί. Έλεγξε ότι τρέχει το admin-api (θύρα 3001) και δοκίμασε ξανά.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _bootstrapInternal(DateTime splashStarted) async {
    if (!kIsWeb && Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }

    unawaited(
      initializeDateFormatting('el_GR').timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      ),
    );

    // Load global auth state
    await _globalAuth.init();

    // Dynamic mode: check for a cached tenant config first
    final cached = await TenantConfig.getCachedTenant();
    TenantConfig config;

    if (cached != null) {
      // If cached URL is local/dev, clear cache and show selector
      if (cached.apiUrl.contains('192.168') || cached.apiUrl.contains('localhost')) {
        await TenantConfig.clearCachedTenant();
        await _waitRemainingSplash(splashStarted);
        if (!mounted) return;
        setState(() => _needsTenantSelection = true);
        return;
      }
      config = await TenantConfig.loadFromApi(
        slug: cached.slug,
        apiBaseUrl: cached.apiUrl,
      );
    } else {
      // Try static asset config; if missing or no business_id, show selector
      try {
        config = await TenantConfig.load();
        // Verify it has a meaningful business — if it's a placeholder, show selector
        if (config.businessId.isEmpty || config.slug.isEmpty) {
          await _waitRemainingSplash(splashStarted);
          if (!mounted) return;
          // If global user with 2+ gyms, show dashboard instead of selector
          if (_globalAuth.isLoggedIn && _globalAuth.gyms.length >= 2) {
            setState(() => _showGlobalDashboard = true);
            return;
          }
          setState(() {
            _needsTenantSelection = true;
            _selectorApiBase = config.apiBaseUrl.isNotEmpty ? config.apiBaseUrl : _selectorApiBase;
          });
          return;
        }
      } catch (_) {
        await _waitRemainingSplash(splashStarted);
        if (!mounted) return;
        if (_globalAuth.isLoggedIn && _globalAuth.gyms.length >= 2) {
          setState(() => _showGlobalDashboard = true);
          return;
        }
        setState(() => _needsTenantSelection = true);
        return;
      }
    }

    if (!mounted) return;

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      final reachErr = await TenantConfig.verifyApiReachable(config.apiBaseUrl);
      if (reachErr != null) {
        throw reachErr;
      }
    }

    setState(() => _config = config);

    final auth = AuthService(config);
    await Future.wait([
      auth.init(),
      _waitRemainingSplash(splashStarted),
    ]);

    if (!mounted) return;
    final seenOnboarding = await hasSeenOnboarding();
    if (!mounted) return;
    if (!seenOnboarding) {
      setState(() { _auth = auth; _showOnboarding = true; });
    } else {
      setState(() => _auth = auth);
    }
    unawaited(_initBackgroundServices());
  }

  Future<void> _waitRemainingSplash(DateTime started) async {
    final elapsed = DateTime.now().difference(started);
    final remaining = _minSplash - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<void> _initBackgroundServices() async {
    try {
      await NotificationService.instance.init();
      await PushService.instance.init();
      await PushService.instance.registerGlobal(_globalAuth);
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _error = null;
      _config = null;
      _auth = null;
      _needsTenantSelection = false;
      _showAuthGate = false;
      _showExplore  = false;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _resetToSelector() {
    setState(() {
      _config = null;
      _auth = null;
      _error = null;
      _needsTenantSelection = true;
      _showAuthGate = false;
      _showExplore  = false;
    });
  }

  Future<void> _enterAsRole(GlobalGym gym) async {
    if (_switchingRole) return;
    setState(() => _switchingRole = true);
    try {
      final gymToken = gym.isStaff
          ? await _globalAuth.getTrainerToken(gym.businessId, asKind: gym.staffKind)
          : await _globalAuth.getGymToken(gym.businessId);
      await BiometricAuthService.instance.setBiometricEnabled(gym.businessId, false);
      await BiometricAuthService.instance.saveToken(gym.businessId, gymToken);
      final config = (_config != null && _config!.businessId == gym.businessId)
          ? _config!
          : await TenantConfig.loadFromApi(
              slug: gym.slug,
              apiBaseUrl: 'https://passionate-grace-production-98ad.up.railway.app',
            );
      await _bootstrapWithConfig(config, quick: true);
    } finally {
      if (mounted) setState(() => _switchingRole = false);
    }
  }

  void _onTenantConfigLoaded(TenantConfig config) {
    debugPrint('[TenantLoaded] slug=${config.slug} bizId=${config.businessId}');
    setState(() {
      _needsTenantSelection = false;
      _config = config;
      _error = null;
    });
    // Now finish bootstrap with the selected config
    _bootstrapWithConfig(config);
  }

  Future<void> _bootstrapWithConfig(TenantConfig config, {bool quick = false}) async {
    final splashStarted = DateTime.now();
    debugPrint('[Bootstrap] Starting for slug=${config.slug} bizId=${config.businessId} quick=$quick');
    try {
      if (!quick && !kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        final reachErr = await TenantConfig.verifyApiReachable(config.apiBaseUrl);
        if (reachErr != null) throw reachErr;
      }
      final auth = AuthService(config);
      if (quick) {
        await auth.init();
      } else {
        await Future.wait([auth.init(), _waitRemainingSplash(splashStarted)]);
      }
      debugPrint('[Bootstrap] auth.isLoggedIn=${auth.isLoggedIn}');
      if (!mounted) return;
      final seenOnboarding = await hasSeenOnboarding();
      if (!mounted) return;
      if (!seenOnboarding) {
        setState(() { _auth = auth; _showOnboarding = true; });
      } else {
        setState(() => _auth = auth);
      }
      unawaited(_initBackgroundServices());
    } catch (e) {
      debugPrint('[Bootstrap] ERROR: $e');
      if (!mounted) return;
      if (quick) rethrow;
      setState(() { _error = e.toString(); _config = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F0F12),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _retry, child: const Text('Δοκίμασε ξανά')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_showGlobalDashboard) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GlobalMemberHomeScreen(
          globalAuth: _globalAuth,
          onEnterGym: (config) {
            setState(() => _showGlobalDashboard = false);
            _onTenantConfigLoaded(config);
          },
          onLogout: () {
            setState(() { _showGlobalDashboard = false; _needsTenantSelection = true; });
          },
        ),
      );
    }

    if (_needsTenantSelection) {
      if (_globalAuth.isLoggedIn) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: GlobalMemberHomeScreen(
            globalAuth: _globalAuth,
            onEnterGym: (config) {
              setState(() { _needsTenantSelection = false; _showGlobalDashboard = false; });
              _onTenantConfigLoaded(config);
            },
            onLogout: () => setState(() {
              _needsTenantSelection = true;
              _showGlobalDashboard = false;
            }),
          ),
        );
      }
      // Guest explore (after tapping "Συνέχεια ως επισκέπτης")
      if (_showExplore) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: DiscoveryLandingScreen(
            globalAuth: _globalAuth,
            onLoggedIn: () => setState(() { _showExplore = false; }),
            onEnterGym: (config) {
              setState(() { _showExplore = false; _needsTenantSelection = false; });
              _onTenantConfigLoaded(config);
            },
          ),
        );
      }
      // Auth Gate: primary = login, secondary = explore as guest
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GlobalAuthGateScreen(
          globalAuth: _globalAuth,
          onLogin: () => setState(() {}),
          onExplore: () => setState(() { _showExplore = true; }),
        ),
      );
    }

    if (_config != null && _auth != null && _showOnboarding) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: OnboardingScreen(
          onDone: () {
            if (!_globalAuth.isLoggedIn) {
              setState(() { _showOnboarding = false; _showAuthGate = true; });
            } else {
              setState(() => _showOnboarding = false);
            }
          },
        ),
      );
    }

    if (_config != null && _auth != null && _showAuthGate) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GlobalAuthGateScreen(
          globalAuth: _globalAuth,
          onLogin: () => setState(() { _showAuthGate = false; }),
          onExplore: () => setState(() { _showAuthGate = false; }),
        ),
      );
    }

    if (_config != null && _auth != null) {
      final user = _auth!.user;
      return Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOut,
            child: BookUpApp(
              key: ValueKey('app-${user?.id}-${user?.isStaff}-${user?.staffKind}'),
              config: _config!,
              auth: _auth!,
              globalAuth: _globalAuth,
              onEnterGym: _onTenantConfigLoaded,
              onEnterAsRole: _enterAsRole,
              onSwitchGym: _resetToSelector,
              onRemoveGym: _globalAuth.isLoggedIn
                  ? () async {
                      final role = _auth?.user?.isStaff == true ? 'staff' : 'member';
                      await _auth?.logout();
                      await _globalAuth.removeGym(_config!.businessId, role: role);
                      _resetToSelector();
                    }
                  : null,
            ),
          ),
          if (_switchingRole)
            const ColoredBox(
              color: Color(0xCC000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFB8F55E)),
                    SizedBox(height: 16),
                    Text('Αλλαγή ρόλου...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(key: const ValueKey('splash')),
    );
  }
}
