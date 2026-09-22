import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _spin;
  late final AnimationController _pulse;

  late final Animation<double> _fadeIn;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _spin  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    _fadeIn   = CurvedAnimation(parent: _entry, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _logoFade = CurvedAnimation(parent: _entry, curve: const Interval(0.2, 0.6, curve: Curves.easeOut));
    _textFade = CurvedAnimation(parent: _entry, curve: const Interval(0.5, 0.9, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic)));

    _entry.forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background radial gradients
          CustomPaint(painter: _BackgroundPainter()),

          // Corner brackets
          const _CornerBrackets(),

          // Systems ready indicator (top center)
          FadeTransition(
            opacity: _fadeIn,
            child: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: _SystemsReady(),
                ),
              ),
            ),
          ),

          // Main centered content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Crosshair / target icon with glow
                FadeTransition(
                  opacity: _logoFade,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => _CrosshairIcon(pulseValue: _pulse.value),
                  ),
                ),

                const SizedBox(height: 24),

                // OMNIPLEX wordmark
                FadeTransition(
                  opacity: _logoFade,
                  child: _OmniplexWordmark(),
                ),

                const SizedBox(height: 16),

                // Horizontal divider
                FadeTransition(
                  opacity: _textFade,
                  child: Container(
                    width: 64,
                    height: 1,
                    color: const Color(0xFF2A2B30),
                  ),
                ),

                const SizedBox(height: 16),

                // Spinning arc
                FadeTransition(
                  opacity: _textFade,
                  child: AnimatedBuilder(
                    animation: _spin,
                    builder: (_, __) => _SpinningArc(progress: _spin.value),
                  ),
                ),

                const SizedBox(height: 16),

                // OMNIPLEX label
                FadeTransition(
                  opacity: _textFade,
                  child: Text(
                    'OMNIPLEX',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9A9CA3),
                      letterSpacing: 3.85,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Tagline
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: _Tagline(),
                  ),
                ),
              ],
            ),
          ),

          // Bottom label
          FadeTransition(
            opacity: _textFade,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 128, height: 1, color: const Color(0xFF2A2B30)),
                      const SizedBox(height: 12),
                      Text(
                        'PRECISION FITNESS ACCESS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF5A5C63),
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background painter ────────────────────────────────────────────────────────
class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Main lime radial glow (center)
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.38),
      size.width * 0.82,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFC6FF3D).withValues(alpha: 0.16),
          const Color(0xFFC6FF3D).withValues(alpha: 0.05),
          Colors.transparent,
        ], stops: const [0.0, 0.32, 0.6]).createShader(
          Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.38), radius: size.width * 0.82),
        ),
    );
    // Top-right cyan glow
    canvas.drawCircle(
      Offset(size.width - 15, 120),
      80,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFF3EE6FF).withValues(alpha: 0.10),
          Colors.transparent,
        ], stops: const [0.0, 0.7]).createShader(
          Rect.fromCircle(center: Offset(size.width - 15, 120), radius: 80),
        ),
    );
    // Bottom-left lime glow
    canvas.drawCircle(
      Offset(80, size.height - 192),
      64,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFC6FF3D).withValues(alpha: 0.08),
          Colors.transparent,
        ], stops: const [0.0, 0.7]).createShader(
          Rect.fromCircle(center: Offset(80, size.height - 192), radius: 64),
        ),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => false;
}

// ── Corner brackets ───────────────────────────────────────────────────────────
class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Stack(
          fit: StackFit.expand,
          children: const [
            Align(alignment: Alignment.topLeft,     child: _Bracket(corners: {_C.topLeft})),
            Align(alignment: Alignment.topRight,    child: _Bracket(corners: {_C.topRight})),
            Align(alignment: Alignment.bottomLeft,  child: _Bracket(corners: {_C.bottomLeft})),
            Align(alignment: Alignment.bottomRight, child: _Bracket(corners: {_C.bottomRight})),
          ],
        ),
      ),
    );
  }
}

enum _C { topLeft, topRight, bottomLeft, bottomRight }

