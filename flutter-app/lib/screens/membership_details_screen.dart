import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class MembershipDetailsScreen extends StatelessWidget {
  const MembershipDetailsScreen({super.key,
    this.gymName = 'Fitness Club Athens',
    this.planName = '10 Class Pack',
    this.startDate = 'Sep 28',
    this.expiryDate = 'Oct 28',
    this.classesRemaining = 8,
    this.totalClasses = 10,
    this.amountPaid = '€90.00',
    this.purchaseDate = 'Sep 28',
  });

  final String gymName;
  final String planName;
  final String startDate;
  final String expiryDate;
  final int classesRemaining;
  final int totalClasses;
  final String amountPaid;
  final String purchaseDate;

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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(context),
                        const SizedBox(height: 24),
                        _buildMembershipCard(),
                        const SizedBox(height: 24),
                        _buildSectionLabel('BENEFITS'),
                        const SizedBox(height: 16),
                        _buildBenefitsCard(),
                        const SizedBox(height: 24),
                        _buildSectionLabel('PAYMENT INFORMATION'),
                        const SizedBox(height: 16),
                        _buildPaymentCard(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        Text('Membership Details', style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.45)),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kBorder2),
          ),
          child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  Widget _buildMembershipCard() {
    final progress = classesRemaining / totalClasses;
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
          // Gym + plan name header
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2024),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(Icons.fitness_center, color: kGray, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gymName, style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                    Text(planName, style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.45)),
                  ],
                ),
              ),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 7),
                  ],
                ),
                child: Center(
                  child: Text('Active', style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kBg, letterSpacing: 0.25)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Start / Expiry date tiles
          Row(
            children: [
              Expanded(child: _buildDateTile(Icons.calendar_today_outlined, 'Start Date', startDate)),
              const SizedBox(width: 12),
              Expanded(child: _buildDateTile(Icons.event_outlined, 'Expiry Date', expiryDate)),
            ],
          ),
          const SizedBox(height: 12),
          // Progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2024),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Classes Remaining', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                    Text('$classesRemaining / $totalClasses', style: GoogleFonts.spaceGrotesk(
                      fontSize: 14, fontWeight: FontWeight.w700, color: kLime)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    height: 8, color: kBorder2,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: [
                            BoxShadow(color: kLime.withValues(alpha: 0.5), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2024),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kGray, size: 12),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: GoogleFonts.manrope(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: kGray, letterSpacing: 0.3));
  }

  Widget _buildBenefitsCard() {
    const benefits = [
      'Access to all group classes',
      'Free equipment locker',
      'Guest pass once a month',
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: benefits.map((b) => Padding(
          padding: EdgeInsets.only(bottom: b == benefits.last ? 0 : 16),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2410),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: kLime, size: 14),
              ),
              const SizedBox(width: 12),
              Text(b, style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          _buildPaymentRow(Icons.credit_card, 'Payment Method', 'Visa •••• 4242', divider: true),
          _buildPaymentRow(Icons.euro, 'Amount Paid', amountPaid, divider: true),
          _buildPaymentRow(Icons.calendar_today_outlined, 'Purchase Date', purchaseDate, divider: false),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(IconData icon, String label, String value, {required bool divider}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2024),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder),
                ),
                child: Icon(icon, color: kGray, size: 14),
              ),
              const SizedBox(width: 12),
              Text(label, style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
              const Spacer(),
              Text(value, style: GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
        if (divider) const Divider(color: kBorder, thickness: 1, height: 1),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: kLime,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync, color: kBg, size: 16),
                const SizedBox(width: 8),
                Text('Renew', style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: kBg, letterSpacing: 0.35)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 56,
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
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 0.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
