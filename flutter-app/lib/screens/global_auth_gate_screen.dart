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
  /// Called after successful login/OTP verify
  final VoidCallback onLogin;
  /// Called when user picks "Εξερεύνηση" (skip auth)
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
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle lime glow top-left
          Positioned(
            top: -60, left: -60,
            child: SizedBox(
              width: 320, height: 320,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kLime.withValues(alpha: 0.10),
                      _kLime.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // Logo
                  Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _kLime,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/discovery_logo_bolt.svg',
                        width: 16, height: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('OmniPlex',
                      style: GoogleFonts.manrope(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.5)),
                  ]),

                  const Spacer(),

                  // Heading
                  Text('Καλώς ήρθες!',
                    style: GoogleFonts.manrope(
                      fontSize: 36, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.9, height: 1.1)),
                  const SizedBox(height: 14),
                  Text(
                    'Είσαι ήδη πελάτης γυμναστηρίου ή έχεις\nλογαριασμό OmniPlex; Σύνδεσε το κινητό σου\nγια να δεις τα πακέτα και τις κρατήσεις σου.',
                    style: GoogleFonts.manrope(
                      fontSize: 15, color: _kGray, height: 1.6)),

                  const SizedBox(height: 52),

                  // ── Button 1: Primary (Σύνδεση) ──────────────────────
                  GestureDetector(
                    onTap: () => _goLogin(context),
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: _kLime,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _kLime.withValues(alpha: 0.30),
                            blurRadius: 18, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone_android_rounded,
                            color: _kBg, size: 18),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Σύνδεση με κινητό',
                                style: GoogleFonts.manrope(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: _kBg, letterSpacing: 0.1)),
                              Text('Έχω ήδη λογαριασμό / με κατέγραψε γυμναστήριο',
                                style: GoogleFonts.manrope(
                                  fontSize: 10.5, fontWeight: FontWeight.w500,
                                  color: _kBg.withValues(alpha: 0.55))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Button 2: Secondary (Εξερεύνηση) ─────────────────
                  GestureDetector(
                    onTap: onExplore,
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kBorder, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.explore_outlined,
                            color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Εξερεύνηση',
                                style: GoogleFonts.manrope(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Colors.white, letterSpacing: 0.1)),
                              Text('Νέος χρήστης · Ψάχνω γυμναστήριο',
                                style: GoogleFonts.manrope(
                                  fontSize: 10.5, fontWeight: FontWeight.w500,
                                  color: _kGray)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Fine print
                  Center(
                    child: Text(
                      'Μπορείς να συνδεθείς ανά πάσα στιγμή μέσα από\nτην εφαρμογή.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5, color: _kGray.withValues(alpha: 0.6), height: 1.5),
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
