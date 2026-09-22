import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kRed = Color(0xFFFF5C5C);

class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({super.key,
    this.className = 'CrossFit',
    this.gymName = 'Fitness Club Athens',
    this.coachName = 'Coach Maria',
    this.coachRole = 'Lead Instructor',
    this.date = 'Tue, Jun 23',
    this.time = '18:30',
    this.duration = '60 min',
  });

  final String className;
  final String gymName;
  final String coachName;
  final String coachRole;
  final String date;
  final String time;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Lime top glow
          Positioned(
            left: 0, top: 0,
            child: Container(
              width: 375, height: 256,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    kLime.withValues(alpha: 0.10),
                    kLime.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.6],
                ),
              ),
            ),
          ),
          // Cyan bottom-right glow
          Positioned(
            right: 0, top: 384,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kCyan.withValues(alpha: 0.08), Colors.transparent],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 24),
                  _buildStatusBadge(),
                  const SizedBox(height: 20),
                  _buildClassCard(),
                  const SizedBox(height: 20),
                  _buildCheckInCard(),
                  const SizedBox(height: 12),
                  _buildScanButton(),
                  const SizedBox(height: 12),
                  _buildSecondaryActions(),
                  const SizedBox(height: 12),
                  _buildTertiaryActions(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kBorder2),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        Text('Booking Details', style: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Center(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: kLime,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, color: kBg, size: 14),
            const SizedBox(width: 8),
            Text('Confirmed', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: kBg, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(className, style: GoogleFonts.spaceGrotesk(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.6)),
          const SizedBox(height: 16),
          // Gym row
          _buildDividerRow(
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2024),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(Icons.fitness_center, color: kGray, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gymName, style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('View gym profile', style: GoogleFonts.manrope(
                        fontSize: 12, color: kGray)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: kGray, size: 16),
              ],
            ),
          ),
          // Coach row
          _buildDividerRow(
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2B30), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: kGray, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coachName, style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(coachRole, style: GoogleFonts.manrope(
                        fontSize: 12, color: kGray)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Meta tiles row
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetaTile(Icons.calendar_today_outlined, 'Date', date),
              const SizedBox(width: 8),
              _buildMetaTile(Icons.access_time_outlined, 'Time', time),
              const SizedBox(width: 8),
              _buildMetaTile(Icons.timer_outlined, 'Duration', duration),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDividerRow({required Widget child}) {
    return Column(
      children: [
        const Divider(color: kBorder, thickness: 1, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: child,
        ),
      ],
    );
  }

  Widget _buildMetaTile(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2024),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kGray, size: 14),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w600, color: kGray)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2410),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder2),
            ),
            child: const Icon(Icons.qr_code_2, color: kLime, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ready for check-in', style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: kLime, letterSpacing: -0.35)),
                const SizedBox(height: 3),
                Text('Scan to enter when you arrive', style: GoogleFonts.manrope(
                  fontSize: 12, color: kGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: kLime,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.30), blurRadius: 12)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, color: kBg, size: 18),
          const SizedBox(width: 8),
          Text('Scan to Enter', style: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: kBg, letterSpacing: 0.35)),
        ],
      ),
    );
  }

  Widget _buildSecondaryActions() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text('Add to Calendar', style: GoogleFonts.spaceGrotesk(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text('View Gym', style: GoogleFonts.spaceGrotesk(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTertiaryActions(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sync, color: kGray, size: 14),
              const SizedBox(width: 8),
              Text('Reschedule', style: GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: kGray, letterSpacing: 0.3)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2A1414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kRed),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.close, color: _kRed, size: 14),
              const SizedBox(width: 8),
              Text('Cancel Booking', style: GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _kRed, letterSpacing: 0.3)),
            ],
          ),
        ),
      ],
    );
  }
}
