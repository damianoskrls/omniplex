import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kRed = Color(0xFFFF5C5C);

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key,
    this.name = 'Damianos Karalis',
    this.email = 'damianos.k@email.com',
    this.phone = '+30 694 123 4567',
  });

  final String name;
  final String email;
  final String phone;

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
          // Cyan bottom-right glow
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
                        _buildTopBar(),
                        const SizedBox(height: 28),
                        _buildProfileHeader(),
                        const SizedBox(height: 28),
                        _buildSection('ACCOUNT', [
                          (Icons.person_outline, 'Personal Information'),
                          (Icons.fitness_center_outlined, 'My Memberships'),
                          (Icons.credit_card_outlined, 'Payment Methods'),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('PREFERENCES', [
                          (Icons.notifications_outlined, 'Notifications'),
                          (Icons.lock_outline, 'Security'),
                          (Icons.shield_outlined, 'Privacy'),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('SUPPORT', [
                          (Icons.help_outline, 'Help & Support'),
                        ]),
                        const SizedBox(height: 24),
                        _buildLogoutButton(),
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

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Profile', style: GoogleFonts.spaceGrotesk(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.6)),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kBorder2),
          ),
          child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Avatar
        Stack(
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2B30),
                shape: BoxShape.circle,
                border: Border.all(color: kBorder2, width: 2),
              ),
              child: const Icon(Icons.person, color: kGray, size: 44),
            ),
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: kLime,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBg, width: 3),
                  boxShadow: [
                    BoxShadow(color: kLime.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
                child: const Icon(Icons.camera_alt, color: kBg, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(name, style: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(email, style: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w500, color: kGray)),
        const SizedBox(height: 2),
        Text(phone, style: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w500, color: kGray)),
        const SizedBox(height: 16),
        // Badges row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kLime,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: [
                  BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 7),
                ],
              ),
              child: Center(
                child: Text('MEMBER', style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: kBg, letterSpacing: 0.25)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: kBorder2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: kGray, size: 12),
                  const SizedBox(width: 6),
                  Text('Add Staff Role', style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kGray, letterSpacing: 0.25)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String label, List<(IconData, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(label, style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: kGray, letterSpacing: 0.3)),
        ),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isLast = i == items.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2024),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBorder),
                          ),
                          child: Icon(item.$1, color: kGray, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item.$2, style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        const Icon(Icons.chevron_right, color: kGray, size: 14),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(color: kBorder, thickness: 1, height: 1),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A1414),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kRed),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout, color: _kRed, size: 16),
          const SizedBox(width: 8),
          Text('Logout', style: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: _kRed, letterSpacing: 0.35)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_outlined, 'Home', false),
      (Icons.search, 'Search', false),
      (Icons.calendar_today_outlined, 'Schedule', false),
      (Icons.fitness_center_outlined, 'My Gyms', false),
      (Icons.person_outline, 'Profile', true),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          final active = item.$3;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              active
                ? Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: kLime.withValues(alpha: 0.5), blurRadius: 12),
                      ],
                    ),
                    child: Icon(item.$1, color: kLime, size: 20),
                  )
                : Icon(item.$1, color: kDim, size: 20),
              const SizedBox(height: 6),
              Text(item.$2,
                style: active
                  ? GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: kLime)
                  : GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: kDim)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
