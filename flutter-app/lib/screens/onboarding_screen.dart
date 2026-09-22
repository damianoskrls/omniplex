import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingKey = 'omniplex_onboarding_done';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

// ── Color constants ──────────────────────────────────────────────────────────
const _bg     = Color(0xFF0A0A0A);
const _lime   = Color(0xFFC6FF3D);
const _gray   = Color(0xFF9A9CA3);
const _border = Color(0xFF2A2B30);
const _card   = Color(0xFF16171B);
const _dim    = Color(0xFF3A3C42);

// ── Slide data ───────────────────────────────────────────────────────────────
class _Slide {
  const _Slide({
    required this.step,
    required this.title,
    required this.body,
    required this.buildVisual,
    required this.buttonLabel,
  });
  final String step;
  final String title;
  final String body;
  final Widget Function(BuildContext ctx, AnimationController spin, double pulse) buildVisual;
  final String buttonLabel;
}

// ── Main screen ──────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _page = 0;

  late final AnimationController _spinCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  late final List<_Slide> _slides;

  @override
  void initState() {
    super.initState();
    _spinCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _entryFade  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _slides = [
      _Slide(
        step: 'Step 01 of 03',
        title: 'All your gyms.\nOne app.',
        body: 'Manage your gym memberships, bookings\nand access from one place.',
        buttonLabel: 'Next',
        buildVisual: (ctx, spin, pulse) => _Slide1Visual(pulse: pulse),
      ),
      _Slide(
        step: 'Step 02 of 03',
        title: 'Discover. Book.\nTrain.',
        body: 'Discover gyms, classes and activities\nand book in seconds.',
        buttonLabel: 'Next',
        buildVisual: (ctx, spin, pulse) => const _Slide2Visual(),
      ),
      _Slide(
        step: 'Step 03 of 03',
        title: 'Walk in. Scan.\nTrain.',
        body: 'Use your OmniPlex QR access to quickly\nenter your connected gyms.',
        buttonLabel: 'Get Started',
        buildVisual: (ctx, spin, pulse) => _Slide3Visual(spin: spin.value),
      ),
    ];
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await markOnboardingDone();
    widget.onDone();
  }

  void _onPageChanged(int p) {
    setState(() => _page = p);
    _entryCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          CustomPaint(painter: _OnboardingBgPainter()),

          // Corner brackets
          const _CornerBrackets(),

          // Page content
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount: _slides.length,
            itemBuilder: (ctx, i) => _buildSlide(ctx, _slides[i]),
          ),

          // Skip button
          if (_page < _slides.length - 1)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 80, right: 24),
                  child: GestureDetector(
                    onTap: _finish,
                    child: Text(
                      'SKIP',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: _gray,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pagination dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            color: active ? _lime : _dim,
                            boxShadow: active ? [
                              BoxShadow(color: _lime.withValues(alpha: 0.7), blurRadius: 8),
                            ] : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Button
                    GestureDetector(
                      onTap: _next,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _lime,
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: [
                            BoxShadow(color: _lime.withValues(alpha: 0.35), blurRadius: 12),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              slide.buttonLabel,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _bg,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, color: _bg, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(BuildContext ctx, _Slide slide) {
    return Column(
      children: [
        // Visual area
        Expanded(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 112, 24, 32),
              child: AnimatedBuilder(
                animation: Listenable.merge([_spinCtrl, _pulseCtrl]),
                builder: (ctx, _) => slide.buildVisual(ctx, _spinCtrl, _pulseCtrl.value),
              ),
            ),
          ),
        ),

        // Text section
        FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 148),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    slide.step.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: _gray,
                      letterSpacing: 3.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.75,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    slide.body,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _gray,
                      height: 1.625,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Slide 1: Gym cards with crosshair ────────────────────────────────────────
class _Slide1Visual extends StatelessWidget {
  const _Slide1Visual({required this.pulse});
  final double pulse;

  static const _gyms = [
    (name: 'Fitness Club', loc: 'Athens',     img: 'https://www.figma.com/api/mcp/asset/91b13e12-4532-48bb-b294-c27e389f0e48.png'),
    (name: 'Urban',        loc: 'Fitness',    img: 'https://www.figma.com/api/mcp/asset/e0ed5651-266f-4b29-a1d4-cc64eebe7e1f.png'),
    (name: 'Iron Works',   loc: 'Gym',        img: 'https://www.figma.com/api/mcp/asset/f200db39-ecc6-4c23-8529-fd8bf59c6b6b.png'),
    (name: 'Apex',         loc: 'Studio',     img: 'https://www.figma.com/api/mcp/asset/58c6ec8c-b7fa-4ffe-b9be-44d973db21b9.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final glowOpacity = 0.6 + pulse * 0.4;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow behind
        Container(
          width: 256, height: 256,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _lime.withValues(alpha: 0.22),
              _lime.withValues(alpha: 0.06),
              Colors.transparent,
            ], stops: const [0.0, 0.45, 0.72]),
          ),
        ),
        // Top-left card (higher)
        Positioned(
          left: 0, top: 0,
          child: _GymCard(name: _gyms[0].name, sub: _gyms[0].loc, imgUrl: _gyms[0].img),
        ),
        // Top-right card (slightly higher)
        Positioned(
          right: 0, top: -8,
          child: _GymCard(name: _gyms[1].name, sub: _gyms[1].loc, imgUrl: _gyms[1].img),
        ),
        // Bottom-left card
        Positioned(
          left: 4, bottom: -8,
          child: _GymCard(name: _gyms[2].name, sub: _gyms[2].loc, imgUrl: _gyms[2].img),
        ),
        // Bottom-right card
        Positioned(
          right: 4, bottom: -16,
          child: _GymCard(name: _gyms[3].name, sub: _gyms[3].loc, imgUrl: _gyms[3].img),
        ),
        // Crosshair center
        SizedBox(
          width: 80, height: 80,
          child: CustomPaint(painter: _CrosshairPainter(glowOpacity: glowOpacity)),
        ),
      ],
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({required this.name, required this.sub, required this.imgUrl});
  final String name;
  final String sub;
  final String imgUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128, height: 160,
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(imgUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1F24))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(sub, style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide 2: Activity cards ───────────────────────────────────────────────────
class _Slide2Visual extends StatelessWidget {
  const _Slide2Visual();

  static const _activities = [
    (name: 'CrossFit',  count: '42 classes nearby', img: 'https://www.figma.com/api/mcp/asset/be845761-3716-45d0-ba05-0ac2277b78ec.png', color: Color(0xFFB48CFF)),
    (name: 'Yoga',      count: '28 classes nearby', img: 'https://www.figma.com/api/mcp/asset/eb5ebc40-66eb-4b33-8375-d8a02ae8239c.png', color: Color(0xFF3EE6FF)),
    (name: 'Pilates',   count: '19 classes nearby', img: 'https://www.figma.com/api/mcp/asset/22fc810f-1907-4c2b-a81d-c59133e40dec.png', color: _lime),
    (name: 'Strength',  count: '35 classes nearby', img: 'https://www.figma.com/api/mcp/asset/cddcdd25-3f31-49bc-b7f0-3e0b336bcee2.png', color: _lime),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Column(
                  children: [
                    _ActivityCard(item: _activities[0]),
                    const SizedBox(height: 12),
                    _ActivityCard(item: _activities[2], offsetTop: -8),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right column (offset down)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    children: [
                      _ActivityCard(item: _activities[1]),
                      const SizedBox(height: 12),
                      _ActivityCard(item: _activities[3]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // "120+ activities" pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _card,
            border: Border.all(color: _dim),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text('120+ activities', style: GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item, this.offsetTop = 0});
  final ({String name, String count, String img, Color color}) item;
  final double offsetTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(item.img, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1F24))),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFF0A0A0A).withValues(alpha: 0.85),
                        const Color(0xFF0A0A0A).withValues(alpha: 0.1),
                      ],
                      stops: const [0.0, 0.6],
                    ),
                  ),
                ),
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A).withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: item.color),
                      boxShadow: [BoxShadow(color: item.color.withValues(alpha: 0.5), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.fitness_center, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(item.count, style: GoogleFonts.manrope(
                  fontSize: 10, color: _gray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide 3: QR scanner visual ────────────────────────────────────────────────
class _Slide3Visual extends StatelessWidget {
  const _Slide3Visual({required this.spin});
  final double spin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background gym image
          Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gym entrance photo
                Image.network(
                  'https://www.figma.com/api/mcp/asset/a46995c8-641e-48fe-9675-3c64103af2d5.png',
                  height: 325,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 325, color: const Color(0xFF0D1117)),
                ),
                // Dark gradient overlay
                Container(
                  height: 325,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0A0A0A).withValues(alpha: 0.15),
                        const Color(0xFF0A0A0A).withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),

                // Cyan corner brackets on image
                ..._buildImageBrackets(),

                // QR phone mockup
                _QrPhoneMockup(spin: spin),
              ],
            ),
          ),

          // "Instant access" pill at bottom
          Positioned(
            bottom: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _card,
                border: Border.all(color: _dim),
                borderRadius: BorderRadius.circular(9999),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 10))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text('Instant access, every gym', style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildImageBrackets() {
    const cyan = Color(0xFF3EE6FF);
    const size = 40.0;
    const thick = 2.0;
    return [
      Positioned(top: 24, left: 24, child: _ImageBracket(corner: _C.topLeft, color: cyan, size: size, thick: thick)),
      Positioned(top: 24, right: 24, child: _ImageBracket(corner: _C.topRight, color: cyan, size: size, thick: thick)),
      Positioned(bottom: 24, left: 24, child: _ImageBracket(corner: _C.bottomLeft, color: cyan, size: size, thick: thick)),
      Positioned(bottom: 24, right: 24, child: _ImageBracket(corner: _C.bottomRight, color: cyan, size: size, thick: thick)),
    ];
  }
}

