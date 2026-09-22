import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Lime top glow (subtle)
          Positioned(
            left: 0, top: 0,
            child: Container(
              width: 375, height: 256,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    kLime.withValues(alpha: 0.08),
                    kLime.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.6],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 28),
                  _buildSectionLabel('TODAY'),
                  const SizedBox(height: 12),
                  _buildNotificationCard(
                    icon: Icons.notifications_outlined,
                    iconBg: const Color(0xFF1D2410),
                    iconBorder: kLime.withValues(alpha: 0.30),
                    iconColor: kLime,
                    title: 'CrossFit starts in 1 hour',
                    subtitle: 'Fitness Club Athens',
                    time: '17:30',
                    unread: true,
                    hasLimeBar: true,
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationCard(
                    icon: Icons.warning_amber_outlined,
                    iconBg: const Color(0xFF2B2110),
                    iconBorder: const Color(0xFFFFB238).withValues(alpha: 0.30),
                    iconColor: const Color(0xFFFFB238),
                    title: 'Membership expires in 5 days',
                    subtitle: 'Urban Fitness · Monthly Unlimited',
                    time: '09:12',
                    unread: true,
                    hasLimeBar: true,
                  ),
                  const SizedBox(height: 28),
                  _buildSectionLabel('EARLIER'),
                  const SizedBox(height: 12),
                  _buildNotificationCard(
                    icon: Icons.check_circle_outline,
                    iconBg: const Color(0xFF1D2410),
                    iconBorder: kLime.withValues(alpha: 0.30),
                    iconColor: kLime,
                    title: 'Booking confirmed',
                    subtitle: 'Yoga · Tomorrow 20:00',
                    time: 'Yesterday',
                    unread: false,
                    hasLimeBar: false,
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationCard(
                    icon: Icons.check_circle_outline,
                    iconBg: const Color(0xFF1D2410),
                    iconBorder: kLime.withValues(alpha: 0.30),
                    iconColor: kLime,
                    title: 'Gym membership approved',
                    subtitle: 'Iron Works Gym',
                    time: '2 days ago',
                    unread: false,
                    hasLimeBar: false,
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationCard(
                    icon: Icons.credit_card_outlined,
                    iconBg: const Color(0xFF1F2024),
                    iconBorder: kBorder2,
                    iconColor: kGray,
                    title: 'Payment successful\n€90.00',
                    subtitle: '10 Class Pack · Fitness Club Athens',
                    time: '3 days ago',
                    unread: false,
                    hasLimeBar: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kCard,
              shape: BoxShape.circle,
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Notifications', style: GoogleFonts.spaceGrotesk(
            fontSize: 20, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.5)),
        ),
        Text('Mark all as read', style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700, color: kLime)),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: GoogleFonts.manrope(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: kGray, letterSpacing: 1.1));
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconBg,
    required Color iconBorder,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required bool unread,
    required bool hasLimeBar,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: iconBorder),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(title, style: GoogleFonts.spaceGrotesk(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Text(time, style: GoogleFonts.manrope(
                                  fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
                                if (unread) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(
                                      color: kLime,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: kLime.withValues(alpha: 0.9), blurRadius: 8),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w400, color: kGray)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Left lime accent bar for unread
            if (hasLimeBar)
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: kLime,
                    boxShadow: [
                      BoxShadow(color: kLime.withValues(alpha: 0.6), blurRadius: 10),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
