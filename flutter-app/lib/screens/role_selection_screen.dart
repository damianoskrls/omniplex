import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

enum OmniRole { member, staff }

class RoleSelectionScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const RoleSelectionScreen({super.key, this.onDone});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  OmniRole _selected = OmniRole.member;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: OmniBgPainter(cyanOffset: Offset(359, 240))),
          const OmniCornerBrackets(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OmniTopNav(onBack: () => Navigator.maybePop(context)),
                  const SizedBox(height: 32),
                  _buildProgressBar(),
                  const SizedBox(height: 32),
                  _buildHeading(),
                  const SizedBox(height: 32),
                  _buildRoleCard(
                    role: OmniRole.member,
                    icon: Icons.fitness_center,
                    title: 'Member',
                    description: 'Discover gyms, book classes\nand manage memberships.',
                  ),
                  const SizedBox(height: 20),
                  _buildRoleCard(
                    role: OmniRole.staff,
                    icon: Icons.calendar_month_outlined,
                    title: 'Staff',
                    description: 'Manage classes, appointments\nand your work schedule.',
                  ),
                  const SizedBox(height: 32),
                  _buildInfoBox(),
                  const Spacer(),
                  OmniLimeButton(
                    label: 'Continue',
                    onTap: () => widget.onDone?.call(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: kLime,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How will you use\nOmniPlex?', style: GoogleFonts.spaceGrotesk(
          fontSize: 30, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.75, height: 1.25)),
        const SizedBox(height: 10),
        Text('You can add another role anytime from your profile.',
          style: GoogleFonts.manrope(fontSize: 14, color: kGray, height: 1.625)),
      ],
    );
  }

  Widget _buildRoleCard({
    required OmniRole role,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final active = _selected == role;
    return GestureDetector(
      onTap: () => setState(() => _selected = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? kLime : kBorder),
          boxShadow: active ? [
            BoxShadow(color: kLime.withValues(alpha: 0.15), blurRadius: 30),
            BoxShadow(color: kLime.withValues(alpha: 0.20), blurRadius: 0, spreadRadius: 3),
          ] : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF1D2410)
                    : kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active
                      ? kLime.withValues(alpha: 0.3)
                      : kBorder2,
                ),
              ),
              child: Icon(icon,
                color: active ? kLime : kGray, size: 28),
            ),
            const SizedBox(width: 20),
            // Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: GoogleFonts.spaceGrotesk(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: -0.5)),
                        if (active)
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: kLime,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: kLime.withValues(alpha: 0.55), blurRadius: 7),
                              ],
                            ),
                            child: const Icon(Icons.arrow_forward, color: kBg, size: 14),
                          )
                        else
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kBorder2, width: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(description, style: GoogleFonts.manrope(
                      fontSize: 14, color: kGray, height: 1.625)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: kDim, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your role determines your default dashboard\nand permissions inside OmniPlex.',
              style: GoogleFonts.manrope(fontSize: 12, color: kDim, height: 1.625),
            ),
          ),
        ],
      ),
    );
  }
}