class _QrPhoneMockup extends StatelessWidget {
  const _QrPhoneMockup({required this.spin});
  final double spin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128, height: 224,
      decoration: BoxDecoration(
        color: const Color(0xFF16171B),
        border: Border.all(color: const Color(0xFF5A5C63), width: 2),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _lime.withValues(alpha: 0.25), blurRadius: 30),
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera texture
            Opacity(
              opacity: 0.7,
              child: Image.network(
                'https://www.figma.com/api/mcp/asset/7217b19b-1e77-4ed6-8742-602cfce3aaee.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A0A0A)),
              ),
            ),
            // Dark overlay
            Container(color: Colors.black.withValues(alpha: 0.4)),

            // QR corners
            Center(
              child: SizedBox(
                width: 64, height: 64,
                child: CustomPaint(painter: _QrCornersPainter()),
              ),
            ),

            // Scanning line
            Center(
              child: Container(
                width: 64, height: 2,
                decoration: BoxDecoration(
                  color: _lime,
                  boxShadow: [BoxShadow(color: _lime.withValues(alpha: 0.9), blurRadius: 10)],
                ),
              ),
            ),

            // "SCANNING" badge at bottom
            Positioned(
              bottom: 8,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A).withValues(alpha: 0.8),
                    border: Border.all(color: _lime),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text('SCANNING', style: GoogleFonts.spaceGrotesk(
                    fontSize: 7, fontWeight: FontWeight.w700,
                    color: _lime, letterSpacing: 0.175)),
                ),
              ),
            ),

            // Notch
            Positioned(
              top: 6,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  width: 40, height: 10,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background painter ────────────────────────────────────────────────────────
class _OnboardingBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.30),
      size.width * 0.88,
      Paint()
        ..shader = RadialGradient(colors: [
          _lime.withValues(alpha: 0.14),
          _lime.withValues(alpha: 0.04),
          Colors.transparent,
        ], stops: const [0.0, 0.32, 0.6]).createShader(
          Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.30), radius: size.width * 0.88),
        ),
    );
  }

  @override
  bool shouldRepaint(_OnboardingBgPainter old) => false;
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
            Align(alignment: Alignment.topLeft,     child: _Bracket(corner: _C.topLeft)),
            Align(alignment: Alignment.topRight,    child: _Bracket(corner: _C.topRight)),
            Align(alignment: Alignment.bottomLeft,  child: _Bracket(corner: _C.bottomLeft)),
            Align(alignment: Alignment.bottomRight, child: _Bracket(corner: _C.bottomRight)),
          ],
        ),
      ),
    );
  }
}

