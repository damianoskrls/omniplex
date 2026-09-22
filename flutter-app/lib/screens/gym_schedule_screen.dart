import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class GymScheduleScreen extends StatefulWidget {
  const GymScheduleScreen({super.key, this.gymName = 'Fitness Club Athens'});
  final String gymName;

  @override
  State<GymScheduleScreen> createState() => _GymScheduleScreenState();
}

class _GymScheduleScreenState extends State<GymScheduleScreen> {
  int _selectedDay = 1; // Tuesday selected

  final _days = ['MON', 'TUE', 'WED', 'THU', 'FRI'];
  final _dates = [22, 23, 24, 25, 26];

  final _classes = [
    _ClassData(time: '07:00', period: 'AM', name: 'CrossFit',
      coach: 'Coach Nikos', duration: '60 min',
      spots: '12 spots available', spotsColor: 0xFF3EE6FF,
      dotColor: 0xFFB48CFF, barColor: 0xFFB48CFF),
    _ClassData(time: '09:00', period: 'AM', name: 'Yoga Flow',
      coach: 'Coach Elena', duration: '45 min',
      spots: '8 spots available', spotsColor: 0xFF3EE6FF,
      dotColor: 0xFF3EE6FF, barColor: 0xFF3EE6FF),
    _ClassData(time: '18:30', period: 'PM', name: 'Strength Training',
      coach: 'Coach Maria', duration: '50 min',
      spots: 'Almost full · 2 spots left', spotsColor: 0xFFFFB23E,
      dotColor: 0xFFC6FF3D, barColor: 0xFFC6FF3D),
    _ClassData(time: '19:30', period: 'PM', name: 'Pilates Reformer',
      coach: 'Coach Sofia', duration: '45 min',
      spots: '6 spots available', spotsColor: 0xFF3EE6FF,
      dotColor: 0xFFFF6FD8, barColor: 0xFFFF6FD8),
    _ClassData(time: '20:30', period: 'PM', name: 'CrossFit',
      coach: 'Coach Dimitris', duration: '60 min',
      spots: '15 spots available', spotsColor: 0xFF3EE6FF,
      dotColor: 0xFFB48CFF, barColor: 0xFFB48CFF),
  ];

  final _categories = [
    ('CrossFit', 0xFFB48CFF),
    ('Yoga', 0xFF3EE6FF),
    ('Strength', 0xFFC6FF3D),
    ('Pilates', 0xFFFF6FD8),
  ];

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
                  const SizedBox(height: 24),
                  _buildTabBar(),
                  const SizedBox(height: 24),
                  _buildMonthHeader(),
                  const SizedBox(height: 28),
                  _buildDayPicker(),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Tuesday, June 23', style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.45)),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _classes.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ClassCard(data: c),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildLegend(),
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
      child: Row(
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.gymName, style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.45)),
                Text('Class Schedule', style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
              ],
            ),
          ),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kCard, shape: BoxShape.circle,
              border: Border.all(color: kBorder)),
            child: const Icon(Icons.tune, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Overview', 'Schedule', 'Memberships', 'Reviews'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: tabs.map((t) {
            final active = t == 'Schedule';
            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: active ? kLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(t, style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? kBg : kGray)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('June 2024', style: GoogleFonts.spaceGrotesk(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.45)),
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('5 classes today', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayPicker() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final active = _selectedDay == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = i),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: active ? kLime : kCard,
                borderRadius: BorderRadius.circular(16),
                border: active ? null : Border.all(color: kBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_days[i], style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: active ? kBg : kGray)),
                  const SizedBox(height: 4),
                  Text('${_dates[i]}', style: GoogleFonts.spaceGrotesk(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: active ? kBg : Colors.white)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class Categories', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: _categories.map((c) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: Color(c.$2), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(c.$1, style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
                ],
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassData {
  final String time;
  final String period;
  final String name;
  final String coach;
  final String duration;
  final String spots;
  final int spotsColor;
  final int dotColor;
  final int barColor;
  const _ClassData({
    required this.time, required this.period, required this.name,
    required this.coach, required this.duration, required this.spots,
    required this.spotsColor, required this.dotColor, required this.barColor,
  });
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.data});
  final _ClassData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(data.time, style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(data.period, style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w600, color: kGray)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 48, color: const Color(0xFF26272C)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: Color(data.dotColor), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(data.name, style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${data.coach} · ${data.duration}', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.people_outline, color: Color(data.spotsColor), size: 12),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(data.spots, style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Color(data.spotsColor))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('Book', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                  ),
                ),
              ],
            ),
          ),
          // Color bar on left
          Positioned(
            left: 0, top: 0, bottom: 0, width: 4,
            child: Container(color: Color(data.barColor)),
          ),
        ],
      ),
    );
  }
}
