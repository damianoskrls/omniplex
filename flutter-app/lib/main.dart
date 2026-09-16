import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'config/tenant_config.dart';
import 'screens/business_selector_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'widgets/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  TenantConfig? _config;
  AuthService? _auth;
  String? _error;
  bool _needsTenantSelection = false;
  String _selectorApiBase = 'https://passionate-grace-production-98ad.up.railway.app';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

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

    // Dynamic mode: check for a cached tenant config first
    final cached = await TenantConfig.getCachedTenant();
    TenantConfig config;

    if (cached != null) {
      // If cached URL is local/dev, clear cache and show selector
      if (cached.apiUrl.contains('192.168') || cached.apiUrl.contains('localhost')) {
        await TenantConfig.clearCachedTenant();
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
          if (!mounted) return;
          setState(() {
            _needsTenantSelection = true;
            _selectorApiBase = config.apiBaseUrl.isNotEmpty ? config.apiBaseUrl : _selectorApiBase;
          });
          return;
        }
      } catch (_) {
        if (!mounted) return;
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
    setState(() => _auth = auth);
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
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _error = null;
      _config = null;
      _auth = null;
      _needsTenantSelection = false;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _resetToSelector() {
    setState(() {
      _config = null;
      _auth = null;
      _error = null;
      _needsTenantSelection = true;
    });
  }

  void _onTenantConfigLoaded(TenantConfig config) {
    setState(() {
      _needsTenantSelection = false;
      _config = config;
      _error = null;
    });
    // Now finish bootstrap with the selected config
    _bootstrapWithConfig(config);
  }

  Future<void> _bootstrapWithConfig(TenantConfig config) async {
    final splashStarted = DateTime.now();
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        final reachErr = await TenantConfig.verifyApiReachable(config.apiBaseUrl);
        if (reachErr != null) throw reachErr;
      }
      final auth = AuthService(config);
      await Future.wait([auth.init(), _waitRemainingSplash(splashStarted)]);
      if (!mounted) return;
      setState(() => _auth = auth);
      unawaited(_initBackgroundServices());
    } catch (e) {
      if (!mounted) return;
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

    if (_needsTenantSelection) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BusinessSelectorScreen(
          onConfigLoaded: _onTenantConfigLoaded,
          apiBaseUrl: _selectorApiBase,
        ),
      );
    }

    if (_config != null && _auth != null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        child: BookUpApp(
          key: const ValueKey('app-ready'),
          config: _config!,
          auth: _auth!,
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(key: ValueKey(_config?.businessId ?? 'splash'), config: _config),
    );
  }
}
