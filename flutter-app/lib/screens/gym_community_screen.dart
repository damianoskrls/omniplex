import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class GymCommunityScreen extends StatefulWidget {
  const GymCommunityScreen({super.key});

  @override
  State<GymCommunityScreen> createState() => _GymCommunityScreenState();
}

class _GymCommunityScreenState extends State<GymCommunityScreen> {
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);

  int _activeTab = 0;
  final _tabs = ['Feed', 'Challenges', 'Leaderboard', 'Events'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    children: [
                      _buildTrainerPost(),
                      const SizedBox(height: 24),
                      _buildMemberPost(),
                      const SizedBox(height: 24),
                      _buildTrendingGroups(),
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
    return SafeArea(
      child: Container(
        color: kBg.withValues(alpha: 0.80),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626).withValues(alpha: 0.50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: const Center(child: Icon(Icons.chevron_left, color: Colors.white, size: 20)),
                    ),
                    const SizedBox(width: 16),
                    Text('COMMUNITY', style: GoogleFonts.spaceGrotesk(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.5)),
                  ],
                ),
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: kBg, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Tab bar
            SizedBox(
              height: 26,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tabs.asMap().entries.map((e) {
                    final active = _activeTab == e.key;
                    return GestureDetector(
                      onTap: () => setState(() => _activeTab = e.key),
                      child: Padding(
                        padding: EdgeInsets.only(right: e.key < _tabs.length - 1 ? 32 : 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.value, style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: active ? kLime : _kGray6B,
                              letterSpacing: 1.2)),
                            if (active)
                              Container(
                                width: 4, height: 4,
                                decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle),
                              )
                            else
                              const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerPost() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kLime, width: 2),
                            color: _kBorder26,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 22),
                        ),
                        Positioned(
                          bottom: -4, right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: kLime,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: kBg),
                            ),
                            child: Text('PRO', style: GoogleFonts.manrope(
                              fontSize: 8, fontWeight: FontWeight.w900, color: kBg)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Trainer Maria', style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Head Coach • 2h ago', style: GoogleFonts.manrope(
                          fontSize: 10, color: _kGray9C)),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.more_vert, color: Color(0xFF9CA3AF), size: 18),
              ],
            ),
          ),
          // Post text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFFE5E7EB)),
                children: [
                  const TextSpan(text: 'New '),
                  TextSpan(text: 'HIIT workout', style: GoogleFonts.manrope(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kCyan)),
                  const TextSpan(text: ' uploaded! Check it out in the Programs section. Let\'s push those limits! 🔥💪'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Image
          Container(
            height: 280,
            color: const Color(0xFF0A1A15),
            child: Stack(
              children: [
                const Center(child: Icon(Icons.fitness_center, color: Color(0xFF1A2A20), size: 80)),
                Positioned(
                  left: 16, bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0x66262626), Color(0x99161616)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_outline, color: kLime, size: 18),
                        const SizedBox(width: 8),
                        Text('WATCH PROGRAM', style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Reactions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildReactionBtn(Icons.favorite, '124', kLime),
                    const SizedBox(width: 24),
                    _buildReactionBtn(Icons.chat_bubble_outline, '18', _kGray9C),
                  ],
                ),
                const Icon(Icons.send_outlined, color: Color(0xFF9CA3AF), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberPost() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      color: _kBorder26,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alex Thompson', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('Gold Member • 5h ago', style: GoogleFonts.manrope(
                        fontSize: 10, color: _kGray9C)),
                    ],
                  ),
                ],
              ),
              const Icon(Icons.more_vert, color: Color(0xFF9CA3AF), size: 18),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: GoogleFonts.spaceGrotesk(fontSize: 18, color: Colors.white, height: 1.25),
              children: [
                const TextSpan(text: '"Just hit a new PR on deadlifts! '),
                TextSpan(text: '140kg!', style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, color: kLime)),
                const TextSpan(text: ' 🏋️‍♂️ Athens community, what are you hitting today?"'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTag(Icons.emoji_events_outlined, 'PERSONAL RECORD', kLime.withValues(alpha: 0.20)),
              const SizedBox(width: 8),
              _buildTag(Icons.location_on_outlined, 'MAIN ZONE', Colors.white.withValues(alpha: 0.10)),
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
                  _buildReactionBtn(Icons.favorite_border, '56', _kGray9C),
                  const SizedBox(width: 24),
                  _buildReactionBtn(Icons.chat_bubble_outline, '9', _kGray9C),
                ],
              ),
              const Icon(Icons.send_outlined, color: Color(0xFF9CA3AF), size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionBtn(IconData icon, String count, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(count, style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildTag(IconData icon, String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.25)),
        ],
      ),
    );
  }

  Widget _buildTrendingGroups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text('TRENDING GROUPS', style: GoogleFonts.spaceGrotesk(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: _kGray6B, letterSpacing: 2.4)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildGroupCard(Icons.flash_on, 'MORNING HIIT SQUAD', '1.2k Members', kLime.withValues(alpha: 0.10)),
            const SizedBox(width: 16),
            _buildGroupCard(Icons.fitness_center, 'ELITE POWERLIFTERS', '850 Members', kCyan.withValues(alpha: 0.10)),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupCard(IconData icon, String name, String members, Color iconBg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x66262626), Color(0x99161616)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            Text(name, style: GoogleFonts.manrope(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: Colors.white, height: 1.25)),
            const SizedBox(height: 4),
            Text(members, style: GoogleFonts.manrope(
              fontSize: 9, color: _kGray6B)),
          ],
        ),
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
          _buildNavItem(Icons.calendar_today, 'SCHEDULE', false),
          _buildNavItem(Icons.people_outlined, 'SOCIAL', true),
          _buildProfileNav(),
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

  Widget _buildProfileNav() {
    return SizedBox(
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
    );
  }
}
