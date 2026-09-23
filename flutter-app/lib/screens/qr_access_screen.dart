import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class QrAccessScreen extends StatelessWidget {
  const QrAccessScreen({super.key});

  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Background camera placeholder
          Positioned.fill(
            top: 7,
            child: Container(
              color: const Color(0xFF0A1A0A),
              child: const Center(
                child: Icon(Icons.qr_code_scanner, color: Color(0xFF1A2A1A), size: 120),
              ),
            ),
          ),
          // Overlay gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kBg.withValues(alpha: 0.40),
                    Colors.transparent,
                    Colors.transparent,
                    kBg.withValues(alpha: 0.90),
                  ],
                  stops: const [0, 0.15, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildInstructions(),
                const Spacer(),
                _buildQrFrame(),
                const Spacer(),
                _buildFooter(),
              ],
            ),
          ),
          // Bottom gradient bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kLime, kCyan, kLime],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlassCircle(const Icon(Icons.close, color: Colors.white, size: 20)),
          Column(
            children: [
              Text('SCAN TO ENTER', style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 1.8)),
              Text('OMNIPLEX ATHENS • FLOOR 1', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: kLime, letterSpacing: -0.5)),
            ],
          ),
          _buildGlassCircle(const Icon(Icons.help_outline, color: Colors.white, size: 18)),
        ],
      ),
    );
  }

  Widget _buildGlassCircle(Widget child) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.60),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildInstructions() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFFD1D5DB)),
        children: [
          const TextSpan(text: "Position the gym's "),
          TextSpan(text: 'Entry QR Code', style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700, color: kCyan)),
          const TextSpan(text: ' inside the frame to unlock the turnstile.'),
        ],
      ),
    );
  }

  Widget _buildQrFrame() {
    return SizedBox(
      width: 280, height: 280,
      child: Stack(
        children: [
          // Scanning line
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, kLime, Colors.transparent],
                ),
                boxShadow: [BoxShadow(color: kLime, blurRadius: 8)],
              ),
            ),
          ),
          // Corner decorations
          ..._buildCorners(),
          // Inner border
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 40.0;
    const border = 4.0;
    const radius = 16.0;

    return [
      Positioned(top: 0, left: 0, child: _corner(size, border, radius, top: true, left: true)),
      Positioned(top: 0, right: 0, child: _corner(size, border, radius, top: true, left: false)),
      Positioned(bottom: 0, left: 0, child: _corner(size, border, radius, top: false, left: true)),
      Positioned(bottom: 0, right: 0, child: _corner(size, border, radius, top: false, left: false)),
    ];
  }

  Widget _corner(double size, double border, double radius, {required bool top, required bool left}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: kLime, width: border) : BorderSide.none,
          bottom: !top ? BorderSide(color: kLime, width: border) : BorderSide.none,
          left: left ? BorderSide(color: kLime, width: border) : BorderSide.none,
          right: !left ? BorderSide(color: kLime, width: border) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? Radius.circular(radius) : Radius.zero,
          topRight: top && !left ? Radius.circular(radius) : Radius.zero,
          bottomLeft: !top && left ? Radius.circular(radius) : Radius.zero,
          bottomRight: !top && !left ? Radius.circular(radius) : Radius.zero,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
      child: Column(
        children: [
          // Flash/Gallery buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlassBtn(const Icon(Icons.flash_on, color: Colors.white, size: 20)),
              const SizedBox(width: 24),
              _buildGlassBtn(const Icon(Icons.image_outlined, color: Colors.white, size: 20)),
            ],
          ),
          const SizedBox(height: 24),
          // Manual code link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("CAN'T SCAN? USE MANUAL CODE", style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _kGray9C, letterSpacing: 1.2)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 14),
            ],
          ),
          const SizedBox(height: 24),
          // Access card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161616).withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: kLime.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kLime.withValues(alpha: 0.30)),
                  ),
                  child: const Icon(Icons.credit_card_outlined, color: kLime, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACCESS LEVEL', style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _kGray6B, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text('Premium All-Access Pass', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle),
                    ),
                    const SizedBox(height: 4),
                    Text('READY', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700, color: kLime)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBtn(Widget child) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF161616).withValues(alpha: 0.80),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Center(child: child),
    );
  }
}
