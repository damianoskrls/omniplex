import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kOrange = Color(0xFFFFA53E);
const _kOrangeBg = Color(0xFF2B1D0E);
const _kCyanBg = Color(0xFF0F2429);

class StaffAvailabilityScreen extends StatefulWidget {
  const StaffAvailabilityScreen({super.key});

  @override
  State<StaffAvailabilityScreen> createState() => _StaffAvailabilityScreenState();
}

class _StaffAvailabilityScreenState extends State<StaffAvailabilityScreen> {
  bool _availableForNew = true;

  final _days = [
    ('M', 'Monday', '08:00 - 17:00', true),
    ('T', 'Tuesday', '08:00 - 17:00', true),
    ('W', 'Wednesday', '08:00 - 17:00', true),
    ('T', 'Thursday', '08:00 - 17:00', true),
    ('F', 'Friday', '08:00 - 15:00', true),
    ('S', 'Saturday', '', false),
    ('S', 'Sunday', '', false),
  ];

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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with back button
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
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
                              Text('My Availability', style: GoogleFonts.spaceGrotesk(
                                fontSize: 20, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: -0.5)),
                            ],
                          ),
                        ),
                        // Workplace bar
                        Container(
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1D2410),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kLime.withValues(alpha: 0.30)),
                                    ),
                                    child: const Icon(Icons.fitness_center, color: kLime, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Fitness Club Athens', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                              const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
                            ],
                          ),
                        ),
                        // Working Days section
                        _buildSectionHeader('Working Days', '5 days active'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _days.map((d) => _buildDayCircle(d.$1, d.$4)).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Working Hours section
                        _buildSectionHeader('Working Hours', null),
                        const SizedBox(height: 12),
                        Column(
                          children: _days.where((d) => d.$4).map((d) =>
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildHoursRow(d.$1, d.$2, d.$3),
                            )
                          ).toList(),
                        ),
                        const SizedBox(height: 12),
                        // Breaks section
                        _buildSectionHeader('Breaks', null),
                        const SizedBox(height: 12),
                        _buildBreakRow(),
                        const SizedBox(height: 12),
                        // Add Break button (dashed)
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorder2, style: BorderStyle.solid),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add, color: kLime, size: 14),
                              const SizedBox(width: 8),
                              Text('Add Break', style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w700, color: kLime)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Location section
                        _buildSectionHeader('Location', null),
                        const SizedBox(height: 12),
                        _buildLocationRow(),
                        const SizedBox(height: 12),
                        // Available toggle row
                        Container(
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
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1D2410),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kLime.withValues(alpha: 0.30)),
                                    ),
                                    child: const Icon(Icons.event_available_outlined, color: kLime, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Available for new\nappointments', style: GoogleFonts.manrope(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _availableForNew = !_availableForNew),
                                child: Container(
                                  width: 48, height: 28,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _availableForNew ? kLime : kBorder2,
                                    borderRadius: BorderRadius.circular(9999),
                                    boxShadow: _availableForNew ? [
                                      BoxShadow(color: kLime.withValues(alpha: 0.40), blurRadius: 5),
                                    ] : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: _availableForNew
                                      ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20, height: 20,
                                        decoration: const BoxDecoration(
                                          color: kBg,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Save Changes button
                Container(
                  decoration: const BoxDecoration(
                    color: kBg,
                    border: Border(top: BorderSide(color: kBorder)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: kLime,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 10),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, color: kBg, size: 16),
                        const SizedBox(width: 8),
                        Text('Save Changes', style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: kBg, letterSpacing: -0.35)),
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

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.4)),
          if (subtitle != null)
            Text(subtitle, style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
        ],
      ),
    );
  }

  Widget _buildDayCircle(String letter, bool active) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: active ? kLime : null,
        shape: BoxShape.circle,
        border: active ? null : Border.all(color: kBorder2),
        boxShadow: active ? [
          BoxShadow(color: kLime.withValues(alpha: 0.50), blurRadius: 6),
        ] : null,
      ),
      child: Center(
        child: Text(letter, style: active
          ? GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: kBg)
          : GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: kGray)),
      ),
    );
  }

  Widget _buildHoursRow(String letter, String day, String hours) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2410),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kLime.withValues(alpha: 0.30)),
                ),
                child: Center(
                  child: Text(letter, style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w700, color: kLime)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(day, style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(hours, style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                ],
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: kGray, size: 16),
        ],
      ),
    );
  }

  Widget _buildBreakRow() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kOrangeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.30)),
                ),
                child: const Icon(Icons.coffee_outlined, color: _kOrange, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Lunch Break', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('12:00 - 13:00', style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                ],
              ),
            ],
          ),
          const Icon(Icons.chevron_right, color: kGray, size: 16),
        ],
      ),
    );
  }

  Widget _buildLocationRow() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kCyanBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCyan.withValues(alpha: 0.30)),
                ),
                child: const Icon(Icons.location_on_outlined, color: kCyan, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Fitness Club Athens', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Main Location', style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
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
