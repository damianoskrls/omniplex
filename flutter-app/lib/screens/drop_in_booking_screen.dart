import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class DropInBookingScreen extends StatelessWidget {
  const DropInBookingScreen({super.key,
    this.gymName = 'Fitness Club Athens',
    this.gymLocation = 'Kolonaki, Athens',
    this.className = 'CrossFit · 18:30',
    this.date = 'Tuesday, June 23',
    this.time = '18:30',
    this.price = '€15.00',
  });

  final String gymName;
  final String gymLocation;
  final String className;
  final String date;
  final String time;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGymCard(),
                      const SizedBox(height: 24),
                      _buildSectionHeader(Icons.receipt_long_outlined,
                        kCyan.withValues(alpha: 0.10), kCyan.withValues(alpha: 0.30),
                        'Booking details', 'Confirm your session'),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.fitness_center, 'CLASS', className),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.calendar_today_outlined, 'DATE', date),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.access_time_outlined, 'TIME', time),
                      const SizedBox(height: 16),
                      _buildTotalCard(),
                      const SizedBox(height: 24),
                      _buildSectionHeader(Icons.credit_card,
                        kLime.withValues(alpha: 0.10), kLime.withValues(alpha: 0.30),
                        'Payment method', 'Choose how you pay'),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.credit_card, 'CARD ON FILE', 'Visa •••• 4242'),
                      const SizedBox(height: 4),
                      _buildAddPaymentRow(),
                      const SizedBox(height: 16),
                      _buildSignInNotice(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kCard, shape: BoxShape.circle,
                border: Border.all(color: kBorder)),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(height: 24),
          Text('Book a Drop-in', style: GoogleFonts.spaceGrotesk(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.6)),
        ],
      ),
    );
  }

  Widget _buildGymCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1D22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.fitness_center, color: kGray, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gymName, style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: kGray, size: 10),
                    const SizedBox(width: 4),
                    Text(gymLocation, style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB23E).withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFB23E).withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.bolt, color: Color(0xFFFFB23E), size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, Color iconBg, Color iconBorder,
      String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: iconBorder),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.4)),
            Text(subtitle, style: GoogleFonts.manrope(
              fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1D22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Icon(icon, color: kGray, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: kGray, letterSpacing: 0.275)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.35)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kGray, size: 16),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26272C)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Drop-in fee', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
              Text(price, style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: kBorder, thickness: 1, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.35)),
              Text(price, style: GoogleFonts.spaceGrotesk(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: kLime, letterSpacing: -0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddPaymentRow() {
    return Container(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add, color: kLime, size: 14),
          const SizedBox(width: 8),
          Text('Add payment method', style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700, color: kLime)),
        ],
      ),
    );
  }

  Widget _buildSignInNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB23E).withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB23E).withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFB23E).withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFFB23E), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Sign in required to complete this booking',
              style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: kBg,
        border: const Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: kLime,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Continue to Payment', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700, color: kBg)),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward, color: kBg, size: 14),
          ],
        ),
      ),
    );
  }
}
