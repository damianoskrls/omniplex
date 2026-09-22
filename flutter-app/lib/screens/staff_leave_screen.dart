import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kOrange = Color(0xFFFFA53E);
const _kOrangeBg = Color(0xFF2B1D0E);
const _kRed = Color(0xFFFF5C5C);

class StaffLeaveScreen extends StatelessWidget {
  const StaffLeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Top lime glow
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
                  stops: const [0.0, 0.35, 0.60],
                ),
              ),
            ),
          ),
          // Bottom-right purple glow
          Positioned(
            right: 0, top: 384,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB57BFF).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.70],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: kCard,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: kBorder),
                                    ),
                                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  Text('My Leave', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 20, fontWeight: FontWeight.w700,
                                    color: Colors.white, letterSpacing: -0.5)),
                                ],
                              ),
                              Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kLime),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add, color: kLime, size: 14),
                                    const SizedBox(width: 6),
                                    Text('Request Leave', style: GoogleFonts.manrope(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: kLime)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Remaining leave card
                        _buildRemainingCard(),
                        const SizedBox(height: 24),
                        // Upcoming Leave
                        _buildSectionTitle('Upcoming Leave'),
                        const SizedBox(height: 12),
                        _buildLeaveRow(
                          iconBg: const Color(0xFF1D2410),
                          iconBorderColor: kLime.withValues(alpha: 0.30),
                          icon: Icons.flight_takeoff_outlined,
                          iconColor: kLime,
                          title: 'Annual Leave',
                          date: 'Oct 24',
                          badgeLabel: 'Approved',
                          badgeBg: const Color(0xFF1D2410),
                          badgeBorderColor: kLime.withValues(alpha: 0.40),
                          badgeTextColor: kLime,
                        ),
                        const SizedBox(height: 24),
                        // Pending Requests
                        _buildSectionTitle('Pending Requests'),
                        const SizedBox(height: 12),
                        _buildPendingCard(),
                        const SizedBox(height: 24),
                        // Previous Leave
                        _buildSectionTitle('Previous Leave'),
                        const SizedBox(height: 12),
                        _buildPreviousRow('Annual Leave', 'Aug 12-16'),
                        const SizedBox(height: 12),
                        _buildPreviousRow('Personal Leave', 'Jun 3'),
                        const SizedBox(height: 24),
                        // Request Leave form
                        _buildSectionTitle('Request Leave'),
                        const SizedBox(height: 12),
                        _buildRequestForm(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                // Bottom nav
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingCard() {
    return Container(
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
              Text('REMAINING LEAVE', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: kGray, letterSpacing: 0.3)),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2410),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kLime.withValues(alpha: 0.30)),
                ),
                child: const Icon(Icons.beach_access_outlined, color: kLime, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('18', style: GoogleFonts.spaceGrotesk(
                fontSize: 36, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.9,
                height: 1.1)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('days', style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: kGray, letterSpacing: -0.9)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Used 4 of 22 days this year', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
              Text('18%', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar (18% used → 82% remaining visually shown as used=left 18%)
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2024),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.18,
              child: Container(
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(color: kLime.withValues(alpha: 0.50), blurRadius: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: GoogleFonts.spaceGrotesk(
        fontSize: 16, fontWeight: FontWeight.w700,
        color: Colors.white, letterSpacing: -0.4)),
    );
  }

  Widget _buildLeaveRow({
    required Color iconBg,
    required Color iconBorderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String date,
    required String badgeLabel,
    required Color badgeBg,
    required Color badgeBorderColor,
    required Color badgeTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconBorderColor),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(date, style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: badgeBorderColor),
            ),
            child: Text(badgeLabel, style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700, color: badgeTextColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _kOrangeBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kOrange.withValues(alpha: 0.30)),
                    ),
                    child: const Icon(Icons.medical_services_outlined, color: _kOrange, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sick Leave', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('Nov 2-3', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kOrangeBg,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.40)),
                ),
                child: Text('Pending', style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _kOrange)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Cancel Request', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700, color: _kRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousRow(String title, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2024),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder2),
                ),
                child: const Icon(Icons.check, color: kDim, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: kGray)),
                  Text(date, style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kDim)),
                ],
              ),
            ],
          ),
          Text('Completed', style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w700, color: kDim)),
        ],
      ),
    );
  }

  Widget _buildRequestForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leave type
          Text('Leave type', style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2024),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D2410),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kLime.withValues(alpha: 0.30)),
                      ),
                      child: const Icon(Icons.flight_takeoff_outlined, color: kLime, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Text('Annual Leave', style: GoogleFonts.manrope(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
                const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Start/end dates
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start date', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                    const SizedBox(height: 8),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2024),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Nov 12', style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          const Icon(Icons.calendar_month_outlined, color: kGray, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End date', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                    const SizedBox(height: 8),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2024),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Nov 14', style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          const Icon(Icons.calendar_month_outlined, color: kGray, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Note
          Text('Note', style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
          const SizedBox(height: 8),
          Container(
            height: 96,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2024),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Text('Add a note (optional)', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w600, color: kDim)),
          ),
          const SizedBox(height: 12),
          // Submit button
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: kLime,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 10),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send_outlined, color: kBg, size: 16),
                const SizedBox(width: 8),
                Text('Submit Request', style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: kBg, letterSpacing: -0.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_outlined, 'Home', false),
          _buildNavItem(Icons.calendar_month_outlined, 'Calendar', false),
          _buildNavItem(Icons.assignment_outlined, 'Appointments', false),
          _buildNavItem(Icons.flight_takeoff_outlined, 'Leave', true),
          _buildNavItem(Icons.person_outline, 'Profile', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? kLime : kDim, size: 22),
          const SizedBox(height: 6),
          Text(label, style: active
            ? GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w700, color: kLime)
            : GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w600, color: kGray),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
