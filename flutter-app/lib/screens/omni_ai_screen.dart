import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class OmniAiScreen extends StatefulWidget {
  const OmniAiScreen({super.key});

  @override
  State<OmniAiScreen> createState() => _OmniAiScreenState();
}

class _OmniAiScreenState extends State<OmniAiScreen> {
  static const _kBg05 = Color(0xFF050505);
  static const _kDark1C = Color(0xFF1C1C1C);
  static const _kDark27 = Color(0xFF27272A);
  static const _kDark2A = Color(0xFF2A2A2A);
  static const _kDark111 = Color(0xFF111111);
  static const _kGray71 = Color(0xFF71717A);
  static const _kGrayA1 = Color(0xFFA1A1AA);
  static const _kGrayD4 = Color(0xFFD4D4D8);
  static const _kGrayF4 = Color(0xFFF4F4F5);
  static const _kMint = Color(0xFF00FFC2);
  static const _kPurple = Color(0xFF8B5CF6);

  final _textController = TextEditingController();
  final _staffTextController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    _staffTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg05,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Member / Guest AI chat section ──
            _buildMemberAiSection(),
            // ── Divider ──
            Container(height: 4, color: _kDark2A),
            // ── Staff Operations Mode section ──
            _buildStaffOpsSection(),
          ],
        ),
      ),
    );
  }

  // ─────────────────── MEMBER AI SECTION ───────────────────

  Widget _buildMemberAiSection() {
    return SizedBox(
      height: 1070,
      child: Stack(
        children: [
          // Scrollable chat area
          Positioned(
            top: 88, left: 0, right: 0, bottom: 100,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  // User message (right)
                  _buildUserBubble('Find me a yoga gym near me',
                    const Color(0x1A00FFC2), const Color(0x3300FFC2)),
                  const SizedBox(height: 24),
                  // AI response with gym cards
                  _buildAiResponse(),
                ],
              ),
            ),
          ),
          // Input bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildMemberInputBar(),
          ),
          // Top header
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildMemberHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      color: _kBg05.withValues(alpha: 0.80),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildHeaderBtn(Icons.chevron_left),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: _kMint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('OMNI AI', style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: _kGrayF4, letterSpacing: 1.4)),
            ],
          ),
          _buildHeaderBtn(Icons.more_horiz),
        ],
      ),
    );
  }

  Widget _buildHeaderBtn(IconData icon) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _kDark1C,
        shape: BoxShape.circle,
        border: Border.all(color: _kDark2A),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _buildUserBubble(String text, Color bg, Color border) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: border),
        ),
        child: Text(text, style: GoogleFonts.manrope(
          fontSize: 15, color: _kGrayF4)),
      ),
    );
  }

  Widget _buildAiResponse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Omni AI label
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _kMint,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: _kMint.withValues(alpha: 0.40),
                  blurRadius: 10)],
              ),
              child: const Icon(Icons.auto_awesome, color: kBg, size: 16),
            ),
            const SizedBox(width: 12),
            Text('OMNI ASSISTANT', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGray71, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 16),
        Text('I found 3 premium yoga studios within 2 miles of your current location:',
          style: GoogleFonts.manrope(fontSize: 15, color: _kGrayD4, height: 1.625)),
        const SizedBox(height: 16),
        _buildGymCard('ZENITH FLOW STUDIO', '4.9', '128 reviews', '0.8 MILES'),
        const SizedBox(height: 16),
        _buildGymCard('THE OMNI LAB', '4.8', '254 reviews', '1.2 MILES'),
      ],
    );
  }

  Widget _buildGymCard(String name, String rating, String reviews, String distance) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C).withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      name.contains('ZENITH')
                          ? const Color(0xFF0A1A10)
                          : const Color(0xFF0A0A1A),
                      _kDark1C,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    name.contains('ZENITH') ? Icons.spa : Icons.fitness_center,
                    color: _kMint.withValues(alpha: 0.15), size: 70),
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kBg05.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(distance, style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kGrayF4)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.manrope(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: _kGrayF4, letterSpacing: -0.45)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: _kMint, size: 10),
                    const SizedBox(width: 4),
                    Text(rating, style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _kMint)),
                    const SizedBox(width: 8),
                    Text('($reviews)', style: GoogleFonts.manrope(
                      fontSize: 14, color: _kGray71)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildGymActionBtn('VIEW GYM', false),
                    const SizedBox(width: 12),
                    _buildGymActionBtn('SEE CLASSES', true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymActionBtn(String label, bool primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: primary ? _kMint : _kDark27,
        borderRadius: BorderRadius.circular(12),
        border: primary ? null : Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(label.toUpperCase(), style: GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: primary ? kBg : Colors.white, letterSpacing: 0.6)),
    );
  }

  Widget _buildMemberInputBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBg05.withValues(alpha: 0), _kBg05],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
        decoration: BoxDecoration(
          color: _kDark1C,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: _kDark2A),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('Ask anything...', style: GoogleFonts.manrope(
                fontSize: 14, color: const Color(0xFF52525B))),
            ),
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                color: _kMint, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward, color: kBg, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── STAFF OPS SECTION ───────────────────

  Widget _buildStaffOpsSection() {
    return Column(
      children: [
        // Purple staff ops mode banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: _kPurple.withValues(alpha: 0.10),
            border: Border(
              top: BorderSide(color: _kPurple.withValues(alpha: 0.20), width: 8),
              bottom: BorderSide(color: _kPurple.withValues(alpha: 0.20)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STAFF OPERATIONS MODE', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w900,
                color: _kPurple, letterSpacing: 2.0)),
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: _kPurple, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
        // Staff ops header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderBtn(Icons.chevron_left),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: _kDark1C,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: _kDark2A),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: _kPurple,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: _kPurple.withValues(alpha: 0.40),
                          blurRadius: 10)],
                      ),
                      child: const Icon(Icons.flash_on, color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 12),
                    Text('Ops Assistant', style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _kGrayD4, letterSpacing: -0.30)),
                  ],
                ),
              ),
              _buildHeaderBtn(Icons.tune),
            ],
          ),
        ),
        // Staff chat content
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User message
              Align(
                alignment: Alignment.centerRight,
                child: _buildUserBubble("Show me today's trials",
                  _kPurple.withValues(alpha: 0.20),
                  _kPurple.withValues(alpha: 0.30)),
              ),
              const SizedBox(height: 24),
              // Assistant overview
              Text('ASSISTANT OVERVIEW', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _kGray71, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              RichText(text: TextSpan(children: [
                TextSpan(text: 'There are ', style: GoogleFonts.manrope(
                  fontSize: 14, color: _kGrayA1, height: 1.5)),
                TextSpan(text: '4 guest trials', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white, height: 1.5)),
                TextSpan(text: ' scheduled for today. Three have not been assigned a host yet.',
                  style: GoogleFonts.manrope(
                    fontSize: 14, color: _kGrayA1, height: 1.5)),
              ])),
              const SizedBox(height: 16),
              // Trial cards with purple left border
              _buildStaffTrialCard(
                name: 'Elena Rodriguez',
                sub: 'First-time Visitor',
                time: '14:30',
                type: 'POWER HIIT',
              ),
              const SizedBox(height: 16),
              _buildStaffTrialCard(
                name: 'Marcus Chen',
                sub: 'Referred by: James T.',
                time: '17:00',
                type: 'BOXING',
              ),
              const SizedBox(height: 16),
              // Assigned trial (dimmed)
              Opacity(
                opacity: 0.60,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C).withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kDark2A),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kDark27,
                              border: Border.all(color: _kDark2A),
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sarah Miller', style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: _kGrayF4)),
                              Text('Assigned to: Alex (You)', style: GoogleFonts.manrope(
                                fontSize: 9, color: _kGray71)),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Staff input
              _buildStaffInputBar(),
              const SizedBox(height: 12),
              // Quick action chips
              SizedBox(
                height: 37,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final labels = ['Class Attendance', 'Revenue Today', 'Member Issues'];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kDark1C,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: _kDark2A),
                      ),
                      child: Text(labels[i], style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _kGrayA1)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffTrialCard({
    required String name,
    required String sub,
    required String time,
    required String type,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDark111,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          left: BorderSide(color: _kPurple, width: 4),
          top: BorderSide(color: _kDark2A),
          right: BorderSide(color: _kDark2A),
          bottom: BorderSide(color: _kDark2A),
        ),
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
                      border: Border.all(color: _kDark2A),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _kGrayF4)),
                      Text(sub, style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: _kGray71)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(time, style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _kPurple)),
                  Text(type, style: GoogleFonts.manrope(
                    fontSize: 10, color: _kGray71,
                    letterSpacing: 0.19)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _kPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Assign to me', textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 0.30)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _kDark1C,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kDark2A),
                  ),
                  child: Text('View Details', textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _kGrayD4, letterSpacing: 0.30)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 18),
      decoration: BoxDecoration(
        color: _kDark111,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPurple.withValues(alpha: 0.30)),
        boxShadow: [BoxShadow(
          color: _kPurple.withValues(alpha: 0.10),
          blurRadius: 0, spreadRadius: 1)],
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: _kPurple, size: 14),
          const SizedBox(width: 16),
          Expanded(
            child: Text('Type a command or ask for data...',
              style: GoogleFonts.manrope(
                fontSize: 14, color: const Color(0xFF9CA3AF))),
          ),
          const Icon(Icons.mic_outlined, color: _kPurple, size: 16),
        ],
      ),
    );
  }
}
