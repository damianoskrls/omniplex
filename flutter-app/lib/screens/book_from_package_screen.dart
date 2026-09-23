import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class BookFromPackageScreen extends StatelessWidget {
  const BookFromPackageScreen({super.key});

  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kD1 = Color(0xFFD1D5DB);
  static const _kRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 160),
            child: Column(
              children: [
                // Header space
                const SizedBox(height: 88),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildClassCard(),
                      const SizedBox(height: 24),
                      _buildTransactionCard(),
                      const SizedBox(height: 24),
                      _buildWarningBox(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Header
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
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _kBorder26.withValues(alpha: 0.50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: const Center(
                        child: Icon(Icons.chevron_left, color: Colors.white, size: 22)),
                    ),
                    const SizedBox(width: 16),
                    Text('CONFIRM BOOKING', style: GoogleFonts.spaceGrotesk(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 2.8)),
                  ],
                ),
              ),
            ),
          ),
          // Bottom CTA
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [kBg, kBg.withValues(alpha: 0.95), Colors.transparent],
                  stops: const [0, 0.6, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DOUBLE CHECK DETAILS BEFORE CONFIRMING',
                    style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _kGray6B, letterSpacing: 1.0),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity, height: 64,
                    decoration: BoxDecoration(
                      color: kLime,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: kLime.withValues(alpha: 0.35), blurRadius: 16)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('CONFIRM BOOKING', style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: kBg, letterSpacing: 4.0)),
                        Text('SECURE CHECKOUT', style: GoogleFonts.manrope(
                          fontSize: 9, fontWeight: FontWeight.w900,
                          color: kBg.withValues(alpha: 0.70), letterSpacing: 0.9)),
                      ],
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

  Widget _buildClassCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          // Image area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            child: SizedBox(
              height: 192,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF101010), Color(0xFF0A1A0A)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.fitness_center, color: Color(0xFF2A2A10), size: 70),
                    ),
                  ),
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [kBg.withValues(alpha: 0.80), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24, right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: kCyan.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: kCyan.withValues(alpha: 0.40)),
                      ),
                      child: Text('INTERMEDIATE', style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w900,
                        color: kCyan, letterSpacing: 1.0)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Class info
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FITNESS CLUB ATHENS', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: kLime, letterSpacing: 3.0)),
                const SizedBox(height: 8),
                Text('CROSSFIT', style: GoogleFonts.spaceGrotesk(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -1.8)),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 32),
                Row(
                  children: [
                    Expanded(child: _buildDetailItem(Icons.calendar_today_outlined, 'DATE', 'Mon, 28\nOct')),
                    Expanded(child: _buildDetailItem(Icons.access_time_outlined, 'TIME', '18:30 -\n19:30')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.manrope(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 0.9)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Text('TRANSACTION DETAILS', style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: _kGray9C, letterSpacing: 1.1)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PAYMENT METHOD', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kGray6B, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text('10 Class Pack', style: GoogleFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('DEDUCTION', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kGray6B, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text('-1 Session', style: GoogleFonts.spaceGrotesk(
                    fontSize: 20, fontWeight: FontWeight.w900, color: kLime)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kBg.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _buildBalanceRow('Current Balance', '7 Sessions', Colors.white),
                const SizedBox(height: 16),
                _buildBalanceRow('Deduction', '-1 Session', _kRed),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('NEW BALANCE', style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: kCyan, letterSpacing: 1.1)),
                    Text('6', style: GoogleFonts.spaceGrotesk(
                      fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 14, color: _kGray9C)),
        Text(value, style: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCyan.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCyan.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: kCyan, size: 16),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.manrope(fontSize: 11, color: _kD1),
                children: [
                  const TextSpan(text: 'Cancellations made less than '),
                  TextSpan(text: '12 hours', style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w700, color: kCyan)),
                  const TextSpan(
                    text: ' before the class starts will not be refunded to your package balance.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
