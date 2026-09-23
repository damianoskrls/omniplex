import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class StaffTrialsScreen extends StatefulWidget {
  const StaffTrialsScreen({super.key});

  @override
  State<StaffTrialsScreen> createState() => _StaffTrialsScreenState();
}

class _StaffTrialsScreenState extends State<StaffTrialsScreen> {
  static const _kDark14 = Color(0xFF141414);
  static const _kDark1F = Color(0xFF1F1F1F);
  static const _kDark27 = Color(0xFF27272A);
  static const _kDark3F = Color(0xFF3F3F46);
  static const _kGrayA1 = Color(0xFFA1A1AA);
  static const _kGray71 = Color(0xFF71717A);
  static const _kGrayD4 = Color(0xFFD4D4D8);

  int _activeFilter = 0;
  final _filters = ['All\nTrials', 'Unassigned', 'My\nTrials'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Dashboard section ──
                _buildDashboardSection(),
                // ── Divider ──
                Container(height: 4, color: const Color(0xFF18181B)),
                // ── Detail section ──
                _buildDetailSection(),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  // ─────────────────── DASHBOARD ───────────────────

  Widget _buildDashboardSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardHeader(),
          const SizedBox(height: 24),
          _buildStatCards(),
          const SizedBox(height: 32),
          _buildFilterPills(),
          const SizedBox(height: 24),
          _buildTrialCards(),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OMNIPLEX STAFF', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: kCyan, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text("Today's Trials", style: GoogleFonts.spaceGrotesk(
                fontSize: 30, fontWeight: FontWeight.w700,
                color: Colors.white)),
            ],
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kLime, width: 2),
                  color: _kDark27,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              Positioned(
                bottom: -4, right: -4,
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildStatCard('TOTAL\nTODAY', '12', Colors.white, _kGray71, null),
          const SizedBox(width: 16),
          _buildStatCard('UNASSIGNED', '04', kCyan, kCyan, null),
          const SizedBox(width: 16),
          _buildStatCard('COMPLETED', '06', Colors.white, _kGray71, null),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color valueColor, Color labelColor, Color? borderColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kDark14,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor ?? const Color(0xFF1F1F1F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: labelColor, letterSpacing: -0.5), maxLines: 2),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.spaceGrotesk(
              fontSize: 24, fontWeight: FontWeight.w700,
              color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPills() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _filters.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final active = _activeFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: active ? kLime : _kDark14,
                borderRadius: BorderRadius.circular(9999),
                border: active ? null : Border.all(color: _kDark1F),
              ),
              child: Text(_filters[i].replaceAll('\n', ' '), style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: active ? kBg : _kGrayA1)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrialCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Card 1 – New Lead (cyan border, Take This Trial)
          _buildTrialCard1(),
          const SizedBox(height: 16),
          // Card 2 – Assigned
          _buildTrialCard2(),
          const SizedBox(height: 16),
          // Card 3 – Your Trial (lime border, Start Session)
          _buildTrialCard3(),
        ],
      ),
    );
  }

  Widget _buildTrialCard1() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kDark14,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kCyan.withValues(alpha: 0.20)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _kDark1F,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kDark3F),
                      ),
                      child: const Icon(Icons.self_improvement, color: kCyan, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('14:30 - 15:30', style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Yoga Trial • Studio B', style: GoogleFonts.manrope(
                          fontSize: 14, color: _kGrayA1)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kDark27,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text('Sarah Jenkins', style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: kCyan,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, color: kBg, size: 14),
                        const SizedBox(width: 8),
                        Text('Take This Trial', style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700, color: kBg)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
              decoration: BoxDecoration(
                color: kCyan.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Text('NEW LEAD', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: kCyan, letterSpacing: 0.18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialCard2() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kDark14,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kDark1F),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _kDark1F,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kDark3F),
                      ),
                      child: const Icon(Icons.directions_run, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('16:00 - 17:00', style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('HIIT Trial • Main Floor', style: GoogleFonts.manrope(
                          fontSize: 14, color: _kGrayA1)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kDark27,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text('Marcus Chen', style: GoogleFonts.manrope(
                          fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kDark1F,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: _kDark1F),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: _kDark27),
                            child: const Icon(Icons.person, color: Colors.white, size: 12),
                          ),
                          const SizedBox(width: 6),
                          Text('Alex R.', style: GoogleFonts.manrope(
                            fontSize: 12, color: _kGrayD4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildOutlineButton('DETAILS'),
                    const SizedBox(width: 12),
                    _buildOutlineButton('CONTACT'),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
              decoration: BoxDecoration(
                color: _kDark27,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Text('ASSIGNED', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _kGrayA1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineButton(String label) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kDark3F),
      ),
      child: Center(
        child: Text(label, style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: 0.6)),
      ),
    );
  }

  Widget _buildTrialCard3() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kDark14,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLime.withValues(alpha: 0.30)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _kDark1F,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kDark3F),
                      ),
                      child: const Icon(Icons.sports_mma, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('17:30 - 18:30', style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Boxing Trial • Combat Zone', style: GoogleFonts.manrope(
                          fontSize: 14, color: _kGrayA1)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kDark27,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text('Elena Rodriguez', style: GoogleFonts.manrope(
                          fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kDark27,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Warm Lead', style: GoogleFonts.manrope(
                        fontSize: 10, color: _kGrayA1)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: kLime.withValues(alpha: 0.20),
                      blurRadius: 15, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: Text('START SESSION', style: GoogleFonts.manrope(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: kBg, letterSpacing: 1.4)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
              decoration: BoxDecoration(
                color: kLime.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Text('YOUR TRIAL', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: kLime)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── DETAIL ───────────────────

  Widget _buildDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero image area
        _buildDetailHero(),
        const SizedBox(height: 64),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailActions(),
              const SizedBox(height: 32),
              _buildTrialInfoGrid(),
              const SizedBox(height: 32),
              _buildAssignedTrainerCard(),
              const SizedBox(height: 32),
              _buildCustomerHistory(),
              const SizedBox(height: 32),
              _buildStartTrialButton(),
              const SizedBox(height: 16),
              Center(
                child: Text('Session timer will start immediately after clicking.',
                  style: GoogleFonts.manrope(fontSize: 12, color: _kGray71)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailHero() {
    return SizedBox(
      height: 288,
      child: Stack(
        children: [
          // Gym image placeholder
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
              ),
            ),
            child: Center(
              child: Icon(Icons.fitness_center,
                color: Colors.white.withValues(alpha: 0.08), size: 120),
            ),
          ),
          // Gradient fade to bottom
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, kBg],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Top bar buttons
          Positioned(
            top: 32, left: 24, right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassButton(Icons.chevron_left),
                _buildGlassButton(Icons.more_vert),
              ],
            ),
          ),
          // Profile card at bottom
          Positioned(
            bottom: -40, left: 24, right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: _kDark1F,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kBg, width: 4),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 48),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sarah Jenkins', style: GoogleFonts.spaceGrotesk(
                        fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('New Lead • Joined 2 days ago', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w600, color: kCyan)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(IconData icon) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F).withValues(alpha: 0.60),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildDetailActions() {
    return Row(
      children: [
        Expanded(child: _buildActionButton(Icons.phone, 'Call')),
        const SizedBox(width: 12),
        Expanded(child: _buildActionButton(Icons.message_outlined, 'Message')),
        const SizedBox(width: 12),
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: _kDark14,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kDark1F),
          ),
          child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _kDark14,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kDark1F),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTrialInfoGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TRIAL INFORMATION', style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _kGray71, letterSpacing: 1.0)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: [
            _buildInfoCell(Icons.self_improvement, 'Activity', 'Yoga Trial'),
            _buildInfoCell(Icons.calendar_today, 'Date', 'Oct 24, 2023'),
            _buildInfoCell(Icons.access_time, 'Time & Duration', '14:30 (60m)'),
            _buildInfoCell(Icons.location_on_outlined, 'Location', 'Studio B'),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCell(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDark14,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDark1F),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 12, color: _kGray71)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildAssignedTrainerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kDark14,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kCyan.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ASSIGNED TRAINER', style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: _kGray71, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kDark27,
                      border: Border.all(color: kCyan),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jordan Miller', style: GoogleFonts.manrope(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('Senior Yoga Specialist', style: GoogleFonts.manrope(
                        fontSize: 12, color: _kGrayA1)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kCyan.withValues(alpha: 0.30)),
                ),
                child: Text('Change', style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kCyan)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CUSTOMER HISTORY', style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _kGray71, letterSpacing: 1.0)),
            Text('VIEW FULL LOG', style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: kLime, letterSpacing: 0.02)),
          ],
        ),
        const SizedBox(height: 16),
        _buildHistoryItem(Icons.notes_outlined, 'Initial Consultation', 'Yesterday • Completed by Admin'),
        const SizedBox(height: 12),
        _buildHistoryItem(Icons.person_add_outlined, 'Profile Created', '2 days ago • via Web Portal'),
      ],
    );
  }

  Widget _buildHistoryItem(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kDark1F),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kDark27,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              Text(sub, style: GoogleFonts.manrope(
                fontSize: 10, color: _kGray71)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartTrialButton() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: kLime,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: kLime.withValues(alpha: 0.20),
          blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_arrow, color: kBg, size: 22),
          const SizedBox(width: 12),
          Text('START TRIAL SESSION', style: GoogleFonts.manrope(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: kBg, letterSpacing: 1.8)),
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
          _buildNavItem(Icons.sports_martial_arts, 'Trials', true),
          _buildNavItem(Icons.group_outlined, 'Leads', false),
          _buildNavFab(),
          _buildNavItem(Icons.bar_chart, 'Stats', false),
          _buildNavItem(Icons.person_outlined, 'Profile', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? kLime : _kGray71, size: 20),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: active ? kLime : _kGray71)),
      ],
    );
  }

  Widget _buildNavFab() {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: kCyan,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
          color: kCyan.withValues(alpha: 0.40),
          blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: const Icon(Icons.add, color: kBg, size: 24),
    );
  }
}
