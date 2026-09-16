import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/tenant_config.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.config});
  final TenantConfig? config;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _pulse;
  late final AnimationController _orb;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _dotsOpacity;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _orb   = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat();

    _logoScale   = CurvedAnimation(parent: _entry, curve: const Interval(0, 0.6, curve: Curves.easeOutBack));
    _logoOpacity = CurvedAnimation(parent: _entry, curve: const Interval(0, 0.4, curve: Curves.easeOut));
    _textOpacity = CurvedAnimation(parent: _entry, curve: const Interval(0.45, 0.85, curve: Curves.easeOut));
    _textSlide   = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic)));
    _dotsOpacity = CurvedAnimation(parent: _entry, curve: const Interval(0.75, 1, curve: Curves.easeOut));

    _entry.forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    _orb.dispose();
    super.dispose();
  }

  bool get _hasGym => widget.config != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient orb background
          AnimatedBuilder(
            animation: _orb,
            builder: (_, __) => CustomPaint(
              painter: _OrbPainter(
                progress: _orb.value,
                hasGym: _hasGym,
                gymColor: _hasGym ? _gymColor() : null,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: _hasGym ? _GymLogo(config: widget.config!) : _OmniplexLogo(),
                  ),
                ),

                const SizedBox(height: 32),

                // Name / wordmark
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: _hasGym ? _GymTitle(config: widget.config!) : _OmniplexWordmark(),
                  ),
                ),

                const Spacer(flex: 3),

                // Loading indicator
                FadeTransition(
                  opacity: _dotsOpacity,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => _LoadingDots(progress: _pulse.value),
                  ),
                ),

                const SizedBox(height: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _gymColor() {
    try {
      return Color(int.parse(widget.config!.primaryColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.lime;
    }
  }
}

// ── Omniplex logo (asset or stylized fallback) ────────────────────────────────
class _OmniplexLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow rings
        Container(
          width: 148, height: 148,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.lime.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 128, height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.lime.withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Logo
        Container(
          width: 104, height: 104,
          decoration: BoxDecoration(
            color: const Color(0xFF111118),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lime.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppColors.lime.withValues(alpha: 0.18), blurRadius: 48, spreadRadius: 4),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _FallbackMark(size: 104),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Gym logo (from network) ───────────────────────────────────────────────────
class _GymLogo extends StatelessWidget {
  const _GymLogo({required this.config});
  final TenantConfig config;

  Color get _primary {
    try { return Color(int.parse(config.primaryColor.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.lime; }
  }

  @override
  Widget build(BuildContext context) {
    final networkUrl = resolveMediaUrl(config, config.logoUrl);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 160, height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [_primary.withValues(alpha: 0.10), Colors.transparent]),
          ),
        ),
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF111118),
            shape: BoxShape.circle,
            border: Border.all(color: _primary.withValues(alpha: 0.30), width: 1.5),
            boxShadow: [
              BoxShadow(color: _primary.withValues(alpha: 0.22), blurRadius: 56, spreadRadius: 6),
            ],
          ),
          child: ClipOval(
            child: networkUrl != null
                ? Image.network(
                    networkUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _FallbackMark(size: 120, color: _primary),
                  )
                : _FallbackMark(size: 120, color: _primary),
          ),
        ),
      ],
    );
  }
}

// ── Wordmarks ─────────────────────────────────────────────────────────────────
class _OmniplexWordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'sans-serif',
              letterSpacing: 5,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
            children: [
              TextSpan(
                text: 'OMNI',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
              ),
              const TextSpan(
                text: 'PLEX',
                style: TextStyle(color: AppColors.lime),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'FITNESS MANAGEMENT',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.22),
            fontSize: 11,
            letterSpacing: 3.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GymTitle extends StatelessWidget {
  const _GymTitle({required this.config});
  final TenantConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          config.appName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 24, height: 1, color: Colors.white12),
            const SizedBox(width: 10),
            Text(
              'ΣΥΝΔΕΣΗ...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.30),
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 24, height: 1, color: Colors.white12),
          ],
        ),
      ],
    );
  }
}

// ── Loading dots ──────────────────────────────────────────────────────────────
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i / 3;
        final t = ((progress - delay) % 1.0).clamp(0.0, 1.0);
        final opacity = (math.sin(t * math.pi)).clamp(0.15, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 5, height: 5,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Background orb painter ────────────────────────────────────────────────────
class _OrbPainter extends CustomPainter {
  const _OrbPainter({required this.progress, required this.hasGym, this.gymColor});
  final double progress;
  final bool hasGym;
  final Color? gymColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final accent = gymColor ?? AppColors.lime;

    // Slow-drifting orb
    final ox = cx + math.sin(progress * math.pi * 2) * size.width * 0.08;
    final oy = cy + math.cos(progress * math.pi * 2 * 0.7) * size.height * 0.06;

    canvas.drawCircle(
      Offset(ox, oy),
      size.width * 0.65,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.045),
            accent.withValues(alpha: 0.02),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(ox, oy), radius: size.width * 0.65)),
    );

    // Bottom accent
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height),
      size.width * 0.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height),
          radius: size.width * 0.4,
        )),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.progress != progress;
}

// ── Fallback mark ─────────────────────────────────────────────────────────────
class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size, this.color = AppColors.lime});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      color: const Color(0xFF111118),
      child: Center(
        child: Text(
          'O',
          style: TextStyle(
            color: color,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
          ),
        ),
      ),
    );
  }
}
