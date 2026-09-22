import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  int _viewMode = 1; // 0=Day, 1=Week, 2=Month
  int _selectedDay = 2; // Wed (index in Mon–Sun)

  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final _dates = [10, 11, 12, 13, 14, 15, 16];

  static const _gymFilters = ['All Gyms', 'Fitness Club Athens', 'Urban Fitness'];
  static const _gymDots = [null, kLime, kCyan];
  int _gymFilter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Top lime radial glow
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
          // Cyan glow bottom right
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
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildViewToggle(),
                        const SizedBox(height: 20),
                        _buildDayPicker(),
                        const SizedBox(height: 24),
                        _buildGymFilter(),
                        const SizedBox(height: 28),
                        _buildDaySection('Monday', 'Oct 10', [
                          _BookingData('18:30', '60 min', 'CrossFit', 'Fitness Club Athens', kLime),
                          _BookingData('20:00', '45 min', 'Yoga', 'Urban Fitness', kCyan),
                        ]),
                        const SizedBox(height: 28),
                        _buildDaySection('Tuesday', 'Oct 11', [
                          _BookingData('07:30', '30 min', 'Personal Training', 'Fitness Club Athens', kLime),
                        ]),
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
            Text('My Schedule', style: GoogleFonts.spaceGrotesk(
              fontSize: 24, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.6)),
            const SizedBox(height: 4),
            Text('3 bookings this week', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
          ],
        ),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kBorder2),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  Widget _buildViewToggle() {
    const labels = ['Day', 'Week', 'Month'];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = _viewMode == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = i),
              child: Container(
                decoration: BoxDecoration(
                  color: active ? kLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(labels[i], style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? kBg : kGray,
                    letterSpacing: 0.3)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final active = _selectedDay == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedDay = i),
          child: Column(
            children: [
              Text(_days[i], style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? kLime : kGray)),
              const SizedBox(height: 8),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: active ? kLime : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: active ? [
                    BoxShadow(color: kLime.withValues(alpha: 0.4), blurRadius: 8),
                  ] : null,
                ),
                child: Center(
                  child: Text('${_dates[i]}', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: active ? kBg : Colors.white)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildGymFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_gymFilters.length, (i) {
          final active = _gymFilter == i;
          final dot = _gymDots[i];
          return Padding(
            padding: EdgeInsets.only(right: i < _gymFilters.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _gymFilter = i),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: active ? kLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                  border: active ? null : Border.all(color: kBorder2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dot != null) ...[
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(_gymFilters[i], style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? kBg : Colors.white,
                      letterSpacing: 0.3)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDaySection(String day, String date, List<_BookingData> bookings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header row
        Row(
          children: [
            Text(day, style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.4)),
            const SizedBox(width: 12),
            Text(date, style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
            const SizedBox(width: 12),
            const Expanded(child: Divider(color: kBorder, thickness: 1, height: 1)),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: bookings.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBookingCard(b),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildBookingCard(_BookingData b) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          // Color accent bar
          Container(
            width: 4, height: 56,
            decoration: BoxDecoration(
              color: b.accentColor,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          const SizedBox(width: 16),
          // Time column
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.time, style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white)),
                const SizedBox(height: 2),
                Text(b.duration, style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w600, color: kGray)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Class info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.className, style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(b.gymName, style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w400, color: kGray)),
                const SizedBox(height: 8),
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D2410),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, color: kLime, size: 10),
                      const SizedBox(width: 4),
                      Text('Confirmed', style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: kLime, letterSpacing: 0.25)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kGray, size: 16),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_outlined, 'Home', false),
      (Icons.search, 'Search', false),
      (Icons.calendar_today_outlined, 'Schedule', true),
      (Icons.fitness_center_outlined, 'My Gyms', false),
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
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF1D2410) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.$1,
                  color: active ? kLime : kGray, size: 20),
              ),
              const SizedBox(height: 6),
              Text(item.$2, style: active
                ? GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kLime, letterSpacing: 0.166)
                : GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w600, color: kGray)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _BookingData {
  final String time;
  final String duration;
  final String className;
  final String gymName;
  final Color accentColor;

  const _BookingData(this.time, this.duration, this.className, this.gymName, this.accentColor);
}
