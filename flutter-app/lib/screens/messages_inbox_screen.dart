import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class MessagesInboxScreen extends StatelessWidget {
  const MessagesInboxScreen({super.key});

  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray4B = Color(0xFF4B5563);
  static const _kDark16 = Color(0xFF161616);
  static const _kDark1C = Color(0xFF1C1C1C);

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
                      _buildConversation(
                        name: 'Trainer Maria',
                        message: 'How was your workout today?',
                        time: 'JUST NOW',
                        tag: 'PERSONAL TRAINER',
                        tagColor: kLime,
                        tagBg: kLime.withValues(alpha: 0.10),
                        tagBorder: kLime.withValues(alpha: 0.20),
                        timeColor: kLime,
                        isActive: true,
                        hasUnread: true,
                        avatarChild: _buildPhotoAvatar(isActive: true),
                      ),
                      const SizedBox(height: 12),
                      _buildConversation(
                        name: 'Coach Alex',
                        message: 'See you at 18:30 for PT.',
                        time: '2H AGO',
                        tag: 'CROSSFIT COACH',
                        tagColor: kCyan,
                        tagBg: kCyan.withValues(alpha: 0.10),
                        tagBorder: kCyan.withValues(alpha: 0.20),
                        timeColor: _kGray6B,
                        isActive: false,
                        hasUnread: false,
                        avatarChild: _buildGrayAvatar(icon: Icons.person, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildConversation(
                        name: 'Gym Admin',
                        message: 'Your membership has been renewed.',
                        time: 'YESTERDAY',
                        tag: 'SYSTEM',
                        tagColor: _kGray6B,
                        tagBg: _kGray6B.withValues(alpha: 0.10),
                        tagBorder: Colors.white.withValues(alpha: 0.10),
                        timeColor: _kGray6B,
                        isActive: false,
                        hasUnread: false,
                        avatarChild: _buildIconAvatar(Icons.shield_outlined, const Color(0xFF3EE6FF)),
                      ),
                      const SizedBox(height: 12),
                      _buildConversation(
                        name: 'Nutritionist Sarah',
                        message: 'The new meal plan has been uploaded to your profile.',
                        time: 'OCT 19',
                        tag: 'HEALTH',
                        tagColor: kLime,
                        tagBg: kLime.withValues(alpha: 0.10),
                        tagBorder: kLime.withValues(alpha: 0.20),
                        timeColor: _kGray6B,
                        isActive: false,
                        hasUnread: false,
                        avatarChild: _buildGrayAvatar(icon: Icons.person, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildConversation(
                        name: 'Zen Studio Athens',
                        message: 'You\'ve been moved from the waitlist to "Yoga Flow".',
                        time: 'OCT 18',
                        tag: 'NOTIFICATION',
                        tagColor: kCyan,
                        tagBg: kCyan.withValues(alpha: 0.10),
                        tagBorder: kCyan.withValues(alpha: 0.20),
                        timeColor: _kGray6B,
                        isActive: false,
                        hasUnread: false,
                        avatarChild: _buildIconAvatar(Icons.help_outline, kCyan),
                      ),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kDark16,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder26),
                ),
                child: const Center(child: Icon(Icons.chevron_left, color: Colors.white, size: 20)),
              ),
              const SizedBox(width: 16),
              Text('MESSAGES', style: GoogleFonts.spaceGrotesk(
                fontSize: 24, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.6)),
              const Spacer(),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kDark16,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder26),
                ),
                child: const Center(child: Icon(Icons.edit_outlined, color: Colors.white, size: 16)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: _kDark16,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder26),
            ),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Text('Search conversations...', style: GoogleFonts.manrope(
                  fontSize: 14, color: _kGray4B)),
              ],
            ),
          ),
          // Search icon overlay handled inline
        ],
      ),
    );
  }

  Widget _buildConversation({
    required String name,
    required String message,
    required String time,
    required String tag,
    required Color tagColor,
    required Color tagBg,
    required Color tagBorder,
    required Color timeColor,
    required bool isActive,
    required bool hasUnread,
    required Widget avatarChild,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? kLime.withValues(alpha: 0.05) : _kDark1C.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? kLime.withValues(alpha: 0.30) : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: isActive ? [BoxShadow(
          color: kLime.withValues(alpha: 0.15),
          blurRadius: 15,
        )] : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatarChild,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: GoogleFonts.spaceGrotesk(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : const Color(0xFFD1D5DB))),
                    Text(time, style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: timeColor, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message,
                  style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? Colors.white : _kGray6B),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tagBorder),
                  ),
                  child: Text(tag, style: GoogleFonts.manrope(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: tagColor, letterSpacing: 0.9)),
                ),
              ],
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(width: 12),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: kLime,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.50), blurRadius: 6)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoAvatar({required bool isActive}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF3A2E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? kLime.withValues(alpha: 0.30) : Colors.transparent),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: const Icon(Icons.person, color: Color(0xFFD4A06A), size: 32),
          ),
        ),
        if (isActive)
          Positioned(
            bottom: -3, right: -4,
            child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: kLime,
                shape: BoxShape.circle,
                border: Border.all(color: kBg, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrayAvatar({required IconData icon, required Color color}) {
    return Opacity(
      opacity: 0.80,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildIconAvatar(IconData icon, Color color) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: _kBorder26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Icon(icon, color: color, size: 22),
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
          _buildNavItem(Icons.home_filled, 'HOME', false),
          _buildNavItem(Icons.search, 'SEARCH', false),
          _buildNavItem(Icons.calendar_today, 'SCHEDULE', false),
          _buildNavItem(Icons.fitness_center_outlined, 'MY GYMS', false),
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
      width: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kLime),
              color: const Color(0xFF3A2E1E),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 14),
          ),
          const SizedBox(height: 4),
          Text('PROFILE', style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: kLime, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}
