import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_auth_service.dart';
import 'phone_otp_login_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

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
                      _kLime.withValues(alpha: 0.08),
                      _kLime.withValues(alpha: 0.0),
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
                  Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: _kLime,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/discovery_logo_bolt.svg',
                        width: 14, height: 14,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text('OmniPlex',
                      style: GoogleFonts.manrope(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.4)),
                  ]),

                  const Spacer(flex: 3),

                  // Main headline
                  Text('Το fitness\nστο χέρι σου.',
                    style: GoogleFonts.manrope(
                      fontSize: 40, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -1.2, height: 1.1)),
                  const SizedBox(height: 16),
                  Text(
                    'Βρες γυμναστήριο, δες πακέτα και κάνε\nκρατήσεις — όλα σε ένα μέρος.',
                    style: GoogleFonts.manrope(
                      fontSize: 15, color: _kGray, height: 1.6)),

                  const Spacer(flex: 2),

                  // ── Primary CTA ──────────────────────────────────────
                  _PrimaryButton(
                    label: 'Σύνδεση',
                    subtitle: 'Έχω ήδη λογαριασμό',
                    icon: Icons.phone_android_rounded,
                    onTap: () => _goLogin(context),
                  ),

                  const SizedBox(height: 12),

                  // ── Secondary CTA ────────────────────────────────────
                  _SecondaryButton(
                    label: 'Συνέχεια ως επισκέπτης',
                    subtitle: 'Εξερεύνηση χωρίς σύνδεση',
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
          color: _kLime,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _kLime.withValues(alpha: 0.25),
              blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: _kBg, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _kBg, letterSpacing: 0.1)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: _kBg.withValues(alpha: 0.55))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: _kBg.withValues(alpha: 0.4), size: 14),
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
                  Text(label,
                    style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 0.1)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                    style: GoogleFonts.manrope(
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