class _Bracket extends StatelessWidget {
  const _Bracket({required this.corners});
  final Set<_C> corners;

  @override
  Widget build(BuildContext context) {
    final c = corners.first;
    final showTop    = c == _C.topLeft || c == _C.topRight;
    final showBottom = c == _C.bottomLeft || c == _C.bottomRight;
    final showLeft   = c == _C.topLeft || c == _C.bottomLeft;
    final showRight  = c == _C.topRight || c == _C.bottomRight;

    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _BracketPainter(
          showTop: showTop, showBottom: showBottom,
          showLeft: showLeft, showRight: showRight,
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.showTop, required this.showBottom,
    required this.showLeft, required this.showRight,
  });
  final bool showTop, showBottom, showLeft, showRight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A2B30)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    if (showTop)    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), paint);
    if (showBottom) canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
    if (showLeft)   canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
    if (showRight)  canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

// ── Systems ready indicator ───────────────────────────────────────────────────
class _SystemsReady extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFC6FF3D),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'SYSTEMS READY',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF9A9CA3),
            letterSpacing: 3.0,
          ),
        ),
      ],
    );
  }
}

// ── Crosshair icon ────────────────────────────────────────────────────────────
class _CrosshairIcon extends StatelessWidget {
  const _CrosshairIcon({required this.pulseValue});
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    final glowOpacity = 0.7 + pulseValue * 0.3;
    return SizedBox(
      width: 80, height: 80,
      child: CustomPaint(
        painter: _CrosshairPainter(glowOpacity: glowOpacity),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter({required this.glowOpacity});
  final double glowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const lime = Color(0xFFC6FF3D);

    // Outer circle
    canvas.drawCircle(
      Offset(cx, cy),
      cx - 1,
      Paint()
        ..color = lime.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Inner ring
    canvas.drawCircle(
      Offset(cx, cy),
      cx - 13,
      Paint()
        ..color = const Color(0xFF3A3C42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Center dot with glow
    canvas.drawCircle(
      Offset(cx, cy),
      6,
      Paint()
        ..color = lime
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * glowOpacity),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      6,
      Paint()..color = lime,
    );

    // Crosshair lines (top, bottom, left, right)
    final linePaint = Paint()
      ..color = lime
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final fadePaint = Paint()
      ..color = lime.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx, 0), Offset(cx, 8), linePaint);          // top
    canvas.drawLine(Offset(cx, size.height - 8), Offset(cx, size.height), fadePaint); // bottom
    canvas.drawLine(Offset(0, cy), Offset(8, cy), fadePaint);           // left
    canvas.drawLine(Offset(size.width - 8, cy), Offset(size.width, cy), fadePaint); // right
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.glowOpacity != glowOpacity;
}

// ── OMNIPLEX wordmark ─────────────────────────────────────────────────────────
class _OmniplexWordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.spaceGrotesk(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1,
        ),
        children: const [
          TextSpan(text: 'OMNI', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'PLEX', style: TextStyle(color: Color(0xFFC6FF3D))),
        ],
      ),
    );
  }
}

// ── Spinning arc ──────────────────────────────────────────────────────────────
class _SpinningArc extends StatelessWidget {
  const _SpinningArc({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56, height: 56,
      child: CustomPaint(
        painter: _ArcPainter(progress: progress),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const cyan = Color(0xFF3EE6FF);

    // Outer border circle
    canvas.drawCircle(
      Offset(cx, cy),
      cx - 0.5,
      Paint()
        ..color = const Color(0xFF26272C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      3,
      Paint()..color = cyan,
    );

    // Spinning arc (270° sweep, rotating)
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: cx - 0.5);
    canvas.drawArc(
      rect,
      progress * 2 * math.pi - math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = cyan.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Tagline ───────────────────────────────────────────────────────────────────
class _Tagline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF9A9CA3),
          height: 1.625,
        ),
        children: const [
          TextSpan(text: 'Your gyms. Your schedule. '),
          TextSpan(text: 'Your access.', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
