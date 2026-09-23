import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class QrSuccessScreen extends StatelessWidget {
  const QrSuccessScreen({super.key});

  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kDark = Color(0xFF161616);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Glow background
          Center(
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kLime.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  _buildCheckIcon(),
                  const SizedBox(height: 32),
                  _buildTitle(),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: _buildInfoCard(),
                  ),
                  const SizedBox(height: 32),
                  _buildSubtitle(),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        _buildDoneButton(),
                        const SizedBox(height: 24),
                        _buildViewSummary(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Row(
              children: [
                Expanded(child: Container(height: 4, color: kLime)),
                Expanded(child: Container(height: 4, color: kCyan)),
                Expanded(child: Container(height: 4, color: kLime)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckIcon() {
    return Container(
      width: 160, height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kBg.withValues(alpha: 0.80),
        border: Border.all(color: kLime.withValues(alpha: 0.20), width: 4),
        boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.10), blurRadius: 30, spreadRadius: 10)],
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kLime, width: 1),
          boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.40), blurRadius: 20)],
        ),
        child: const Center(
          child: Icon(Icons.check, color: kLime, size: 52),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text("YOU'RE CHECKED IN", style: GoogleFonts.spaceGrotesk(
          fontSize: 36, fontWeight: FontWeight.w800,
          color: Colors.white, letterSpacing: -0.9,
          height: 1.1),
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('ENTRY AUTHORIZED', style: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: kLime, letterSpacing: 1.4)),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LOCATION', style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _kGray6B, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('Fitness Club Athens', style: GoogleFonts.manrope(
                        fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                  const Icon(Icons.location_on_outlined, color: Color(0xFF9CA3AF), size: 16),
                ],
              ),
              Divider(color: Colors.white.withValues(alpha: 0.05), height: 32),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TIME', style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _kGray6B, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('18:25', style: GoogleFonts.manrope(
                        fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(width: 40),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DATE', style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _kGray6B, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('Monday, 28 Oct', style: GoogleFonts.manrope(
                        fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Lime corner accent
          Positioned(
            top: -32, right: -32,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: kLime.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.manrope(fontSize: 18, color: _kGray9C),
        children: [
          const TextSpan(text: 'Turnstile is unlocked.\n'),
          TextSpan(text: 'Have a great workout!', style: GoogleFonts.manrope(
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildDoneButton() {
    return Container(
      width: double.infinity, height: 64,
      decoration: BoxDecoration(
        color: kLime,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('DONE', style: GoogleFonts.spaceGrotesk(
            fontSize: 18, fontWeight: FontWeight.w900,
            color: kBg, letterSpacing: 0.9)),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: kBg, size: 18),
        ],
      ),
    );
  }

  Widget _buildViewSummary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.receipt_outlined, color: Color(0xFF6B7280), size: 14),
        const SizedBox(width: 8),
        Text('VIEW SUMMARY', style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _kGray6B, letterSpacing: 1.2)),
      ],
    );
  }
}
