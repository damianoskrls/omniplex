import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.config});

  final TenantConfig? config;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final appName = config?.appName ?? 'Handstand';

    final body = Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1035), AppColors.bg, Color(0xFF0D1F1A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                const Spacer(flex: 3),
                ScaleTransition(
                  scale: _scale,
                  child: _SplashLogo(config: config, size: 112),
                ),
                const SizedBox(height: 28),
                Text(
                  appName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  config?.label('home_hero', 'Κράτησε εύκολα το επόμενο ραντεβού σου.') ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const Spacer(flex: 4),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.lime,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );

    if (config == null) return body;
    return Provider.value(value: config, child: body);
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({required this.config, required this.size});

  final TenantConfig? config;
  final double size;

  @override
  Widget build(BuildContext context) {
    final networkUrl = config == null ? null : resolveMediaUrl(config!, config!.logoUrl);

    Widget logo = Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        if (networkUrl != null) {
          return Image.network(
            networkUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallback(),
          );
        }
        return _fallback();
      },
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: 0.18),
            blurRadius: 40,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: logo,
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.purple, AppColors.pink]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(Icons.fitness_center, color: Colors.white, size: size * 0.45),
    );
  }
}
