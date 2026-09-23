import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class TrainingProgramsScreen extends StatefulWidget {
  const TrainingProgramsScreen({super.key});

  @override
  State<TrainingProgramsScreen> createState() => _TrainingProgramsScreenState();
}

class _TrainingProgramsScreenState extends State<TrainingProgramsScreen> {
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kDark16 = Color(0xFF161616);
  static const _kDark26 = Color(0xFF262626);

  int _activeFilter = 0;
  final _filters = ['All', 'Strength', 'Cardio'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Subtle radial gradients
          Positioned(
            top: -60, left: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  kCyan.withValues(alpha: 0.05), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: 100, right: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  kLime.withValues(alpha: 0.05), Colors.transparent]),
              ),
            ),
          ),
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 112),
            child: Column(
              children: [
                const SizedBox(height: 100),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    children: [
                      _buildFilters(),
                      const SizedBox(height: 32),
                      _buildProgramCard(
                        title: 'Strength\nFoundation',
                        levelTag: 'Pro Level',
                        levelColor: kLime,
                        typeTag: 'Strength',
                        duration: '4 Weeks',
                        durationColor: _kGray9C,
                        coachName: 'Coach\nMaria',
                        description:
                            'Master the core lifts and build a solid athletic base with our signature strength-building protocol.',
                        stat1Label: 'Workouts', stat1Value: '12', statColor: kCyan,
                        stat2Label: 'Kcal/Wk', stat2Value: '3400', stat2Color: kCyan,
                        stat3Label: 'Intensity', stat3Value: 'High', stat3Color: kCyan,
                        buttonActive: true,
                      ),
                      const SizedBox(height: 24),
                      _buildProgramCard(
                        title: 'HIIT Mastery',
                        levelTag: 'All Levels',
                        levelColor: kCyan,
                        typeTag: 'HIIT',
                        duration: '6 Weeks',
                        durationColor: _kGray9C,
                        coachName: 'Coach Alex',
                        description:
                            'Torch fat and improve metabolic efficiency with high-intensity interval sequences designed for results.',
                        stat1Label: 'Workouts', stat1Value: '18', statColor: kLime,
                        stat2Label: 'Kcal/Wk', stat2Value: '5200', stat2Color: kLime,
                        stat3Label: 'Intensity', stat3Value: 'Extreme', stat3Color: kLime,
                        buttonActive: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Header overlay
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildHeader(),
          ),
          // Bottom nav
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.80),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kDark16,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: const Center(child: Icon(Icons.chevron_left, color: Colors.white, size: 20)),
          ),
          Text('TRAINING PROGRAMS', style: GoogleFonts.spaceGrotesk(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: Colors.white, letterSpacing: -0.5)),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kDark16,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: const Center(child: Icon(Icons.tune, color: Colors.white, size: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final active = _activeFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
              decoration: BoxDecoration(
                color: active ? kLime : _kDark16,
                borderRadius: BorderRadius.circular(9999),
                border: active ? null : Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(_filters[i].toUpperCase(), style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? kBg : _kGray9C, letterSpacing: 1.2)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgramCard({
    required String title,
    required String levelTag,
    required Color levelColor,
    required String typeTag,
    required String duration,
    required Color durationColor,
    required String coachName,
    required String description,
    required String stat1Label,
    required String stat1Value,
    required Color statColor,
    required String stat2Label,
    required String stat2Value,
    required Color stat2Color,
    required String stat3Label,
    required String stat3Value,
    required Color stat3Color,
    required bool buttonActive,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.85, -1),
          end: Alignment(-0.85, 1),
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image area
          Stack(
            children: [
              Container(
                height: 224,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      buttonActive
                          ? const Color(0xFF1A0A00)
                          : const Color(0xFF001A1A),
                      kBg,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    buttonActive ? Icons.fitness_center : Icons.directions_run,
                    color: buttonActive
                        ? kLime.withValues(alpha: 0.15)
                        : kCyan.withValues(alpha: 0.15),
                    size: 80,
                  ),
                ),
              ),
              // Gradient overlay at bottom
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, kBg],
                    ),
                  ),
                ),
              ),
              // Tags
              Positioned(
                top: 16, left: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: levelColor,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(levelTag.toUpperCase(), style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w900,
                        color: kBg, letterSpacing: -0.5)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Text(typeTag.toUpperCase(), style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GoogleFonts.spaceGrotesk(
                            fontSize: 24, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: -0.21, height: 1.25)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFF9CA3AF), size: 10),
                              const SizedBox(width: 8),
                              Text(duration.toUpperCase(), style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: _kGray9C, letterSpacing: 1.2)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _kDark16, width: 2),
                            color: const Color(0xFF3A3C42),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(coachName, style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: _kGray6B, letterSpacing: 1.0), textAlign: TextAlign.right),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(description, style: GoogleFonts.manrope(
                  fontSize: 14, color: _kGray9C, height: 1.625)),
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildStat(stat1Value, stat1Label, statColor),
                    Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.05), margin: const EdgeInsets.symmetric(horizontal: 24)),
                    _buildStat(stat2Value, stat2Label, stat2Color),
                    Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.05), margin: const EdgeInsets.symmetric(horizontal: 24)),
                    _buildStat(stat3Value, stat3Label, stat3Color),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: buttonActive ? kLime : _kDark16,
                      borderRadius: BorderRadius.circular(16),
                      border: buttonActive ? null : Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      boxShadow: buttonActive ? [BoxShadow(
                        color: kLime.withValues(alpha: 0.10),
                        blurRadius: 20, offset: const Offset(0, 8))] : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('START PROGRAM', style: GoogleFonts.manrope(
                          fontSize: 16, fontWeight: FontWeight.w900,
                          color: buttonActive ? kBg : Colors.white,
                          letterSpacing: 1.6)),
                        const SizedBox(width: 8),
                        Icon(Icons.play_arrow,
                          color: buttonActive ? kBg : Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value.toUpperCase(), style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 0.14)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: GoogleFonts.manrope(
          fontSize: 9, fontWeight: FontWeight.w500,
          color: _kGray6B, letterSpacing: 0.13)),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_filled, 'HOME', false),
          _buildNavItem(Icons.search, 'SEARCH', false),
          _buildNavItem(Icons.fitness_center, 'PROGRAMS', true),
          _buildNavItem(Icons.calendar_today, 'SCHEDULE', false),
          _buildProfileNav(),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? kLime : _kGray6B, size: 20),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: active ? kLime : _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }

  Widget _buildProfileNav() {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kDark26),
              color: const Color(0xFF3A3C42),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 14),
          ),
          const SizedBox(height: 6),
          Text('PROFILE', style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}
