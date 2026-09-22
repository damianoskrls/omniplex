import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kPurple = Color(0xFFB57BFF);
const _kPurpleBg = Color(0xFF20142F);

class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key});

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
          // Purple bottom-right glow
          Positioned(
            right: 0, top: 384,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kPurple.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
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
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildWorkplaceBar(),
                        const SizedBox(height: 28),
                        _buildTodaySection(),
                        const SizedBox(height: 28),
                        _buildQuickActions(),
                        const SizedBox(height: 28),
                        _buildUpcomingSection(),
                        const SizedBox(height: 20),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monday, Oct 21', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
            const SizedBox(height: 4),
            Text('Good morning, Maria 👋', style: GoogleFonts.spaceGrotesk(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.5)),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: kCard, shape: BoxShape.circle,
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
                ),
                Positioned(
                  right: 10, top: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: kLime, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.9), blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kLime, width: 2),
                color: kGray,
              ),
              child: const Icon(Icons.person, color: kBg, size: 24),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkplaceBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1D2410),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kLime.withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.fitness_center, color: kLime, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('WORKING AT', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: kGray, letterSpacing: 1.0)),
                Text('Fitness Club Athens', style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
        ],
      ),
    );
  }

  Widget _buildTodaySection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today', style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.4)),
            Text('4 sessions', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
          ],
        ),
        const SizedBox(height: 12),
        _buildSessionCard(time: '09:00', name: 'Personal Training',
          sub: 'with Alex Papas · Room 2', accentColor: kLime,
          iconBg: const Color(0xFF1D2410), iconBorderColor: kLime.withValues(alpha: 0.30),
          iconColor: kLime, icon: Icons.person_outline),
        const SizedBox(height: 12),
        _buildSessionCard(time: '10:30', name: 'CrossFit',
          sub: '12 members · Main Floor', accentColor: _kPurple,
          iconBg: _kPurpleBg, iconBorderColor: _kPurple.withValues(alpha: 0.30),
          iconColor: _kPurple, icon: Icons.people_outline),
        const SizedBox(height: 12),
        _buildBreakCard(),
        const SizedBox(height: 12),
        _buildSessionCard(time: '18:30', name: 'CrossFit',
          sub: '18 members · Main Floor', accentColor: _kPurple,
          iconBg: _kPurpleBg, iconBorderColor: _kPurple.withValues(alpha: 0.30),
          iconColor: _kPurple, icon: Icons.people_outline),
      ],
    );
  }

  Widget _buildSessionCard({
    required String time, required String name, required String sub,
    required Color accentColor, required Color iconBg,
    required Color iconBorderColor, required Color iconColor, required IconData icon,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(time, style: GoogleFonts.spaceGrotesk(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(width: 8),
                            Text('·', style: GoogleFonts.manrope(fontSize: 12, color: kGray)),
                            const SizedBox(width: 8),
                            Text(name, style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(sub, style: GoogleFonts.manrope(
                          fontSize: 12, color: kGray)),
                      ],
                    ),
                  ),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: iconBg, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: iconBorderColor),
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.6), blurRadius: 10)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakCard() {
    return Opacity(
      opacity: 0.70,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2024),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder2, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('12:00', style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, fontWeight: FontWeight.w700, color: kGray)),
                      const SizedBox(width: 8),
                      Text('·', style: GoogleFonts.manrope(fontSize: 12, color: kDim)),
                      const SizedBox(width: 8),
                      Text('Break', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('1 hour · Off duty', style: GoogleFonts.manrope(
                    fontSize: 12, color: kDim)),
                ],
              ),
            ),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: kBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder2),
              ),
              child: const Icon(Icons.coffee_outlined, color: kGray, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.calendar_month_outlined, const Color(0xFF1D2410), kLime.withValues(alpha: 0.30), kLime, 'Add\nAppointment'),
      (Icons.access_time_outlined, const Color(0xFF0F2429), kCyan.withValues(alpha: 0.30), kCyan, 'My Availability'),
      (Icons.flight_takeoff_outlined, _kPurpleBg, _kPurple.withValues(alpha: 0.30), _kPurple, 'Request Leave'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.4)),
        const SizedBox(height: 12),
        Row(
          children: actions.map((a) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: a == actions.last ? 0 : 12),
              height: 104,
              decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: a.$2, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: a.$3),
                    ),
                    child: Icon(a.$1, color: a.$4, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(a.$5, textAlign: TextAlign.center, style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    final items = [
      ('22', 'Tue', '09:30 Personal Training', 'with Elena K. · Room 1', kLime),
      ('23', 'Wed', '17:00 CrossFit', '15 members · Main Floor', _kPurple),
      ('24', 'Thu', '08:00 Personal Training', 'with Nikos D. · Room 2', kLime),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming', style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.4)),
            Row(
              children: [
                Text('See all', style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: kGray, size: 14),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isLast = i == items.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: kBg, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBorder2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item.$1, style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                              Text(item.$2, style: GoogleFonts.manrope(
                                fontSize: 9, fontWeight: FontWeight.w600,
                                color: kGray, letterSpacing: 0.4)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$3, style: GoogleFonts.manrope(
                                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(item.$4, style: GoogleFonts.manrope(
                                fontSize: 12, color: kGray)),
                            ],
                          ),
                        ),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: item.$5, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: item.$5.withValues(alpha: 0.8), blurRadius: 8)],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(color: kBorder, thickness: 1, height: 1),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_outlined, 'Home', true),
      (Icons.calendar_today_outlined, 'Calendar', false),
      (Icons.assignment_outlined, 'Appointments', false),
      (Icons.flight_takeoff_outlined, 'Leave', false),
      (Icons.person_outline, 'Profile', false),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          final active = item.$3;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, color: active ? kLime : kDim, size: 20),
              const SizedBox(height: 6),
              Text(item.$2,
                style: active
                  ? GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: kLime)
                  : GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: kDim)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
