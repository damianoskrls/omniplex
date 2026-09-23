import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class MemberHomeV2Screen extends StatefulWidget {
  const MemberHomeV2Screen({super.key, this.userName, this.onTabChange});
  final String? userName;
  final void Function(int)? onTabChange;

  @override
  State<MemberHomeV2Screen> createState() => _MemberHomeV2ScreenState();
}

class _MemberHomeV2ScreenState extends State<MemberHomeV2Screen> {
  int _selectedDay = 1; // Mon = 1 (active)

  static const _kDark = Color(0xFF161616);
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);

  final _days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI'];
  final _dates = ['20', '21', '22', '23', '24', '25'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMyGymSection(),
                    const SizedBox(height: 32),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildThisWeekSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
      color: kBg.withValues(alpha: 0.80),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good morning,', style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w500, color: _kGray9C)),
              const SizedBox(height: 2),
              Text('${widget.userName?.split(' ').first ?? 'there'} 👋', style: GoogleFonts.spaceGrotesk(
                fontSize: 24, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.6)),
            ],
          ),
          Stack(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _kDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBorder26),
                ),
                child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
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

  Widget _buildMyGymSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('MY GYM', style: GoogleFonts.spaceGrotesk(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: kCyan, letterSpacing: 0.9)),
            Text('ACTIVE ACCESS', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: _kGray6B, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 256,
          decoration: BoxDecoration(
            color: _kDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Stack(
            children: [
              // Gym image placeholder
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Opacity(
                    opacity: 0.40,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A3A1A), Color(0xFF0A1A0A)],
                        ),
                      ),
                      child: const Icon(Icons.fitness_center, color: Color(0xFF2A4A2A), size: 80),
                    ),
                  ),
                ),
              ),
              // Bottom gradient
              Positioned(
                left: 0, right: 0, bottom: 0, height: 140,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [kBg, kBg.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fitness Club\nAthens', style: GoogleFonts.spaceGrotesk(
                              fontSize: 24, fontWeight: FontWeight.w800,
                              color: Colors.white, height: 1.0)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kLime.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(color: kLime.withValues(alpha: 0.30)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: kLime, size: 10),
                                  const SizedBox(width: 6),
                                  Text('ACTIVE MEMBERSHIP', style: GoogleFonts.manrope(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: kLime, letterSpacing: 1.0)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: kLime.withValues(alpha: 0.20), blurRadius: 15, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: const Icon(Icons.qr_code_2, color: kBg, size: 28),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VALID UNTIL', style: GoogleFonts.manrope(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: _kGray9C, letterSpacing: -0.5)),
                            Text('Oct 28, 2024', style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: Colors.white)),
                          ],
                        ),
                        Container(
                          width: 1, height: 32, color: Colors.white.withValues(alpha: 0.10),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NEXT SESSION', style: GoogleFonts.manrope(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: _kGray9C, letterSpacing: -0.5)),
                            Text('18:30 CrossFit', style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: kCyan)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.add_circle_outline, 'BOOK'),
      (Icons.layers_outlined, 'PACKAGES'),
      (Icons.restaurant_outlined, 'NUTRITION'),
      (Icons.show_chart, 'PROGRESS'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: a.$2 == 'PROGRESS' ? 0 : 12),
          child: Column(
            children: [
              Container(
                height: 68,
                decoration: BoxDecoration(
                  color: _kDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder26),
                ),
                child: Center(child: Icon(a.$1, color: Colors.white, size: 20)),
              ),
              const SizedBox(height: 8),
              Text(a.$2, style: GoogleFonts.manrope(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _kGray9C, letterSpacing: -0.25)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildThisWeekSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('THIS WEEK', style: GoogleFonts.spaceGrotesk(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: kCyan, letterSpacing: 0.9)),
            const Icon(Icons.tune, color: _kGray6B, size: 16),
          ],
        ),
        const SizedBox(height: 16),
        // Day picker
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final isActive = i == _selectedDay;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = i),
                child: Container(
                  width: 48, height: 64,
                  decoration: BoxDecoration(
                    color: isActive ? kLime : _kDark,
                    borderRadius: BorderRadius.circular(12),
                    border: isActive ? null : Border.all(color: _kBorder26),
                    boxShadow: isActive ? [
                      BoxShadow(color: kLime.withValues(alpha: 0.30), blurRadius: 7.5),
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_days[i], style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: isActive ? kBg.withValues(alpha: 0.70) : _kGray6B,
                        letterSpacing: 0.3)),
                      Text(_dates[i], style: GoogleFonts.manrope(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: isActive ? kBg : Colors.white)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Class cards
        _buildClassCard(
          time: '18:30', duration: '60 MIN', title: 'CrossFit Intermediate',
          location: 'Fitness Club Athens', accentColor: kLime,
          trailing: _buildAvatarStack(),
        ),
        const SizedBox(height: 16),
        Opacity(
          opacity: 0.70,
          child: _buildClassCard(
            time: '20:00', duration: '45 MIN', title: 'Yoga Flow',
            location: 'Zen Studio Hub', accentColor: _kBorder26,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('WAITLIST', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 0.5)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildClassCard({
    required String time,
    required String duration,
    required String title,
    required String location,
    required Color accentColor,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
          top: BorderSide(color: _kBorder26),
          right: BorderSide(color: _kBorder26),
          bottom: BorderSide(color: _kBorder26),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(time, style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(duration, style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kGray6B, letterSpacing: 0.2)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: _kGray9C, size: 9),
                    const SizedBox(width: 4),
                    Text(location, style: GoogleFonts.manrope(
                      fontSize: 12, color: _kGray9C)),
                  ],
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    return Row(
      children: [
        for (int i = 0; i < 2; i++)
          Transform.translate(
            offset: Offset(i * -8.0, 0),
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kDark, width: 2),
                color: const Color(0xFF3A3C42),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 12),
            ),
          ),
        Transform.translate(
          offset: const Offset(-16, 0),
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kDark, width: 2),
              color: const Color(0xFF262626),
            ),
            child: Center(
              child: Text('+12', style: GoogleFonts.manrope(
                fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

}
