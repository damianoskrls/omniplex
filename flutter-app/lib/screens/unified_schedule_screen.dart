import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class UnifiedScheduleScreen extends StatefulWidget {
  const UnifiedScheduleScreen({super.key});

  @override
  State<UnifiedScheduleScreen> createState() => _UnifiedScheduleScreenState();
}

class _UnifiedScheduleScreenState extends State<UnifiedScheduleScreen> {
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);

  int _viewMode = 0; // 0=Day, 1=Week, 2=Month
  int _gymFilter = 0; // 0=All Gyms, 1=Fitness Club Athens, 2=Urban Fitness

  final _gyms = ['All Gyms', 'Fitness Club Athens', 'Urban Fitness'];
  final _views = ['Day', 'Week', 'Month'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildDaySection(
                      label: 'MONDAY, OCT 21',
                      isCurrent: true,
                      classes: [
                        _ClassData(
                          time: '18:30', duration: '60 MIN',
                          title: 'CrossFit\nIntermediate',
                          gym: 'Fitness Club Athens',
                          trainerName: 'Maria',
                          accentColor: kLime,
                        ),
                        _ClassData(
                          time: '20:00', duration: '45 MIN',
                          title: 'Yoga Flow',
                          gym: 'Urban Fitness',
                          trainerName: 'Alex',
                          accentColor: kCyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildDaySection(
                      label: 'TUESDAY, OCT 22',
                      isCurrent: false,
                      classes: [
                        _ClassData(
                          time: '07:30', duration: '50 MIN',
                          title: 'Personal\nTraining',
                          gym: 'Fitness Club Athens',
                          trainerName: 'Maria',
                          accentColor: Colors.white24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text('END OF SCHEDULED BOOKINGS',
                        style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: const Color(0xFF4B5563), letterSpacing: 3.0)),
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Container(
        color: kBg.withValues(alpha: 0.80),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MY SCHEDULE', style: GoogleFonts.spaceGrotesk(
                    fontSize: 24, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.6)),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _kBorder26,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBorder26),
                    ),
                    child: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Gym filter chips
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: _gyms.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final active = _gymFilter == i;
                  return GestureDetector(
                    onTap: () => setState(() => _gymFilter = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? kLime : _kBorder26,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: active ? kLime : _kBorder26),
                      ),
                      child: Text(_gyms[i].toUpperCase(), style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: active ? kBg : _kGray9C, letterSpacing: 0.6)),
                    ),
                  );
                },
              ),
            ),
            // Day/Week/Month tabs
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _kBorder26),
                ),
              ),
              child: Row(
                children: List.generate(_views.length, (i) {
                  final active = _viewMode == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewMode = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: active ? kLime : Colors.transparent,
                              width: 2),
                          ),
                        ),
                        child: Text(_views[i].toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: active ? kLime : _kGray6B,
                            letterSpacing: 1.2)),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection({
    required String label,
    required bool isCurrent,
    required List<_ClassData> classes,
  }) {
    return Column(
      children: [
        // Date label with divider lines
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCurrent
                      ? [kCyan.withValues(alpha: 0.50), kCyan.withValues(alpha: 0.0)]
                      : [const Color(0xFF374151).withValues(alpha: 0.50), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(label, style: GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w900,
                color: isCurrent ? kCyan : _kGray6B,
                letterSpacing: 2.4)),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCurrent
                      ? [kCyan.withValues(alpha: 0.0), kCyan.withValues(alpha: 0.50)]
                      : [Colors.transparent, const Color(0xFF374151).withValues(alpha: 0.50)],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...classes.map((cls) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildClassCard(cls),
        )),
      ],
    );
  }

  Widget _buildClassCard(_ClassData cls) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Time column
                        Column(
                          children: [
                            Text(cls.time, style: GoogleFonts.spaceGrotesk(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                            const SizedBox(height: 6),
                            Text(cls.duration, style: GoogleFonts.manrope(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: _kGray6B, letterSpacing: -0.5)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Container(width: 1, height: 32, color: _kBorder26),
                        const SizedBox(width: 16),
                        // Class info
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cls.title, style: GoogleFonts.manrope(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                            Text(cls.gym, style: GoogleFonts.manrope(
                              fontSize: 12, color: kCyan)),
                          ],
                        ),
                      ],
                    ),
                    // Confirmed badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kLime.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kLime.withValues(alpha: 0.20)),
                      ),
                      child: Text('CONFIRMED', style: GoogleFonts.manrope(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: kLime, letterSpacing: 0.9)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cls.accentColor.withValues(alpha: 0.30)),
                            color: const Color(0xFF3A3C42),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.manrope(fontSize: 12, color: _kGray9C),
                            children: [
                              const TextSpan(text: 'Trainer: '),
                              TextSpan(text: cls.trainerName,
                                style: GoogleFonts.manrope(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('DETAILS', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _kGray6B, letterSpacing: 1.2)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 14),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Left accent bar
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: cls.accentColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
          ),
        ],
      ),
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
          _buildNavItem(Icons.home_rounded, 'HOME', false),
          _buildNavItem(Icons.search, 'SEARCH', false),
          _buildScheduleNavItem(),
          _buildNavItem(Icons.fitness_center_outlined, 'MY GYMS', false),
          SizedBox(
            width: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGray6B),
                    color: const Color(0xFF3A3C42),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 14),
                ),
                const SizedBox(height: 4),
                Text('PROFILE', style: GoogleFonts.manrope(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _kGray6B, letterSpacing: 0.9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleNavItem() {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.calendar_today, color: kLime, size: 22),
              Positioned(
                top: -4, right: -4,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: kLime,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: kLime.withValues(alpha: 0.80), blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('SCHEDULE', style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: kLime, letterSpacing: 0.9)),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? kLime : _kGray6B, size: 22),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: active ? kLime : _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}

class _ClassData {
  final String time;
  final String duration;
  final String title;
  final String gym;
  final String trainerName;
  final Color accentColor;

  const _ClassData({
    required this.time,
    required this.duration,
    required this.title,
    required this.gym,
    required this.trainerName,
    required this.accentColor,
  });
}
