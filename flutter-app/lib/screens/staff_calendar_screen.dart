import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kPurple = Color(0xFFB57BFF);
const _kPurpleBg = Color(0xFF20142F);
const _kOrange = Color(0xFFFFA53E);
const _kOrangeBg = Color(0xFF2B1D0E);

class StaffCalendarScreen extends StatefulWidget {
  const StaffCalendarScreen({super.key});

  @override
  State<StaffCalendarScreen> createState() => _StaffCalendarScreenState();
}

class _StaffCalendarScreenState extends State<StaffCalendarScreen> {
  int _view = 1; // 0=Day, 1=Week, 2=Month
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
                  colors: [_kPurple.withValues(alpha: 0.08), Colors.transparent],
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
                        const SizedBox(height: 20),
                        _buildViewToggle(),
                        const SizedBox(height: 20),
                        _buildLegend(),
                        const SizedBox(height: 20),
                        _buildWeekPicker(),
                        const SizedBox(height: 24),
                        _buildDaySection(
                          date: 'Tue, Oct 21',
                          isToday: true,
                          entries: [
                            _CalEntry('09:00', 'Personal Training', 'Alex Papas · Room 2', kLime, const Color(0xFF1D2410), Icons.person_outline),
                            _CalEntry('10:30', 'CrossFit', 'Main Floor · 12 members', _kPurple, _kPurpleBg, Icons.people_outline),
                            _CalEntry('12:00', 'Break', '1 hour · Off duty', null, null, Icons.coffee_outlined),
                            _CalEntry('18:30', 'CrossFit', 'Main Floor · 18 members', _kPurple, _kPurpleBg, Icons.people_outline),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildDaySection(
                          date: 'Wed, Oct 22',
                          isToday: false,
                          entries: [
                            _CalEntry('09:30', 'Personal Training', 'Elena K. · Room 1', kLime, const Color(0xFF1D2410), Icons.person_outline),
                            _CalEntry('13:00', 'Break', '45 min · Off duty', null, null, Icons.coffee_outlined),
                            _CalEntry('17:00', 'CrossFit', 'Main Floor · 15 members', _kPurple, _kPurpleBg, Icons.people_outline),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildDaySection(
                          date: 'Thu, Oct 23',
                          isToday: false,
                          entries: [
                            _CalEntry('08:00', 'Personal Training', 'Nikos D. · Room 2', kLime, const Color(0xFF1D2410), Icons.person_outline),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildDaySection(
                          date: 'Fri, Oct 24',
                          isToday: false,
                          entries: [
                            _CalEntry('All Day', 'Approved Leave', 'Annual leave · Off duty full day', _kOrange, _kOrangeBg, Icons.flight_takeoff_outlined, isLeave: true),
                          ],
                        ),
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
        Text('My Calendar', style: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.5)),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: kCard, shape: BoxShape.circle,
            border: Border.all(color: kBorder),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 18),
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
            child: Text('Fitness Club Athens', style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    const labels = ['Day', 'Week', 'Month'];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = _view == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _view = i),
              child: Container(
                decoration: active ? BoxDecoration(
                  color: const Color(0xFF1D2410),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kLime.withValues(alpha: 0.40)),
                ) : null,
                child: Center(
                  child: Text(labels[i],
                    style: active
                      ? GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: kLime)
                      : GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLegend() {
    const items = [
      (_kPurple, 'Classes'),
      (kLime, 'Appointments'),
      (kDim, 'Breaks'),
      (_kOrange, 'Leave'),
    ];
    return Wrap(
      spacing: 16, runSpacing: 8,
      children: items.map((item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: item.$1, shape: BoxShape.circle,
              boxShadow: item.$1 != kDim ? [
                BoxShadow(color: item.$1.withValues(alpha: 0.8), blurRadius: 6),
              ] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(item.$2, style: GoogleFonts.manrope(
            fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
        ],
      )).toList(),
    );
  }

  Widget _buildWeekPicker() {
    final days = [
      ('Mon', '20', kGray, null),
      ('TUE', '21', kBg, kLime),  // active
      ('Wed', '22', kGray, null),
      ('Thu', '23', kGray, null),
      ('Fri', '24', _kOrange, null),
      ('Sat', '25', kGray, null),
      ('Sun', '26', kGray, null),
    ];

    return Row(
      children: List.generate(days.length, (i) {
        final d = days[i];
        final active = i == 1;
        final isFriLeave = i == 4;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {}),
            child: Container(
              margin: EdgeInsets.only(right: i < days.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? kLime : kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? kLime
                    : isFriLeave ? _kOrange.withValues(alpha: 0.40)
                    : kBorder),
              ),
              child: Column(
                children: [
                  Text(d.$1,
                    style: active
                      ? GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: kBg)
                      : GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600,
                          color: isFriLeave ? _kOrange : kGray)),
                  const SizedBox(height: 6),
                  Text(d.$2,
                    style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700,
                      color: active ? kBg : Colors.white)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDaySection({required String date, required bool isToday, required List<_CalEntry> entries}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(date, style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.4)),
            if (isToday) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2410),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: kLime.withValues(alpha: 0.40)),
                ),
                child: Text('TODAY', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: kLime, letterSpacing: 0.1)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildEntry(e),
        )),
      ],
    );
  }

  Widget _buildEntry(_CalEntry e) {
    final isBreak = e.accent == null;
    final isLeave = e.isLeave;

    if (isBreak) {
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
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(e.time, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: kGray)),
                    const SizedBox(width: 8),
                    Text('·', style: GoogleFonts.manrope(fontSize: 12, color: kDim)),
                    const SizedBox(width: 8),
                    Text(e.name, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
                  ]),
                  const SizedBox(height: 4),
                  Text(e.sub, style: GoogleFonts.manrope(fontSize: 12, color: kDim)),
                ],
              )),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: kBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder2),
                ),
                child: Icon(e.icon, color: kGray, size: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isLeave ? e.iconBg : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isLeave ? e.accent!.withValues(alpha: 0.40) : kBorder),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, isLeave ? 20 : 16, 16, isLeave ? 20 : 16),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(e.time, style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(width: 8),
                        Text('·', style: GoogleFonts.manrope(
                          fontSize: 12, color: isLeave ? e.accent! : kGray)),
                        const SizedBox(width: 8),
                        Text(e.name, style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      ]),
                      const SizedBox(height: 4),
                      Text(e.sub, style: GoogleFonts.manrope(fontSize: 12, color: kGray)),
                    ],
                  )),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isLeave ? kBg : e.iconBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: e.accent!.withValues(alpha: isLeave ? 0.40 : 0.30)),
                    ),
                    child: Icon(e.icon, color: e.accent, size: 16),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: e.accent!,
                  boxShadow: [BoxShadow(color: e.accent!.withValues(alpha: 0.6), blurRadius: 10)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_outlined, 'Home', false),
      (Icons.calendar_today_outlined, 'Calendar', true),
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

class _CalEntry {
  final String time;
  final String name;
  final String sub;
  final Color? accent;
  final Color? iconBg;
  final IconData icon;
  final bool isLeave;

  const _CalEntry(this.time, this.name, this.sub, this.accent, this.iconBg, this.icon, {this.isLeave = false});
}
