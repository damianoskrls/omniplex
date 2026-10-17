import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/tr.dart';

const _kOnboardingKey = 'bookup_onboarding_v4_done';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

const _kBg      = Color(0xFF090A0F);
const _kText    = Color(0xFFF5F5FA);
const _kGray    = Color(0xFFA7ABBE);
const _kBorder  = Color(0xFF2B2E3D);
const _kAccent  = Color(0xFF9A9DFF);
const _kPrimary = Color(0xFF565CE4);
const _kCard    = Color(0xFF242642);
const _kCardBorder = Color(0xFF3B3F72);
const _kCardDark   = Color(0xFF14161F);
const _kPink    = Color(0xFFC52473);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  static const _totalPages = 2;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
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
    return Scaffold(
      backgroundColor: _kBg,
      body: PageView(
        controller: _pageCtrl,
        onPageChanged: (p) => setState(() => _page = p),
        children: [
          _SlideDiscover(onNext: _next, onSkip: _finish),
          _SlideSchedule(onNext: _next, onSkip: _finish),
        ],
      ),
    );
  }
}

// ── Slide 02: Discover your next gym ────────────────────────────────────────

class _SlideDiscover extends StatelessWidget {
  const _SlideDiscover({required this.onNext, required this.onSkip});
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final photoH = MediaQuery.of(context).size.height * 0.49;
    return Column(
      children: [
        // Photo section with gradient overlay
        SizedBox(
          height: photoH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/onboarding/discovery_editorial.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00090A0F), Color(0xF0090A0F)],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SvgPicture.asset('assets/omniplex_symbol.svg', height: 28),
                          const Spacer(),
                          GestureDetector(
                            onTap: onSkip,
                            child: Text(tr('Παράλειψη'),
                              style: GoogleFonts.inter(color: _kText, fontSize: 13)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _kCard, borderRadius: BorderRadius.circular(6)),
                        child: Text('Η ΑΘΗΝΑ ΕΙΝΑΙ Ο ΧΩΡΟΣ ΠΡΟΠΟΝΗΣΗΣ ΣΟΥ',
                          style: GoogleFonts.inter(color: _kAccent, fontSize: 10)),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content section
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Βρες τον χώρο σου.\nΒρες τον ρυθμό σου.'),
                  style: GoogleFonts.inter(
                    color: _kText, fontSize: 36, fontWeight: FontWeight.w800,
                    height: 1.03, letterSpacing: -0.5),
                ),
                const SizedBox(height: 14),
                Text(
                  tr('Ανακάλυψε το επόμενο γυμναστήριό σου, από αίθουσες δύναμης έως στούντιο reformer. Η καλή προπόνηση είναι πιο κοντά από ό,τι νομίζεις.'),
                  style: GoogleFonts.inter(color: _kGray, fontSize: 14, height: 1.45),
                ),
                const Spacer(),
                Row(children: [_Dot(active: true), const SizedBox(width: 6), _Dot(active: false)]),
                const SizedBox(height: 16),
                _PrimaryButton(label: tr('Επόμενο'), onTap: onNext),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Slide 03: One schedule ───────────────────────────────────────────────────

class _SlideSchedule extends StatelessWidget {
  const _SlideSchedule({required this.onNext, required this.onSkip});
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Text(tr('Ροή για όλους'),
                    style: GoogleFonts.inter(
                      color: _kText, fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onSkip,
                    child: Text(tr('Παράλειψη'),
                      style: GoogleFonts.inter(color: _kAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),

          // Schedule illustration
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    SvgPicture.asset('assets/omniplex_symbol.svg', height: 34),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('ΠΕΜΠΤΗ, 15 ΟΚΤΩΒΡΙΟΥ',
                          style: GoogleFonts.inter(color: _kGray, fontSize: 12)),
                        const Spacer(),
                        const Icon(Icons.calendar_month_outlined, color: _kAccent, size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Highlighted schedule card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kCardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Badge(label: '18:00', dark: false),
                              const Spacer(),
                              Text('50 MIN',
                                style: GoogleFonts.inter(color: _kGray, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Βάσεις Δύναμης',
                            style: GoogleFonts.inter(
                              color: _kText, fontSize: 20, height: 1.45)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _Badge(label: 'FORMA Athletics', dark: true),
                              const SizedBox(width: 6),
                              _Badge(label: 'Αθλητής', dark: false),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Timeline + second card
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 2, height: 18, color: _kPink),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _kCardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('ΠΑΡ 16 · 17:00',
                                      style: GoogleFonts.inter(color: _kAccent, fontSize: 12)),
                                    const Spacer(),
                                    _Badge(label: 'Προπονητής', dark: false),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text('Coaching Κινητικότητας',
                                  style: GoogleFonts.inter(
                                    color: _kText, fontSize: 17, fontWeight: FontWeight.w600, height: 1.45)),
                                const SizedBox(height: 6),
                                Text('FORMA Athletics · Η ορισμένη σου συνεδρία',
                                  style: GoogleFonts.inter(color: _kGray, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Text content + progress + CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Πολλά γυμναστήρια.\nΈνας ρυθμός.'),
                  style: GoogleFonts.inter(
                    color: _kText, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('Η προπόνηση, το coaching και τα ραντεβού σου, μαζί. Ένα πρόγραμμα σε κάθε γυμναστήριο και κάθε ρόλο.'),
                  style: GoogleFonts.inter(color: _kGray, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 16),
                Row(children: [_Dot(active: false), const SizedBox(width: 6), _Dot(active: true)]),
                const SizedBox(height: 16),
                _PrimaryButton(label: tr('Ας ξεκινήσουμε'), onTap: onNext),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 30 : 8,
      height: 4,
      decoration: BoxDecoration(
        color: active ? _kAccent : _kBorder,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.dark});
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1F2B) : _kCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
        style: GoogleFonts.inter(
          color: dark ? _kGray : _kAccent, fontSize: 10)),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: _kPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: GoogleFonts.inter(color: _kText, fontSize: 14)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: _kText, size: 16),
          ],
        ),
      ),
    );
  }
}
