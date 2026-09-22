import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kOrange = Color(0xFFFFA53E);
const _kOrangeBg = Color(0xFF2B1D0E);

class StaffWorkplacesScreen extends StatelessWidget {
  const StaffWorkplacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Top lime glow
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
                  stops: const [0.0, 0.35, 0.60],
                ),
              ),
            ),
          ),
          // Bottom-right purple glow
          Positioned(
            right: 0, top: 384,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB57BFF).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.70],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: kCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: kBorder),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 16),
                        Text('My Workplaces', style: GoogleFonts.spaceGrotesk(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                  // Section label
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('WHERE YOU WORK', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: kGray, letterSpacing: 0.3)),
                  ),
                  // Workplace list
                  Column(
                    children: [
                      _buildActiveWorkplace(
                        name: 'Fitness Club Athens',
                        role: 'CrossFit Coach',
                        since: 'Since Jan 2023',
                        icon: Icons.fitness_center,
                        iconBg: const Color(0xFF1F2024),
                        iconBorderColor: kBorder2,
                        iconColor: kGray,
                      ),
                      const SizedBox(height: 12),
                      _buildActiveWorkplace(
                        name: 'Urban Fitness',
                        role: 'Personal Trainer',
                        since: 'Since Mar 2024',
                        icon: Icons.favorite_border,
                        iconBg: const Color(0xFF1F2024),
                        iconBorderColor: kBorder2,
                        iconColor: kGray,
                      ),
                      const SizedBox(height: 12),
                      _buildPendingWorkplace(),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Add Workplace button
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kLime, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: kLime, size: 16),
                        const SizedBox(width: 8),
                        Text('Add Workplace', style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: kLime, letterSpacing: -0.35)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Find a Workplace section
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('Find a Workplace', style: GoogleFonts.spaceGrotesk(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.4)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      children: [
                        // Search field
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2024),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: kDim, size: 18),
                              const SizedBox(width: 12),
                              Text('Search gym', style: GoogleFonts.manrope(
                                fontSize: 14, fontWeight: FontWeight.w600, color: kDim)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Search result
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2024),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: kCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kBorder2),
                                    ),
                                    child: const Icon(Icons.location_city_outlined, color: kGray, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 80,
                                    child: Text('CrossFit Box Piraeus', style: GoogleFonts.manrope(
                                      fontSize: 14, fontWeight: FontWeight.w700,
                                      color: Colors.white, height: 1.43)),
                                  ),
                                ],
                              ),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: kLime,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text('Request to Join', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: kBg, letterSpacing: -0.35)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Info note
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.info_outline, color: kDim, size: 12),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Admin approval required to join a new workplace.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: kDim),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildActiveWorkplace({
    required String name,
    required String role,
    required String since,
    required IconData icon,
    required Color iconBg,
    required Color iconBorderColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconBorderColor),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(role, style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D2410),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: kLime.withValues(alpha: 0.40)),
                    ),
                    child: Text('ACTIVE', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: kLime, letterSpacing: 0.25)),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.chevron_right, color: kGray, size: 16),
              const SizedBox(height: 11),
              Text(since, style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w600, color: kDim)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingWorkplace() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kOrange.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _kOrangeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.30)),
                ),
                child: const Icon(Icons.self_improvement_outlined, color: _kOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Iron Works Gym', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Yoga Instructor', style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kOrangeBg,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: _kOrange.withValues(alpha: 0.50)),
                    ),
                    child: Text('PENDING APPROVAL', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _kOrange, letterSpacing: 0.25)),
                  ),
                  const SizedBox(height: 4),
                  Text('Waiting for admin approval', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w600, color: kDim)),
                ],
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: kGray, size: 16),
        ],
      ),
    );
  }
}
