import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kOrange = Color(0xFFFFA53E);
const _kOrangeBg = Color(0xFF2B1D0E);
const _kRed = Color(0xFFFF5C5C);

class StaffAppointmentsScreen extends StatefulWidget {
  const StaffAppointmentsScreen({super.key});

  @override
  State<StaffAppointmentsScreen> createState() => _StaffAppointmentsScreenState();
}

class _StaffAppointmentsScreenState extends State<StaffAppointmentsScreen> {
  int _tab = 0; // 0=Today, 1=Upcoming, 2=Completed, 3=Cancelled

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
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Appointments', style: GoogleFonts.spaceGrotesk(
                                fontSize: 20, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: -0.5)),
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: kCard,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kBorder),
                                ),
                                child: const Icon(Icons.filter_list, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                        // Workplace bar
                        Container(
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                      color: const Color(0xFF1D2410),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kLime.withValues(alpha: 0.30)),
                                    ),
                                    child: const Icon(Icons.fitness_center, color: kLime, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Fitness Club Athens', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                              const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
                            ],
                          ),
                        ),
                        // Tab toggle
                        Container(
                          height: 48,
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorder),
                          ),
                          child: Row(
                            children: [
                              _buildTab(0, 'Today'),
                              _buildTab(1, 'Upcoming'),
                              _buildTab(2, 'Completed'),
                              _buildTab(3, 'Cancelled'),
                            ],
                          ),
                        ),
                        // Section header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tue, Oct 21', style: GoogleFonts.spaceGrotesk(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: -0.4)),
                              Text('3 appointments', style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                            ],
                          ),
                        ),
                        // Appointment cards
                        Column(
                          children: [
                            _buildPendingCard(),
                            const SizedBox(height: 16),
                            _buildConfirmedCard1(),
                            const SizedBox(height: 16),
                            _buildConfirmedCard2(),
                          ],
                        ),
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

  Widget _buildTab(int index, String label) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1D2410) : null,
            borderRadius: BorderRadius.circular(12),
            border: isActive ? Border.all(color: kLime.withValues(alpha: 0.40)) : null,
          ),
          child: Center(
            child: Text(label, style: isActive
              ? GoogleFonts.spaceGrotesk(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: kLime, letterSpacing: 0.22)
              : GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Member row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kBorder2),
                            color: const Color(0xFF2A2B30),
                          ),
                          child: const Icon(Icons.person, color: kGray, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Alex Papas', style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text('Personal Training', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kOrangeBg,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: _kOrange.withValues(alpha: 0.40)),
                      ),
                      child: Text('PENDING', style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _kOrange, letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Time + location
                _buildInfoRow(Icons.access_time_outlined, '09:00 - 10:00'),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.location_on_outlined, 'Fitness Club Athens · Room 2'),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: kBg, size: 14),
                            const SizedBox(width: 6),
                            Text('Confirm', style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2024),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.close, color: _kRed, size: 14),
                            const SizedBox(width: 6),
                            Text('Cancel', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w700, color: _kRed)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Left accent bar
            Positioned(
              left: -16, top: -16, bottom: -16,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _kOrange,
                  boxShadow: [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.60),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmedCard1() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kBorder2),
                            color: const Color(0xFF2A2B30),
                          ),
                          child: const Icon(Icons.person, color: kGray, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Elena Kostas', style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text('Nutrition Consult', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                          ],
                        ),
                      ],
                    ),
                    _buildConfirmedBadge(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.access_time_outlined, '11:30 - 12:15'),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.location_on_outlined, 'Fitness Club Athens · Room 1'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: kBg, size: 14),
                            const SizedBox(width: 6),
                            Text('Complete', style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 122,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2024),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh, color: kCyan, size: 14),
                            const SizedBox(width: 6),
                            Text('Reschedule', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w700, color: kCyan)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2024),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder2),
                      ),
                      child: const Icon(Icons.close, color: _kRed, size: 14),
                    ),
                  ],
                ),
              ],
            ),
            // Left accent bar
            Positioned(
              left: -16, top: -16, bottom: -16,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: kLime,
                  boxShadow: [
                    BoxShadow(
                      color: kLime.withValues(alpha: 0.60),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmedCard2() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kBorder2),
                            color: const Color(0xFF2A2B30),
                          ),
                          child: const Icon(Icons.person, color: kGray, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nikos Dimou', style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text('Personal Training', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                          ],
                        ),
                      ],
                    ),
                    _buildConfirmedBadge(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.access_time_outlined, '15:00 - 16:00'),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.location_on_outlined, 'Fitness Club Athens · Room 2'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: kBg, size: 14),
                            const SizedBox(width: 6),
                            Text('Complete', style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 122,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2024),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh, color: kCyan, size: 14),
                            const SizedBox(width: 6),
                            Text('Reschedule', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w700, color: kCyan)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2024),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder2),
                      ),
                      child: const Icon(Icons.close, color: _kRed, size: 14),
                    ),
                  ],
                ),
              ],
            ),
            // Left accent bar
            Positioned(
              left: -16, top: -16, bottom: -16,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: kLime,
                  boxShadow: [
                    BoxShadow(
                      color: kLime.withValues(alpha: 0.60),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2410),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: kLime.withValues(alpha: 0.40)),
      ),
      child: Text('CONFIRMED', style: GoogleFonts.manrope(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: kLime, letterSpacing: 0.5)),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Icon(icon, color: kGray, size: 12),
        ),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_outlined, 'Home', false),
          _buildNavItem(Icons.calendar_month_outlined, 'Calendar', false),
          _buildNavItem(Icons.assignment_outlined, 'Appointments', true),
          _buildNavItem(Icons.flight_takeoff_outlined, 'Leave', false),
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
          Container(
            width: 44, height: 44,
            decoration: active ? BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.20), blurRadius: 12)],
            ) : null,
            child: Icon(icon, color: active ? kLime : kDim, size: 22),
          ),
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