enum _C { topLeft, topRight, bottomLeft, bottomRight }

class _Bracket extends StatelessWidget {
  const _Bracket({required this.corner});
  final _C corner;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24, height: 24,
      child: CustomPaint(painter: _BracketPainter(corner: corner, color: _border)),
    );
  }
}

class _ImageBracket extends StatelessWidget {
  const _ImageBracket({required this.corner, required this.color, required this.size, required this.thick});
  final _C corner;
  final Color color;
  final double size;
  final double thick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(painter: _BracketPainter(corner: corner, color: color, thickness: thick, radius: 12)),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({required this.corner, required this.color, this.thickness = 1, this.radius = 0});
  final _C corner;
  final Color color;
  final double thickness;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final showTop    = corner == _C.topLeft || corner == _C.topRight;
    final showBottom = corner == _C.bottomLeft || corner == _C.bottomRight;
    final showLeft   = corner == _C.topLeft || corner == _C.bottomLeft;
    final showRight  = corner == _C.topRight || corner == _C.bottomRight;

    if (radius > 0) {
      // Rounded bracket for image overlay
      final path = Path();
      if (corner == _C.topLeft) {
        path.moveTo(0, size.height);
        path.lineTo(0, radius);
        path.quadraticBezierTo(0, 0, radius, 0);
        path.lineTo(size.width, 0);
      } else if (corner == _C.topRight) {
        path.moveTo(0, 0);
        path.lineTo(size.width - radius, 0);
        path.quadraticBezierTo(size.width, 0, size.width, radius);
        path.lineTo(size.width, size.height);
      } else if (corner == _C.bottomLeft) {
        path.moveTo(0, 0);
        path.lineTo(0, size.height - radius);
        path.quadraticBezierTo(0, size.height, radius, size.height);
        path.lineTo(size.width, size.height);
      } else {
        path.moveTo(0, size.height);
        path.lineTo(size.width - radius, size.height);
        path.quadraticBezierTo(size.width, size.height, size.width, size.height - radius);
        path.lineTo(size.width, 0);
      }
      final shadowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = thickness + 8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, paint);
    } else {
      if (showTop)    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), paint);
      if (showBottom) canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
      if (showLeft)   canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
      if (showRight)  canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

