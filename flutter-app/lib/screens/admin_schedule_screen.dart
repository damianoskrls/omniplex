import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kRed = Color(0xFFFF5D5D);
const _kRedBg = Color(0xFF2A1414);

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  int _selectedDay = 2; // 0=Mon, 1=Tue, 2=Wed (today), 3=Thu, 4=Fri, 5=Sat
  int _viewIndex = 0; // 0=Day, 1=Week

  final _days = [
    ('Mon', '10'),
    ('Tue', '11'),
    ('Wed', '12'),
    ('Thu', '13'),
    ('Fri', '14'),
    ('Sat', '15'),
  ];

  final _classes = [
    _ClassData(
      time: '09:00',
      endTime: '10:00',
      name: 'CrossFit',
      status: 'Nearly Full',
      coach: 'Coach Maria',
      room: 'Room 2',
      booked: 18,
      capacity: 20,
      dotColor: Color(0xFFC6FF3D),
      statusBg: Color(0xFF1D2410),
      statusBorder: Color(0x66C6FF3D),
      statusText: Color(0xFFC6FF3D),
      barColor: Color(0xFFC6FF3D),
    ),
    _ClassData(
      time: '11:00',
      endTime: '12:00',
      name: 'Yoga Flow',
      status: 'Open',
      coach: 'Coach Elena',
      room: 'Room 1',
      booked: 12,
      capacity: 18,
      dotColor: Color(0xFF3EE6FF),
      statusBg: Color(0xFF0F2429),
      statusBorder: Color(0x663EE6FF),
      statusText: Color(0xFF3EE6FF),
      barColor: Color(0xFF3EE6FF),
    ),
    _ClassData(
      time: '14:00',
      endTime: '15:00',
      name: 'Pilates Core',
      status: 'Low Booking',
      coach: 'Coach Nikos',
      room: 'Room 3',
      booked: 4,
      capacity: 15,
      dotColor: Color(0xFF5A5C63),
      statusBg: Color(0xFF1F2024),
      statusBorder: Color(0xFF3A3C42),
      statusText: Color(0xFF9A9CA3),
      barColor: Color(0xFF5A5C63),
    ),
    _ClassData(
      time: '17:30',
      endTime: '18:30',
      name: 'HIIT Blast',
      status: 'Filling Up',
      coach: 'Coach Dimitris',
      room: 'Room 1',
      booked: 14,
      capacity: 16,
      dotColor: Color(0xFFB57BFF),
      statusBg: Color(0xFF20142F),
      statusBorder: Color(0x66B57BFF),
      statusText: Color(0xFFB57BFF),
      barColor: Color(0xFFC6FF3D),
    ),
  ];

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admin Dashboard', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                            const SizedBox(height: 4),
                            Text('Class Schedule', style: GoogleFonts.spaceGrotesk(
                              fontSize: 20, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: -0.5)),
                          ],
                        ),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add, color: kBg, size: 12),
                              const SizedBox(width: 8),
                              Text('Add Class', style: GoogleFonts.spaceGrotesk(
                                fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // View toggle + filter
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: kBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: GestureDetector(
                                  onTap: () => setState(() => _viewIndex = 0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _viewIndex == 0 ? kLime : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Center(
                                      child: Text('Day', style: _viewIndex == 0
                                        ? GoogleFonts.spaceGrotesk(
                                            fontSize: 12, fontWeight: FontWeight.w700, color: kBg)
                                        : GoogleFonts.manrope(
                                            fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                                    ),
                                  ),
                                )),
                                Expanded(child: GestureDetector(
                                  onTap: () => setState(() => _viewIndex = 1),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _viewIndex == 1 ? kLime : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Center(
                                      child: Text('Week', style: _viewIndex == 1
                                        ? GoogleFonts.spaceGrotesk(
                                            fontSize: 12, fontWeight: FontWeight.w700, color: kBg)
                                        : GoogleFonts.manrope(
                                            fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBorder),
                          ),
                          child: const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ),
                  // Day picker
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _days.asMap().entries.map((e) {
                        final i = e.key;
                        final d = e.value;
                        final active = i == _selectedDay;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDay = i),
                          child: Container(
                            width: 48,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? kLime : kCard,
                              borderRadius: BorderRadius.circular(12),
                              border: active ? null : Border.all(color: kBorder),
                            ),
                            child: Column(
                              children: [
                                Text(d.$1.toUpperCase(), style: active
                                  ? GoogleFonts.manrope(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: kBg, letterSpacing: 0.4)
                                  : GoogleFonts.manrope(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: kGray, letterSpacing: 0.4)),
                                const SizedBox(height: 6),
                                Text(d.$2, style: active
                                  ? GoogleFonts.spaceGrotesk(
                                      fontSize: 14, fontWeight: FontWeight.w700, color: kBg)
                                  : GoogleFonts.manrope(
                                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Date header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Wednesday, June 12', style: GoogleFonts.spaceGrotesk(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: -0.4)),
                        Text('4 classes', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                      ],
                    ),
                  ),
                  // Timeline
                  Stack(
                    children: [
                      // Vertical line
                      Positioned(
                        left: 26, top: 8, bottom: 8,
                        child: Container(width: 1, color: kBorder),
                      ),
                      Column(
                        children: _classes.asMap().entries.map((e) {
                          final i = e.key;
                          final c = e.value;
                          return Padding(
                            padding: EdgeInsets.only(bottom: i < _classes.length - 1 ? 16 : 0),
                            child: _buildClassCard(c),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(_ClassData c) {
    final fillFraction = c.booked / c.capacity;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time column
        SizedBox(
          width: 48,
          child: Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: c.dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: c.dotColor.withValues(alpha: 0.60), blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(c.time, style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(c.endTime, style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w600, color: kDim)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Class card
        Expanded(
          child: Opacity(
            opacity: c.status == 'Low Booking' ? 0.80 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.name, style: GoogleFonts.spaceGrotesk(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: c.statusBg,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: c.statusBorder),
                        ),
                        child: Text(c.status, style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, fontWeight: FontWeight.w700, color: c.statusText)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Coach + room row
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.dotColor, width: 2),
                        ),
                        child: ClipOval(
                          child: Container(
                            color: const Color(0xFF2A2B30),
                            child: Icon(Icons.person, color: c.dotColor, size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(c.coach, style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(width: 8),
                      Container(
                        width: 4, height: 4,
                        decoration: const BoxDecoration(
                          color: kDim, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on_outlined, color: kGray, size: 10),
                      const SizedBox(width: 4),
                      Text(c.room, style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Capacity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Capacity', style: GoogleFonts.manrope(
                        fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
                      Text('${c.booked} / ${c.capacity} booked',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w700, color: c.barColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2024),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fillFraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.barColor,
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: c.barColor != kDim ? [
                            BoxShadow(color: c.barColor.withValues(alpha: 0.50), blurRadius: 8),
                          ] : null,
                        ),
                      ),
                    ),
                  ),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: kBorder)),
                      ),
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(child: _buildActionButton(
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _buildActionButton(
                            icon: Icons.swap_horiz_outlined,
                            label: 'Reassign',
                          )),
                          const SizedBox(width: 8),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: _kRedBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kRed.withValues(alpha: 0.40)),
                            ),
                            child: const Icon(Icons.close, color: _kRed, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label}) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2024),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ClassData {
  final String time;
  final String endTime;
  final String name;
  final String status;
  final String coach;
  final String room;
  final int booked;
  final int capacity;
  final Color dotColor;
  final Color statusBg;
  final Color statusBorder;
  final Color statusText;
  final Color barColor;

  const _ClassData({
    required this.time,
    required this.endTime,
    required this.name,
    required this.status,
    required this.coach,
    required this.room,
    required this.booked,
    required this.capacity,
    required this.dotColor,
    required this.statusBg,
    required this.statusBorder,
    required this.statusText,
    required this.barColor,
  });
}
