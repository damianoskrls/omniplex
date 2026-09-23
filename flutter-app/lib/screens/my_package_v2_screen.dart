import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class MyPackageV2Screen extends StatelessWidget {
  const MyPackageV2Screen({super.key});

  static const _kDark = Color(0xFF161616);
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  _buildHeroBanner(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSessionsCard(),
                        const SizedBox(height: 32),
                        _buildLogisticsSection(),
                        const SizedBox(height: 24),
                        _buildBenefitsCard(),
                        const SizedBox(height: 32),
                        _buildActionButtons(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.80),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleBtn(const Icon(Icons.chevron_left, color: Colors.white, size: 20)),
          Text('MY PACKAGE', style: GoogleFonts.spaceGrotesk(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 1.8)),
          _buildCircleBtn(const Icon(Icons.more_vert, color: Colors.white, size: 18)),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(Widget child) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _kBorder26.withValues(alpha: 0.50),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildHeroBanner() {
    return SizedBox(
      height: 256,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A0A), Color(0xFF0A0A05)],
              ),
            ),
            child: const Center(
              child: Icon(Icons.fitness_center, color: Color(0xFF2A2A10), size: 80),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0, height: 160,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [kBg, kBg.withValues(alpha: 0.40), Colors.transparent],
                  stops: const [0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24, bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text('PREMIUM TIER', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kBg, letterSpacing: -0.5)),
                ),
                const SizedBox(height: 8),
                Text('10 CLASS PACK', style: GoogleFonts.spaceGrotesk(
                  fontSize: 36, fontWeight: FontWeight.w800,
                  color: Colors.white, height: 1.0)),
                const SizedBox(height: 4),
                Text('Fitness Club Athens', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w500, color: kCyan)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96, height: 96,
            child: CustomPaint(
              painter: _CircleProgressPainter(progress: 0.70),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('7', style: GoogleFonts.spaceGrotesk(
                      fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('LEFT', style: GoogleFonts.manrope(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: _kGray9C, letterSpacing: 0.18)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('7 Sessions\nremaining', style: GoogleFonts.manrope(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: Colors.white, height: 1.2)),
                const SizedBox(height: 4),
                Text("You've used 3 out of 10 sessions from your current pack.",
                  style: GoogleFonts.manrope(fontSize: 12, color: _kGray9C)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: kLime, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('READY TO BOOK', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: kLime, letterSpacing: 1.0)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('PACKAGE LOGISTICS', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 2.4)),
            const SizedBox(width: 16),
            Expanded(child: Container(height: 1, color: _kBorder26.withValues(alpha: 0.30))),
          ],
        ),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.0,
          children: [
            _buildInfoTile('Status', 'Active', highlight: true),
            _buildInfoTile('Valid Until', '28 Oct 2026'),
            _buildInfoTile('Start Date', '28 Oct 2025'),
            _buildInfoTile('Purchase Date', '25 Oct 2025'),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDark.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700, color: _kGray6B)),
          const SizedBox(height: 4),
          if (highlight)
            Row(
              children: [
                const Icon(Icons.check_circle, color: kLime, size: 12),
                const SizedBox(width: 8),
                Text(value, style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white)),
              ],
            )
          else
            Text(value, style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    final benefits = [
      'Access to all CrossFit & HIIT sessions',
      'Complimentary towel & sauna service',
      '20% discount on supplements in-store',
      'One-time guest pass per month',
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INCLUDED BENEFITS', style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: kCyan, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: kCyan.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: kCyan, size: 10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(b, style: GoogleFonts.manrope(
                    fontSize: 14, color: const Color(0xFFD1D5DB))),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            color: kLime,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: kLime.withValues(alpha: 0.20), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month_outlined, color: kBg, size: 18),
              const SizedBox(width: 8),
              Text('BOOK A SESSION', style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: kBg, letterSpacing: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Center(
            child: Text('VIEW PACKAGE DETAILS', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 1.4)),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_rounded, 'HOME', false),
          _buildNavItem(Icons.search, 'SEARCH', false),
          _buildNavItem(Icons.calendar_today_outlined, 'SCHEDULE', false),
          _buildNavItem(Icons.fitness_center_outlined, 'MY GYMS', true),
          SizedBox(
            width: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGray6B),
                    color: const Color(0xFF3A3C42),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 14),
                ),
                const SizedBox(height: 4),
                Text('PROFILE', style: GoogleFonts.manrope(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _kGray6B, letterSpacing: 0.9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? kLime : _kGray6B, size: 22),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: active ? kLime : _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  const _CircleProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Background track
    paint.color = const Color(0xFF262626);
    canvas.drawCircle(center, radius, paint);

    // Progress arc (lime)
    paint.color = const Color(0xFFC6FF3D);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
