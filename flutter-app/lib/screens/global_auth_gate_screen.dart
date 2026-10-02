import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_auth_service.dart';
import '../theme/brand.dart';
import 'phone_otp_login_screen.dart';
import '../l10n/tr.dart';


const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);

class GlobalAuthGateScreen extends StatelessWidget {
  const GlobalAuthGateScreen({
    super.key,
    required this.globalAuth,
    required this.onLogin,
    required this.onExplore,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onLogin;
  final VoidCallback onExplore;

  void _goLogin(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PhoneOtpLoginScreen(
        globalAuth: globalAuth,
        onLoggedIn: () {
          Navigator.pop(context);
          onLogin();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background glow — bottom center lime
          Positioned(
            bottom: -100,
            left: size.width / 2 - 180,
            child: SizedBox(
              width: 360, height: 360,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7B3EAD).withValues(alpha: 0.22),
                      const Color(0xFF7B3EAD).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.75],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),

                  // Logo row
                  SvgPicture.asset('assets/omniplex_logo.svg', height: 40),

                  const Spacer(flex: 3),

                  // Main headline
                  Text(tr('Το fitness\nστο χέρι σου.'),
                    style: GoogleFonts.inter(
                      fontSize: 40, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -1.2, height: 1.1)),
                  const SizedBox(height: 16),
                  Text(
                    tr('Βρες γυμναστήριο, δες πακέτα και κάνε\nκρατήσεις — όλα σε ένα μέρος.'),
                    style: GoogleFonts.inter(
                      fontSize: 15, color: _kGray, height: 1.6)),

                  const Spacer(flex: 2),

                  // ── Primary CTA ──────────────────────────────────────
                  _PrimaryButton(
                    label: tr('Είσοδος / Εγγραφή'),
                    subtitle: tr('Με τον αριθμό του κινητού σου'),
                    icon: Icons.phone_android_rounded,
                    onTap: () => _goLogin(context),
                  ),

                  const SizedBox(height: 12),

                  // ── Secondary CTA ────────────────────────────────────
                  _SecondaryButton(
                    label: tr('Συνέχεια ως επισκέπτης'),
                    subtitle: tr('Εξερεύνηση χωρίς σύνδεση'),
                    onTap: onExplore,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: kBrandGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: kBrandShadow.withValues(alpha: 0.4),
              blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(label),
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 0.1)),
                  const SizedBox(height: 1),
                  Text(tr(subtitle),
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: Colors.white70)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(Icons.explore_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(label),
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 0.1)),
                  const SizedBox(height: 1),
                  Text(tr(subtitle),
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: _kGray)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: _kGray.withValues(alpha: 0.5), size: 14),
          ],
        ),
      ),
    );
  }
}
