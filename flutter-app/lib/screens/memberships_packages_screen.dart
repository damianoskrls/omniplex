import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class MembershipsPackagesScreen extends StatelessWidget {
  const MembershipsPackagesScreen({super.key,
    this.gymName = 'Fitness Club Athens'});
  final String gymName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: OmniBgPainter(
            cyanOffset: Offset(MediaQuery.sizeOf(context).width, 384))),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 32),
                  _buildMembershipSection(),
                  const SizedBox(height: 32),
                  _buildPackageSection(),
                  const SizedBox(height: 32),
                  _buildDropInSection(),
                  const SizedBox(height: 24),
                  _buildInfoBox(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
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
                color: kCard,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          Text('Choose your plan', style: GoogleFonts.spaceGrotesk(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.6)),
          const SizedBox(height: 4),
          Text(gymName, style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, Color iconBg, Color iconBorder,
      String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
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
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: kLime, size: 12),
        const SizedBox(width: 10),
        Text(text, style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
      ],
    );
  }

  Widget _buildMembershipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          Icons.fitness_center,
          kLime.withValues(alpha: 0.10),
          kLime.withValues(alpha: 0.30),
          'Membership', 'Recurring unlimited access'),
        const SizedBox(height: 16),
        // Monthly card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly', style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.45)),
                const SizedBox(height: 4),
                Text('UNLIMITED CLASSES', style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: kCyan, letterSpacing: 0.3)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('€45', style: GoogleFonts.spaceGrotesk(
                      fontSize: 36, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.9)),
                    const SizedBox(width: 4),
                    Text('/month', style: GoogleFonts.manrope(
                      fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFeatureRow('Access to all group classes'),
                const SizedBox(height: 10),
                _buildFeatureRow('Full gym floor access'),
                const SizedBox(height: 10),
                _buildFeatureRow('Free locker & towel service'),
                const SizedBox(height: 10),
                _buildFeatureRow('Cancel anytime'),
                const SizedBox(height: 20),
                _chooseButton(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 3 Months card (best value)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kLime),
                  boxShadow: [
                    BoxShadow(
                      color: kLime.withValues(alpha: 0.18),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('3 Months', style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.45)),
                    const SizedBox(height: 4),
                    Text('UNLIMITED CLASSES', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: kCyan, letterSpacing: 0.3)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('€120', style: GoogleFonts.spaceGrotesk(
                          fontSize: 36, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: -0.9)),
                        const SizedBox(width: 4),
                        Text('total', style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
                      ],
                    ),
                    Text('Only €40/month · Save €15', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kLime)),
                    const SizedBox(height: 16),
                    _buildFeatureRow('Access to all group classes'),
                    const SizedBox(height: 10),
                    _buildFeatureRow('Full gym floor access'),
                    const SizedBox(height: 10),
                    _buildFeatureRow('Free locker & towel service'),
                    const SizedBox(height: 10),
                    _buildFeatureRow('1 free personal training session'),
                    const SizedBox(height: 20),
                    _chooseButton(),
                  ],
                ),
              ),
              // Best value badge
              Positioned(
                right: 16, top: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: kBg, size: 14),
                      const SizedBox(width: 4),
                      Text('BEST VALUE', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: kBg, letterSpacing: 0.4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          Icons.grid_view_rounded,
          kCyan.withValues(alpha: 0.10),
          kCyan.withValues(alpha: 0.30),
          'Class Package', 'Prepaid bundle of visits'),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('10 Class Pack', style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: -0.45)),
                        const SizedBox(height: 4),
                        Text('10 VISITS · VALID 90 DAYS', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: kCyan, letterSpacing: 0.3)),
                      ],
                    ),
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1D22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Icon(Icons.layers_outlined, color: kGray, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('€90', style: GoogleFonts.spaceGrotesk(
                      fontSize: 36, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.9)),
                    const SizedBox(width: 4),
                    Text('total', style: GoogleFonts.manrope(
                      fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
                  ],
                ),
                const SizedBox(height: 20),
                _chooseButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          Icons.bolt,
          const Color(0xFFFFB23E).withValues(alpha: 0.10),
          const Color(0xFFFFB23E).withValues(alpha: 0.30),
          'Drop-in', 'One-time single visit'),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1D22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(Icons.door_front_door_outlined, color: kGray, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Single\nDrop-in', style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.35)),
                      Text('Access for one day', style: GoogleFonts.manrope(
                        fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('€15', style: GoogleFonts.spaceGrotesk(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.5)),
                    Text('/visit', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w600, color: kGray)),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('Choose', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF26272C)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: kGray, size: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You'll need to sign in or create an account to complete your purchase after choosing a plan.",
                style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: kGray, height: 1.625)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chooseButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: kLime,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text('Choose', style: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w700, color: kBg)),
      ),
    );
  }
}
