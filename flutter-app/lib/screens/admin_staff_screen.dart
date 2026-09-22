import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kAmber = Color(0xFFFFB93D);
const _kAmberBg = Color(0xFF2A210F);

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  int _filterIndex = 0; // 0=All Staff, 1=On Shift, 2=On Leave

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
          // Bottom-right cyan glow
          Positioned(
            right: 0, top: 384,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kCyan.withValues(alpha: 0.08),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Admin Dashboard', style: GoogleFonts.manrope(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                                  const SizedBox(height: 4),
                                  Text('Staff', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 20, fontWeight: FontWeight.w700,
                                    color: Colors.white, letterSpacing: -0.5)),
                                ],
                              ),
                              Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: kLime,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add, color: kBg, size: 14),
                                    const SizedBox(width: 8),
                                    Text('Add Staff', style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Filter tabs
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            children: [
                              _buildFilterChip('All Staff', 0),
                              const SizedBox(width: 10),
                              _buildFilterChip('On Shift', 1),
                              const SizedBox(width: 10),
                              _buildFilterChip('On Leave', 2),
                            ],
                          ),
                        ),
                        // Team Members header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Team Members', style: GoogleFonts.spaceGrotesk(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: -0.4)),
                              Text('14 total', style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                            ],
                          ),
                        ),
                        // Staff cards
                        _buildStaffCard(
                          name: 'Maria Papadopoulou',
                          role: 'CrossFit Coach',
                          status: 'Active',
                          scheduleItems: ['09:00 PT', '10:30 CrossFit'],
                          availability: 'Available Mon–Fri',
                          leaveNote: null,
                          assignEnabled: true,
                        ),
                        const SizedBox(height: 12),
                        _buildStaffCard(
                          name: 'Nikos Anagnostou',
                          role: 'Strength Coach',
                          status: 'Off duty',
                          scheduleItems: [],
                          availability: 'Available Tue–Sat',
                          leaveNote: 'On leave until Oct 24',
                          assignEnabled: false,
                        ),
                        const SizedBox(height: 12),
                        _buildStaffCard(
                          name: 'Eleni Papadaki',
                          role: 'Yoga & Pilates Instructor',
                          status: 'Active',
                          scheduleItems: ['08:00 Yoga', '17:00 Pilates'],
                          availability: 'Available Mon, Wed, Fri',
                          leaveNote: null,
                          assignEnabled: true,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final active = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? kLime : kCard,
          borderRadius: BorderRadius.circular(9999),
          border: active ? null : Border.all(color: kBorder),
        ),
        child: Center(
          child: Text(label, style: active
            ? GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w700, color: kBg)
            : GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
        ),
      ),
    );
  }

  Widget _buildStaffCard({
    required String name,
    required String role,
    required String status,
    required List<String> scheduleItems,
    required String availability,
    required String? leaveNote,
    required bool assignEnabled,
  }) {
    final isActive = status == 'Active';
    final Color avatarBorder = isActive ? kLime : _kAmber;
    final Color statusBg = isActive ? const Color(0xFF1D2410) : const Color(0xFF1F2024);
    final Color statusBorder = isActive ? kLime.withValues(alpha: 0.40) : kBorder2;
    final Color statusText = isActive ? kLime : kGray;

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
          // Top row: avatar + name/role + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarBorder, width: 2),
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFF2A2B30),
                    child: Icon(Icons.person, color: isActive ? kLime : _kAmber, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(name, style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: statusBorder),
                          ),
                          child: Text(status, style: GoogleFonts.spaceGrotesk(
                            fontSize: 10, fontWeight: FontWeight.w700, color: statusText)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(role, style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Today's schedule
          Text("TODAY'S SCHEDULE", style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: kDim, letterSpacing: 0.25)),
          const SizedBox(height: 8),
          if (scheduleItems.isEmpty)
            Opacity(
              opacity: 0.50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2024),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: kGray, size: 10),
                    const SizedBox(width: 6),
                    Text('No sessions', style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              children: scheduleItems.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2024),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_outlined, color: kLime, size: 10),
                    const SizedBox(width: 6),
                    Text(item, style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              )).toList(),
            ),
          const SizedBox(height: 8),
          // Availability
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: kGray, size: 10),
              const SizedBox(width: 6),
              Text(availability, style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
            ],
          ),
          // Leave note
          if (leaveNote != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _kAmberBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kAmber.withValues(alpha: 0.30)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flight_takeoff_outlined, color: _kAmber, size: 11),
                  const SizedBox(width: 6),
                  Text(leaveNote, style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _kAmber)),
                ],
              ),
            ),
          ],
          // Action buttons
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Expanded(child: _buildActionButton(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    bg: const Color(0xFF1F2024),
                    borderColor: kBorder2,
                    textColor: Colors.white,
                    opacity: 1.0,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    bg: const Color(0xFF1F2024),
                    borderColor: kBorder2,
                    textColor: Colors.white,
                    opacity: 1.0,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionButton(
                    icon: Icons.calendar_month_outlined,
                    label: 'Assign',
                    bg: assignEnabled ? const Color(0xFF1D2410) : const Color(0xFF1F2024),
                    borderColor: assignEnabled ? kLime.withValues(alpha: 0.30) : kBorder2,
                    textColor: assignEnabled ? kLime : kGray,
                    opacity: assignEnabled ? 1.0 : 0.50,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bg,
    required Color borderColor,
    required Color textColor,
    required double opacity,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 12),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
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
          _buildNavItem(Icons.home_outlined, 'Home', false, false),
          _buildNavItem(Icons.people_outlined, 'Members', false, false),
          _buildNavItem(Icons.assignment_outlined, 'Staff', true, false),
          _buildNavItem(Icons.inbox_outlined, 'Requests', false, true),
          _buildNavItem(Icons.person_outline, 'Profile', false, false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active, bool hasBadge) {
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              SizedBox(
                width: 44, height: 44,
                child: Center(child: Icon(icon, color: active ? kLime : kDim, size: 22)),
              ),
              if (hasBadge)
                Positioned(
                  top: 4, right: 10,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _kAmber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: _kAmber.withValues(alpha: 0.90), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
            ],
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