// ── QR corners painter ────────────────────────────────────────────────────────
class _QrCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _lime
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    const arm = 16.0;

    // Shadow paint
    final shadowPaint = Paint()
      ..color = _lime.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final corners = [
      [Offset(0, arm), Offset(0, 0), Offset(arm, 0)],             // TL
      [Offset(size.width - arm, 0), Offset(size.width, 0), Offset(size.width, arm)], // TR
      [Offset(0, size.height - arm), Offset(0, size.height), Offset(arm, size.height)], // BL
      [Offset(size.width - arm, size.height), Offset(size.width, size.height), Offset(size.width, size.height - arm)], // BR
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_QrCornersPainter old) => false;
}

// ── Crosshair painter (reused from splash) ────────────────────────────────────
class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter({required this.glowOpacity});
  final double glowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawCircle(Offset(cx, cy), cx - 1, Paint()
      ..color = _lime.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    canvas.drawCircle(Offset(cx, cy), cx - 13, Paint()
      ..color = _bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    canvas.drawCircle(Offset(cx, cy), cx - 13, Paint()
      ..color = const Color(0xFF3A3C42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    canvas.drawCircle(Offset(cx, cy), cx - 1, Paint()
      ..color = _bg.withValues(alpha: 0.9));

    canvas.drawCircle(Offset(cx, cy), 6, Paint()
      ..color = _lime
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * glowOpacity));
    canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = _lime);

    final linePaint = Paint()..color = _lime..strokeWidth = 2..strokeCap = StrokeCap.round;
    final fadePaint = Paint()..color = _lime.withValues(alpha: 0.4)..strokeWidth = 2..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx, 0), Offset(cx, 8), linePaint);
    canvas.drawLine(Offset(cx, size.height - 8), Offset(cx, size.height), fadePaint);
    canvas.drawLine(Offset(0, cy), Offset(8, cy), fadePaint);
    canvas.drawLine(Offset(size.width - 8, cy), Offset(size.width, cy), fadePaint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.glowOpacity != glowOpacity;
}
