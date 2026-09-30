import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/brand.dart';

const _kOnboardingKey = 'bookup_onboarding_v3_done';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

const _bg = Color(0xFF0A0A0A);
const _gray = Color(0xFF9A9CA3);

class _Slide {
  const _Slide({required this.image, required this.title, required this.body});
  final String image;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    image: 'assets/onboarding/onboarding_gyms.jpg',
    title: 'Όλα τα γυμναστήρια.\nΣε ένα μέρος.',
    body: 'Πακέτα, κρατήσεις και πρόσβαση, χωρίς να αλλάζεις εφαρμογή.',
  ),
  _Slide(
    image: 'assets/onboarding/onboarding_book.jpg',
    title: 'Βρες μάθημα.\nΚλείσε θέση.',
    body: 'Δες το πρόγραμμα και κλείσε σε δευτερόλεπτα, μόνο τις μέρες που τρέχει.',
  ),
  _Slide(
    image: 'assets/onboarding/onboarding_enter.jpg',
    title: 'Μπες.\nΣκάναρε. Ξεκίνα.',
    body: 'Το QR σου ανοίγει την πόρτα στα γυμναστήρια που είσαι μέλος.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _slides.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (_, i) => Image.asset(
              _slides[i].image,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0xCC000000),
                  Color(0xFF000000),
                ],
                stops: [0, 0.28, 0.62, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      SvgPicture.asset('assets/omniplex_logo.svg', height: 22),
                      const Spacer(),
                      if (_page < _slides.length - 1)
                        TextButton(
                          onPressed: _finish,
                          child: Text('Παράλειψη', style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13)),
                        ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Column(
                      key: ValueKey(slide.title),
                      children: [
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.05,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(fontSize: 15, color: _gray, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: active ? Colors.white : Colors.white24,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: kBrandGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: kBrandShadow.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Text(
                        _page == _slides.length - 1 ? 'Ξεκίνα' : 'Επόμενο',
                        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
