import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kPurple = Color(0xFFB084FF);
const _kPurpleBg = Color(0xFF1E1830);
const _kCyanBg = Color(0xFF0F2429);

class EmptyStatesScreen extends StatelessWidget {
  const EmptyStatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OMNIPLEX DESIGN SYSTEM', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: kGray, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text('Empty State Reference Sheet', style: GoogleFonts.spaceGrotesk(
                fontSize: 24, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.6)),
              const SizedBox(height: 32),
              _buildVariantLabel('NO GYMS', kLime),
              const SizedBox(height: 12),
              _buildEmptyCard(
                glowColor: kLime,
                iconBg: const Color(0xFF1D2410),
                iconBorder: kLime.withValues(alpha: 0.30),
                icon: Icons.map_outlined,
                iconColor: kLime,
                title: 'Your fitness journey\nstarts here.',
                subtitle: 'Find a gym and add it to My Gyms.',
                buttonLabel: 'Discover Gyms',
                buttonIcon: Icons.explore_outlined,
                buttonPrimary: true,
              ),
              const SizedBox(height: 32),
              _buildVariantLabel('NO BOOKINGS', kCyan),
              const SizedBox(height: 12),
              _buildEmptyCard(
                glowColor: kCyan,
                iconBg: _kCyanBg,
                iconBorder: kCyan.withValues(alpha: 0.30),
                icon: Icons.calendar_month_outlined,
                iconColor: kCyan,
                title: 'Nothing booked yet.',
                subtitle: 'Find a class and reserve your spot.',
                buttonLabel: 'Explore Classes',
                buttonIcon: Icons.fitness_center_outlined,
                buttonPrimary: false,
              ),
              const SizedBox(height: 32),
              _buildVariantLabel('NO MEMBERSHIPS', _kPurple),
              const SizedBox(height: 12),
              _buildEmptyCard(
                glowColor: _kPurple,
                iconBg: _kPurpleBg,
                iconBorder: _kPurple.withValues(alpha: 0.30),
                icon: Icons.card_membership_outlined,
                iconColor: _kPurple,
                title: 'No active memberships',
                subtitle: 'Explore gyms and find a plan that fits you.',
                buttonLabel: 'Discover Gyms',
                buttonIcon: Icons.explore_outlined,
                buttonPrimary: true,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantLabel(String label, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: kGray, letterSpacing: 1.1)),
      ],
    );
  }

  Widget _buildEmptyCard({
    required Color glowColor,
    required Color iconBg,
    required Color iconBorder,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData buttonIcon,
    required bool buttonPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kBorder),
      ),
      child: Container(
        height: 420,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kBorder),
        ),
        child: Stack(
          children: [
            // Top glow
            Positioned(
              left: 0, right: 0, top: 0,
              child: Container(
                height: 256,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.0,
                    colors: [
                      glowColor.withValues(alpha: 0.10),
                      glowColor.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 0.70],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 58),
                // Icon with radial glow
                SizedBox(
                  width: 112, height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 112, height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glowColor.withValues(alpha: 0.22),
                              glowColor.withValues(alpha: 0.05),
                              glowColor.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.55, 0.75],
                          ),
                        ),
                      ),
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: iconBorder),
                        ),
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Heading
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(title, textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.45)),
                ),
                const SizedBox(height: 12),
                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(subtitle, textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14, color: kGray, height: 1.625)),
                ),
                const Spacer(),
                // Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: buttonPrimary ? kLime : null,
                      borderRadius: BorderRadius.circular(12),
                      border: buttonPrimary ? null : Border.all(color: kBorder2),
                      boxShadow: buttonPrimary ? [
                        BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 10),
                      ] : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(buttonIcon,
                          color: buttonPrimary ? kBg : Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(buttonLabel, style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: buttonPrimary ? kBg : Colors.white,
                          letterSpacing: -0.35)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
