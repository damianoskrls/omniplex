import 'dart:math' as math;
import 'package:flutter/material.dart';
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

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;

  late final AnimationController _bgAnim;
  late final AnimationController _entryAnim;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  static const _slides = [
    _Slide(
      icon: Icons.fitness_center_rounded,
      accentStart: Color(0xFF7C5CFC),
      accentEnd: Color(0xFFB8F55E),
      title: 'Κρατήσεις\nμε ένα tap',
      body: 'Κλείσε θέση σε κάθε ομαδικό μάθημα,\nδες το πρόγραμμα και διαχειρίσου\nτις συνεδρίες σου εύκολα.',
    ),
    _Slide(
      icon: Icons.show_chart_rounded,
      accentStart: Color(0xFFB8F55E),
      accentEnd: Color(0xFF4FD1C5),
      title: 'Παρακολούθησε\nτην πρόοδό σου',
      body: 'Δες αναλυτικά stats προπόνησης,\nπαρακολούθησε το σώμα σου\nκαι μείνε στον στόχο σου.',
    ),
    _Slide(
      icon: Icons.shopping_bag_rounded,
      accentStart: Color(0xFFFF8A4C),
      accentEnd: Color(0xFFFF6B9D),
      title: 'Marketplace\n& Παραγγελίες',
      body: 'Αγόρασε supplements και προϊόντα\nάμεσα από το app και παρακολούθησε\nτην πορεία της παραγγελίας σου.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _fadeIn = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    _bgAnim.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
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
    _entryAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  slide.accentStart.withValues(alpha: 0.12),
                  const Color(0xFF09090E),
                  slide.accentEnd.withValues(alpha: 0.08),
                ],
              ),
            ),
          ),

          // Decorative orb
          Positioned(
            top: -80,
            right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    slide.accentStart.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Page content
          PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemCount: _slides.length,
            itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: active ? slide.accentStart : Colors.white24,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Next / Start button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: slide.accentStart,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          _page == _slides.length - 1 ? 'Ξεκινάμε!' : 'Επόμενο',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (_page < _slides.length - 1) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Παράλειψη', style: TextStyle(color: Colors.white38, fontSize: 14)),
                      ),
                    ] else
                      const SizedBox(height: 44),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.icon, required this.accentStart, required this.accentEnd, required this.title, required this.body});
  final IconData icon;
  final Color accentStart;
  final Color accentEnd;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 200),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [slide.accentStart, slide.accentEnd],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: slide.accentStart.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(slide.icon, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            slide.body,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
