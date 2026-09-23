import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class TrialOutcomeScreen extends StatefulWidget {
  const TrialOutcomeScreen({super.key});

  @override
  State<TrialOutcomeScreen> createState() => _TrialOutcomeScreenState();
}

class _TrialOutcomeScreenState extends State<TrialOutcomeScreen> {
  static const _kDark14 = Color(0xFF141414);
  static const _kDark1F = Color(0xFF1F1F1F);
  static const _kDark27 = Color(0xFF27272A);
  static const _kDark3F = Color(0xFF3F3F46);
  static const _kGrayA1 = Color(0xFFA1A1AA);
  static const _kGray71 = Color(0xFF71717A);
  static const _kGrayD4 = Color(0xFFD4D4D8);

  int _selectedInterest = 0; // 0=Converted, 1=Very Interested, 2=Interested, 3=Thinking, 4=Not Interested
  int _selectedFollowup = 0; // 0=Tomorrow, 1=3d

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              children: [
                // ── Trial Outcome section ──
                _buildOutcomeSection(),
                // ── Divider ──
                Container(height: 4, color: const Color(0xFF18181B)),
                // ── Admin Gym Overview ──
                _buildGymOverviewSection(),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  // ─────────────────── TRIAL OUTCOME ───────────────────

  Widget _buildOutcomeSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          _buildOutcomeHeader(),
          _buildSessionSummaryCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMembershipInterest(),
                const SizedBox(height: 32),
                _buildFollowupAction(),
                const SizedBox(height: 32),
                _buildSessionNotes(),
                const SizedBox(height: 32),
                _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kDark14,
              shape: BoxShape.circle,
              border: Border.all(color: _kDark1F),
            ),
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POST-SESSION REPORT', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: kCyan, letterSpacing: 1.0)),
              Text('Trial Outcome', style: GoogleFonts.spaceGrotesk(
                fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDark1F),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 56,
            decoration: BoxDecoration(
              color: _kDark1F,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kDark3F),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sarah Jenkins', style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Yoga Trial • Oct 24, 14:30', style: GoogleFonts.manrope(
                  fontSize: 14, color: _kGray71)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('DURATION', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: kLime, letterSpacing: 0.09)),
              Text('62m', style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 0.47)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipInterest() {
    final options = [
      'Converted (Signed Up)',
      'Very Interested',
      'Interested',
      'Thinking About It',
      'Not Interested',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MEMBERSHIP INTEREST', style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _kGray71, letterSpacing: 1.0)),
        const SizedBox(height: 16),
        ...List.generate(options.length, (i) {
          final selected = _selectedInterest == i;
          final disabled = i == 4;
          return Opacity(
            opacity: disabled ? 0.50 : 1.0,
            child: GestureDetector(
              onTap: disabled ? null : () => setState(() => _selectedInterest = i),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kDark14,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kDark1F),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(options[i], style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: disabled ? _kGrayA1 : Colors.white)),
                    selected
                        ? Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              color: kLime, shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: kBg, size: 14),
                          )
                        : Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF52525B)),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFollowupAction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FOLLOW-UP ACTION', style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _kGray71, letterSpacing: 1.0)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _selectedFollowup = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _kDark14,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFollowup == 0
                        ? kCyan.withValues(alpha: 0.50)
                        : _kDark1F),
                ),
                child: Text('Contact\nTomorrow',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _selectedFollowup == 0 ? kCyan : _kGrayA1)),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _selectedFollowup = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _kDark14,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFollowup == 1
                        ? kCyan.withValues(alpha: 0.50)
                        : _kDark1F),
                ),
                child: Text('Follow-up in 3d',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _selectedFollowup == 1 ? kCyan : _kGrayA1)),
              ),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SESSION NOTES', style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _kGray71, letterSpacing: 1.0)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          decoration: BoxDecoration(
            color: _kDark14,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kDark1F),
          ),
          child: Text(
            'Sarah was very receptive to the balance work. She mentioned being interested in the unlimited yoga & sauna package. Needs a custom quote for corporate membership...',
            style: GoogleFonts.manrope(fontSize: 14, color: _kGrayD4, height: 1.5)),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: kLime,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: kLime.withValues(alpha: 0.20),
          blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: Center(
        child: Text('SAVE TRIAL OUTCOME', style: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: kBg, letterSpacing: 1.8)),
      ),
    );
  }

  // ─────────────────── GYM OVERVIEW ───────────────────

  Widget _buildGymOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGymOverviewHeader(),
        const SizedBox(height: 24),
        _buildGymStatCards(),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAllTrialsHeader(),
              const SizedBox(height: 16),
              _buildFilterChips(),
              const SizedBox(height: 24),
              _buildAllTrialCards(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGymOverviewHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OMNIPLEX ADMIN', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: kLime, letterSpacing: 1.0)),
              Text('Gym Overview', style: GoogleFonts.spaceGrotesk(
                fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kDark14,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kDark1F),
                ),
                child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kCyan, width: 2),
                  color: _kDark27,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGymStatCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildGymStat('TRIALS TODAY', '24', Colors.white, _kGray71, null),
          const SizedBox(width: 12),
          _buildGymStat('UNASSIGNED', '03', Colors.white, kCyan, kCyan.withValues(alpha: 0.30)),
          const SizedBox(width: 12),
          _buildGymStat('CONVERTED', '08', Colors.white, kLime, kLime.withValues(alpha: 0.30)),
        ],
      ),
    );
  }

  Widget _buildGymStat(String label, String value, Color valueColor, Color labelColor, Color? borderColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kDark14,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? _kDark1F),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.manrope(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: labelColor, letterSpacing: -0.23), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.spaceGrotesk(
              fontSize: 24, fontWeight: FontWeight.w700,
              color: valueColor), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTrialsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('ALL TRIALS', style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _kGray71, letterSpacing: 1.0)),
        Row(
          children: [
            const Icon(Icons.tune, color: kCyan, size: 12),
            const SizedBox(width: 8),
            Text('Filters', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700, color: kCyan)),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final chips = ['Date: Today', 'Trainer: All', 'Status'];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _kDark27,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(chips[i], style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllTrialCards() {
    return Column(
      children: [
        _buildTrialListCard(
          name: 'Marcus Chen',
          sub: 'HIIT Trial • 16:00',
          badgeText: 'Converted',
          badgeColor: kLime,
          badgeBg: kLime.withValues(alpha: 0.10),
          trainerName: 'Alex R.',
          timeText: 'Just now',
          borderColor: _kDark1F,
          showAssignButton: false,
        ),
        const SizedBox(height: 16),
        _buildTrialListCard(
          name: 'Elena Rodriguez',
          sub: 'Boxing Trial • 17:30',
          badgeText: 'Thinking',
          badgeColor: _kGrayA1,
          badgeBg: _kDark27,
          trainerName: 'Jordan M.',
          timeText: '2h ago',
          borderColor: _kDark1F,
          showAssignButton: false,
        ),
        const SizedBox(height: 16),
        _buildTrialListCard(
          name: 'James Wilson',
          sub: 'Strength • 19:00',
          badgeText: 'Pending',
          badgeColor: kCyan,
          badgeBg: kCyan.withValues(alpha: 0.20),
          trainerName: null,
          timeText: null,
          borderColor: kCyan.withValues(alpha: 0.20),
          showAssignButton: true,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTrialListCard({
    required String name,
    required String sub,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required String? trainerName,
    required String? timeText,
    required Color borderColor,
    required bool showAssignButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDark14,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
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
                      shape: BoxShape.circle,
                      color: _kDark27,
                      border: Border.all(color: _kDark3F),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(sub, style: GoogleFonts.manrope(
                        fontSize: 10, color: _kGray71)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 7),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(badgeText.toUpperCase(), style: GoogleFonts.manrope(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: badgeColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: _kDark27, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: trainerName != null ? _kDark27 : _kDark27,
                    ),
                    child: Icon(
                      trainerName != null ? Icons.person : Icons.person_off_outlined,
                      color: Colors.white, size: 12),
                  ),
                  const SizedBox(width: 8),
                  trainerName != null
                      ? RichText(text: TextSpan(children: [
                          TextSpan(text: 'Trainer: ', style: GoogleFonts.manrope(
                            fontSize: 10, color: _kGrayA1)),
                          TextSpan(text: trainerName, style: GoogleFonts.manrope(
                            fontSize: 10, color: Colors.white)),
                        ]))
                      : Text('Unassigned', style: GoogleFonts.manrope(
                          fontSize: 10, color: _kGray71,
                          fontStyle: FontStyle.italic)),
                ],
              ),
              if (showAssignButton)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: kCyan,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('ASSIGN', style: GoogleFonts.manrope(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: kBg, letterSpacing: -0.45)),
                )
              else if (timeText != null)
                Text(timeText, style: GoogleFonts.manrope(
                  fontSize: 10, color: _kGray71)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────── BOTTOM NAV ───────────────────

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F).withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.sports_martial_arts, 'Trials', false),
          _buildNavItem(Icons.group_outlined, 'Leads', false),
          _buildNavFab(),
          _buildNavItem(Icons.admin_panel_settings_outlined, 'Admin', true),
          _buildNavItem(Icons.settings_outlined, 'Settings', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? kCyan : const Color(0xFF71717A), size: 20),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: active ? kCyan : const Color(0xFF71717A))),
      ],
    );
  }

  Widget _buildNavFab() {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: kLime,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
          color: kLime.withValues(alpha: 0.40),
          blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: const Icon(Icons.add, color: kBg, size: 24),
    );
  }
}
