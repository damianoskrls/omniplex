import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class PackageDetailsScreen extends StatelessWidget {
  const PackageDetailsScreen({super.key});

  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kD1 = Color(0xFFD1D5DB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHero()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 128),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildUsageCard(),
                    const SizedBox(height: 24),
                    _buildDatesRow(),
                    const SizedBox(height: 24),
                    _buildBenefitsCard(),
                    const SizedBox(height: 24),
                    _buildPaymentCard(),
                    const SizedBox(height: 24),
                    _buildFooterLinks(),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
          // Top header overlay
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: kBg.withValues(alpha: 0.80),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCircleBtn(const Icon(Icons.chevron_left, color: Colors.white, size: 20)),
                    Text('PACKAGE DETAILS', style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 1.8)),
                    _buildCircleBtn(const Icon(Icons.share_outlined, color: Colors.white, size: 18)),
                  ],
                ),
              ),
            ),
          ),
          // Bottom CTA
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [kBg, kBg.withValues(alpha: 0.95), kBg.withValues(alpha: 0.0)],
                  stops: const [0, 0.6, 1.0],
                ),
              ),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: kLime.withValues(alpha: 0.25), blurRadius: 14)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: kBg, size: 20),
                    const SizedBox(width: 12),
                    Text('BOOK A SESSION', style: GoogleFonts.spaceGrotesk(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: kBg, letterSpacing: 3.2)),
                  ],
                ),
              ),
            ),
          ),
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

  Widget _buildHero() {
    return SizedBox(
      height: 340,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A0A0A), Color(0xFF0A1A0A)],
              ),
            ),
            child: const Center(
              child: Icon(Icons.fitness_center, color: Color(0xFF2A2A10), size: 100),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0, height: 200,
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
            left: 24, right: 24, bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FITNESS CLUB ATHENS', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: kCyan, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text('10 CLASS PACK', style: GoogleFonts.spaceGrotesk(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kLime.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: kLime.withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('✓ ACTIVE', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: kLime)),
                  ],
                ),
              ),
              Text('USAGE DETAILS', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _kGray9C, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: '7', style: GoogleFonts.spaceGrotesk(
                      fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                    TextSpan(text: ' / 10', style: GoogleFonts.spaceGrotesk(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _kGray6B)),
                  ],
                ),
              ),
              Text('SESSIONS REMAINING', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700, color: kCyan)),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar — 70% filled
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: _kBorder26,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.70,
              child: Container(
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDatesRow() {
    return Row(
      children: [
        Expanded(child: _buildDateCard('START DATE', '28 Oct 2025')),
        const SizedBox(width: 16),
        Expanded(child: _buildDateCard('EXPIRY DATE', '28 Oct 2026')),
      ],
    );
  }

  Widget _buildDateCard(String label, String date) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _kGray6B, letterSpacing: 0.9)),
          const SizedBox(height: 4),
          Text(date, style: GoogleFonts.manrope(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
        ],
      ),
      radius: 16,
    );
  }

  Widget _buildBenefitsCard() {
    final benefits = [
      'All classes included (CrossFit, Yoga, HIIT)',
      'Premium Towel service',
      'Daily Sauna & Spa access',
    ];
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: kLime, width: 2)),
            ),
            child: Text('PACKAGE BENEFITS', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 1.4)),
          ),
          const SizedBox(height: 16),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: kCyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check, color: kCyan, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(b, style: GoogleFonts.manrope(
                    fontSize: 14, color: _kD1)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: kCyan, width: 2)),
            ),
            child: Text('PAYMENT INFO', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 1.4)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STATUS', style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: _kGray9C, letterSpacing: 0.12)),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: kLime, size: 14),
                  const SizedBox(width: 8),
                  Text('PAID', style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w900,
                    color: Colors.white, fontStyle: FontStyle.italic, letterSpacing: 0.16)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          const SizedBox(height: 16),
          Text('PURCHASE HISTORY', style: GoogleFonts.manrope(
            fontSize: 11, fontWeight: FontWeight.w700, color: _kGray9C)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('25 Oct 2025', style: GoogleFonts.manrope(
                fontSize: 14, color: Colors.white)),
              Text('€120', style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            const Icon(Icons.download_outlined, color: _kGray6B, size: 14),
            const SizedBox(width: 8),
            Text('DOWNLOAD INVOICE', style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(width: 16),
        Container(width: 4, height: 4, decoration: const BoxDecoration(
          color: _kBorder26, shape: BoxShape.circle)),
        const SizedBox(width: 16),
        Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xCCEF4444), size: 14),
            const SizedBox(width: 8),
            Text('CANCEL PACKAGE', style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: const Color(0xCCEF4444), letterSpacing: 1.0)),
          ],
        ),
      ],
    );
  }

  Widget _glassCard({required Widget child, double radius = 24}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}
