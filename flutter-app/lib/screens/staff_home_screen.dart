import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key});

  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kDark16 = Color(0xFF161616);
  static const _kDark1C = Color(0xFF1C1C1C);
  static const _kBorder26 = Color(0xFF262626);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 0),
                      _buildShiftCard(),
                      const SizedBox(height: 32),
                      _buildQuickActionsSection(),
                      const SizedBox(height: 32),
                      _buildScheduleSection(),
                      const SizedBox(height: 32),
                      _buildWorkloadChart(),
                      const SizedBox(height: 32),
                      _buildTrialsSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.90),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good morning,', style: GoogleFonts.manrope(
                fontSize: 14, color: _kGray9C)),
              const SizedBox(height: 3),
              Text('Maria 👋', style: GoogleFonts.spaceGrotesk(
                fontSize: 24, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.6)),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text('FITNESS CLUB ATHENS', style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: kCyan, letterSpacing: 1.1)),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, color: kCyan, size: 12),
                ],
              ),
            ],
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _kDark16,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder26),
                ),
                child: const Center(child: Icon(Icons.notifications_outlined, color: Colors.white, size: 20)),
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: kLime,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBg, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.85, -1),
          end: Alignment(0.85, 1),
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border(
          left: const BorderSide(color: kLime, width: 4),
          top: BorderSide(color: kLime.withValues(alpha: 0.50)),
          right: BorderSide(color: kLime.withValues(alpha: 0.50)),
          bottom: BorderSide(color: kLime.withValues(alpha: 0.50)),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              color: const Color(0xFF3A2E1E),
            ),
            child: const Icon(Icons.person, color: Color(0xFFD4A06A), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENT SHIFT', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kGray6B, letterSpacing: -0.5)),
                Text('On Duty • 08:00 - 14:00', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('ACTIVE NOW', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: kLime, letterSpacing: 1.0)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("TODAY'S\nEARNINGS", style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _kGray6B, letterSpacing: -0.5),
                textAlign: TextAlign.right),
              const SizedBox(height: 2),
              Text('€142.50', style: GoogleFonts.spaceGrotesk(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: kCyan)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final actions = [
      (Icons.add, 'ADD APPT', null),
      (Icons.history, 'AVAILABILITY', null),
      (Icons.flight_takeoff, 'LEAVE', null),
      (Icons.fitness_center, 'PROGRAMS', null),
      (Icons.chat_bubble_outline, 'MESSAGES', kCyan),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUICK ACTIONS', style: GoogleFonts.spaceGrotesk(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: kCyan, letterSpacing: 1.4)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((a) {
            return Expanded(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: _kDark16,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kBorder26),
                        ),
                        child: Center(child: Icon(a.$1, color: Colors.white, size: 18)),
                      ),
                      if (a.$3 != null)
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: a.$3, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(a.$2, style: GoogleFonts.manrope(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: _kGray9C, letterSpacing: -0.225),
                    textAlign: TextAlign.center),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("TODAY'S SCHEDULE", style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: kCyan, letterSpacing: 1.4)),
            Text('MON, OCT 21', style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 16),
        // Schedule items with timeline
        _buildTimelineItem(
          time: '08:00', sub: 'DONE',
          title: 'Gym Cleaning Routine', detail: 'Facility Task',
          detailColor: _kGray6B, timeColor: Colors.white, subColor: _kGray6B,
          isActive: false, isDone: true,
          trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF6B7280), size: 16),
        ),
        _buildTimelineItem(
          time: '09:00', sub: '60 MIN',
          title: 'Personal Training', detail: 'Client: Alex Johnson',
          detailColor: _kGray9C, timeColor: kLime, subColor: kLime,
          isActive: true, isDone: false,
          trailing: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: kLime, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.qr_code_scanner, color: kBg, size: 20),
          ),
        ),
        _buildTimelineItem(
          time: '10:30', sub: '90 MIN',
          title: 'CrossFit WOD', detail: 'Group Class • 18 Booked',
          detailColor: _kGray9C, timeColor: Colors.white, subColor: _kGray6B,
          isActive: false, isDone: false,
          trailing: _buildAvatarStack(),
        ),
        _buildTimelineItem(
          time: '18:30', sub: '60 MIN',
          title: 'CrossFit Advanced', detail: 'Group Class • 12 Booked',
          detailColor: _kGray9C, timeColor: Colors.white, subColor: _kGray6B,
          isActive: false, isDone: false, isLast: true,
          trailing: const Icon(Icons.people_outline, color: Color(0xFF6B7280), size: 20),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String time,
    required String sub,
    required String title,
    required String detail,
    required Color detailColor,
    required Color timeColor,
    required Color subColor,
    required bool isActive,
    required bool isDone,
    bool isLast = false,
    required Widget trailing,
  }) {
    return Opacity(
      opacity: isDone ? 0.50 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: isActive ? 20 : 16,
                  height: isActive ? 20 : 16,
                  decoration: BoxDecoration(
                    color: isActive ? kLime : _kBorder26,
                    shape: BoxShape.circle,
                    border: isActive ? Border.all(color: kBg, width: 4) : Border.all(color: kBg, width: 2),
                    boxShadow: isActive ? [BoxShadow(
                      color: kLime.withValues(alpha: 0.50), blurRadius: 10)] : null,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2, height: 80,
                    color: isActive ? kLime.withValues(alpha: 0.30) : _kBorder26,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 0),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive ? _kDark1C : _kDark16,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? kLime.withValues(alpha: 0.30) : _kBorder26),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(time, style: GoogleFonts.manrope(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: timeColor)),
                          Text(sub, style: GoogleFonts.manrope(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: subColor, letterSpacing: 0.27)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.manrope(fontSize: 10, color: detailColor),
                              children: detail.contains('Booked')
                                  ? [
                                      TextSpan(text: '${detail.split('•')[0]}• '),
                                      TextSpan(text: detail.split('• ')[1], style: GoogleFonts.manrope(color: kCyan)),
                                    ]
                                  : detail.contains('Client:')
                                      ? [
                                          TextSpan(text: 'Client: '),
                                          TextSpan(text: detail.split(': ')[1], style: GoogleFonts.manrope(color: Colors.white, fontSize: 10)),
                                        ]
                                      : [TextSpan(text: detail)],
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(width: 24, height: 24, decoration: BoxDecoration(
          shape: BoxShape.circle, color: const Color(0xFF4A4A4A),
          border: Border.all(color: _kDark16))),
        Positioned(left: 16, child: Container(width: 24, height: 24, decoration: BoxDecoration(
          shape: BoxShape.circle, color: const Color(0xFF5A5A6A),
          border: Border.all(color: _kDark16)))),
        Positioned(left: 32, child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _kBorder26, border: Border.all(color: _kDark16)),
          child: Center(child: Text('+16', style: GoogleFonts.manrope(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
        )),
        const SizedBox(width: 56),
      ],
    );
  }

  Widget _buildWorkloadChart() {
    final bars = [32.0, 68.0, 48.0, 24.0, 16.0, 36.0, 76.0, 56.0];
    final peakIndices = {1, 6};
    final labels = ['08:00', '10:00', '12:00', '14:00', '16:00', '18:00', '20:00', '22:00'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.85, -1),
          end: Alignment(0.85, 1),
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STAFF WORKLOAD', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _kGray9C, letterSpacing: 1.0)),
              Text('Peak at 11:00 AM', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700, color: kLime)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.asMap().entries.map((e) {
                final isPeak = peakIndices.contains(e.key);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: e.value,
                      decoration: BoxDecoration(
                        color: isPeak ? kLime : _kBorder26,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        boxShadow: isPeak ? [BoxShadow(color: kLime.withValues(alpha: 0.30), blurRadius: 10)] : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((l) => Text(l, style: GoogleFonts.manrope(
              fontSize: 8, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: -0.4))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Trials", style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildTrialCard('Morning Yoga'),
            const SizedBox(width: 12),
            _buildTrialCard('HIIT Intro'),
          ],
        ),
      ],
    );
  }

  Widget _buildTrialCard(String name) {
    return Container(
      width: 150, height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBorder26, borderRadius: BorderRadius.circular(16)),
      child: Text(name, style: GoogleFonts.manrope(fontSize: 14, color: Colors.white)),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_filled, 'HOME', true),
          _buildNavItem(Icons.calendar_today, 'SCHEDULE', false),
          _buildNavItem(Icons.group_outlined, 'CLIENTS', false),
          _buildChatNav(),
          _buildProfileNav(),
          _buildNavItem(Icons.science_outlined, 'TRIALS', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? kLime : _kGray6B, size: 20),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: active ? kLime : _kGray6B, letterSpacing: 0.9)),
      ],
    );
  }

  Widget _buildChatNav() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_outlined, color: Color(0xFF6B7280), size: 20),
            const SizedBox(height: 4),
            Text('CHAT', style: GoogleFonts.manrope(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 0.9)),
          ],
        ),
        Positioned(
          top: 10, right: -4,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: kCyan, shape: BoxShape.circle,
              border: Border.all(color: kBg, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileNav() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kGray6B),
            color: const Color(0xFF3A2E1E),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 14),
        ),
        const SizedBox(height: 4),
        Text('PROFILE', style: GoogleFonts.manrope(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: _kGray6B, letterSpacing: 0.9)),
      ],
    );
  }
}
