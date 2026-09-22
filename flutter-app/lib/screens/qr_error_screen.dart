import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kRed = Color(0xFFFF5A4E);
const _kOrange = Color(0xFFF5A623);

class QrErrorScreen extends StatelessWidget {
  const QrErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Red radial glow
          Positioned(
            left: 0, top: 100,
            child: Container(
              width: 375, height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.55,
                  colors: [
                    _kRed.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                children: [
                  _buildTopBar(context),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildErrorIcon(),
                          const SizedBox(height: 28),
                          Text('Access unavailable', style: GoogleFonts.spaceGrotesk(
                            fontSize: 30, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.75),
                            textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('Your membership has expired.',
                            style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: kGray),
                            textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          _buildExpiredCard(),
                          const SizedBox(height: 16),
                          _buildActionButtons(),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => Navigator.maybePop(context),
                            child: Text('Close', style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: kGray,
                              decoration: TextDecoration.underline,
                              decorationColor: kGray)),
                          ),
                          const SizedBox(height: 32),
                          _buildDivider(),
                          const SizedBox(height: 20),
                          _buildWrongGymCard(context),
                        ],
                      ),
                    ),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2024),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.bolt, color: kLime, size: 14),
            ),
            const SizedBox(width: 8),
            Text('OMNIPLEX', style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 1.4)),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2024),
              shape: BoxShape.circle,
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorIcon() {
    return SizedBox(
      width: 176, height: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 176, height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kRed.withValues(alpha: 0.20)),
            ),
          ),
          // Middle ring
          Container(
            width: 132, height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kRed.withValues(alpha: 0.30)),
            ),
          ),
          // Glow bg
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _kRed.withValues(alpha: 0.35),
                  _kRed.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 0.75],
              ),
            ),
          ),
          // Core circle
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFF2A1512),
              shape: BoxShape.circle,
              border: Border.all(color: _kRed, width: 2),
              boxShadow: [
                BoxShadow(color: _kRed.withValues(alpha: 0.55), blurRadius: 30, spreadRadius: 6),
                BoxShadow(color: _kRed.withValues(alpha: 0.25), blurRadius: 60, spreadRadius: 12),
              ],
            ),
            child: const Icon(Icons.warning_amber_rounded, color: _kRed, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A1512),
              shape: BoxShape.circle,
              border: Border.all(color: _kRed),
            ),
            child: const Icon(Icons.calendar_today_outlined, color: _kRed, size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fitness Club Athens', style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('Membership expired on Oct 15', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: _kRed, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.credit_card_outlined, color: _kRed, size: 18),
              const SizedBox(width: 8),
              Text('View Membership', style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w700, color: _kRed)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: kBorder2, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Book a Class', style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: kBorder, thickness: 1)),
        const SizedBox(width: 12),
        Text('OTHER SCENARIO', style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: kDim, letterSpacing: 1.2)),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: kBorder, thickness: 1)),
      ],
    );
  }

  Widget _buildWrongGymCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kOrange.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2210),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kOrange),
                ),
                child: const Icon(Icons.location_off_outlined, color: _kOrange, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wrong gym detected', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('This QR belongs to another gym', style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2024),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, color: kGray, size: 14),
                const SizedBox(width: 8),
                Text('Urban Fitness', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Center(
                    child: Text('Switch Gym', style: GoogleFonts.spaceGrotesk(
                      fontSize: 14, fontWeight: FontWeight.w700, color: kBg)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: kBorder2, width: 2),
                    ),
                    child: Center(
                      child: Text('Cancel', style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
