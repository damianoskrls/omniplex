import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class ClassDetailsScreen extends StatelessWidget {
  const ClassDetailsScreen({super.key,
    this.className = 'Strength Training',
    this.category = 'Strength',
    this.categoryColor = kLime,
    this.gymName = 'Fitness Club Athens',
    this.coachName = 'Coach Maria',
    this.coachSpecialty = 'Strength & Conditioning',
    this.date = 'Tue, June 23',
    this.time = '18:30',
    this.duration = '50 min',
    this.level = 'Intermediate',
    this.levelDots = 2,
    this.spotsLeft = 2,
    this.totalSpots = 20,
  });

  final String className;
  final String category;
  final Color categoryColor;
  final String gymName;
  final String coachName;
  final String coachSpecialty;
  final String date;
  final String time;
  final String duration;
  final String level;
  final int levelDots;
  final int spotsLeft;
  final int totalSpots;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(context),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(className, style: GoogleFonts.spaceGrotesk(
                        fontSize: 24, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.6)),
                      const SizedBox(height: 12),
                      _buildGymRow(),
                      const SizedBox(height: 10),
                      _buildCoachRow(),
                      const SizedBox(height: 20),
                      _buildMetaChips(),
                      const SizedBox(height: 24),
                      _buildAbout(),
                      const SizedBox(height: 24),
                      _buildWhatToBring(),
                      const SizedBox(height: 24),
                      _buildAvailability(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return SizedBox(
      height: 256,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF1A1B20)),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C0A0A0A), Color(0x260A0A0A), Color(0xF20A0A0A)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          // Top bar
          Positioned(
            left: 20, right: 20, top: 56,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xCC16171B),
                      shape: BoxShape.circle,
                      border: Border.all(color: kBorder),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Class Details', style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.4)),
              ],
            ),
          ),
          // Category badge
          Positioned(
            left: 20, bottom: 16,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Center(
                child: Text(category, style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: kBg, letterSpacing: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1D22),
              shape: BoxShape.circle,
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.fitness_center, color: kGray, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gymName, style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('View gym profile', style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kGray, size: 16),
        ],
      ),
    );
  }

  Widget _buildCoachRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF2A2B30), shape: BoxShape.circle),
            child: const Icon(Icons.person, color: kGray, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coachName, style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(coachSpecialty, style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text('4.9', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChips() {
    return Column(
      children: [
        Row(
          children: [
            _chip(Icons.calendar_today_outlined, date),
            const SizedBox(width: 8),
            _chip(Icons.access_time_outlined, time),
            const SizedBox(width: 8),
            _chip(Icons.timer_outlined, duration),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1D22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Text(level, style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: i < levelDots ? kLime : kBorder2,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kGray, size: 12),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About this class', style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 10),
        Text(
          'A high-intensity strength session focused on compound lifts and progressive overload. Coach Maria guides you through squats, deadlifts, and presses with proper form coaching for all levels. Perfect for building raw power and muscular endurance in a supportive group environment.',
          style: GoogleFonts.manrope(
            fontSize: 14, color: kGray, height: 1.625)),
      ],
    );
  }

  Widget _buildWhatToBring() {
    final items = [
      (Icons.water_drop_outlined, 'Water bottle'),
      (Icons.cleaning_services_outlined, 'Towel'),
      (Icons.directions_run, 'Training shoes'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What to bring', style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        Column(
          children: items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1D22),
                      shape: BoxShape.circle,
                      border: Border.all(color: kBorder),
                    ),
                    child: Icon(item.$1, color: kGray, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(item.$2, style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildAvailability() {
    final fillFraction = 1.0 - (spotsLeft / totalSpots);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB23E), size: 16),
              const SizedBox(width: 8),
              Text('Almost full · $spotsLeft of $totalSpots spots left',
                style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFB23E))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 10,
              color: kCard,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fillFraction,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFB23E), Color(0xFFC6FF3D)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBg,
        border: const Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: kLime,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, color: kBg, size: 16),
                const SizedBox(width: 8),
                Text('Book Class', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kBg)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder2),
            ),
            child: Center(
              child: Text('Book Drop-in', style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
