import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class WaitlistRecurringScreen extends StatefulWidget {
  const WaitlistRecurringScreen({super.key});

  @override
  State<WaitlistRecurringScreen> createState() => _WaitlistRecurringScreenState();
}

class _WaitlistRecurringScreenState extends State<WaitlistRecurringScreen> {
  static const _kDark16 = Color(0xFF161616);
  static const _kDark26 = Color(0xFF262626);
  static const _kDark33 = Color(0xFF333333);
  static const _kGrayA1 = Color(0xFFA1A1AA);
  static const _kGray71 = Color(0xFF71717A);
  static const _kGrayD4 = Color(0xFFD4D4D8);
  static const _kRed = Color(0xFFEF4444);
  static const _kYellow = Color(0xFFEAB308);

  // T and T selected (Tue / Thu)
  final _selectedDays = {1: true, 3: true};
  final _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            // ── Class Details section ──
            _buildClassDetailsSection(),
            // ── Divider ──
            Container(height: 16, color: const Color(0xFF333333)),
            // ── Recurring Booking section ──
            _buildRecurringSection(),
          ],
        ),
      ),
    );
  }

  // ─────────────────── CLASS DETAILS ───────────────────

  Widget _buildClassDetailsSection() {
    return SizedBox(
      height: 840,
      child: Stack(
        children: [
          // Gym image card
          Positioned(
            top: 88, left: 24, right: 24,
            child: _buildGymImageCard(),
          ),
          // Content below image
          Positioned(
            top: 368, left: 24, right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClassInfo(),
                const SizedBox(height: 32),
                _buildWaitlistCard(),
                const SizedBox(height: 32),
                _buildScheduleDetails(),
              ],
            ),
          ),
          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildDetailHeader('Class Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      color: kBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kDark26,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
          ),
          Text(title, style: GoogleFonts.manrope(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.45)),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kDark26,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildGymImageCard() {
    return Container(
      height: 256,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kDark33),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF0A0A14)],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(Icons.self_improvement,
              color: Colors.white.withValues(alpha: 0.08), size: 100),
          ),
          // Gradient at bottom
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, kBg],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
          ),
          // CLASS FULL badge
          Positioned(
            top: 16, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text('CLASS FULL', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 1.0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ADVANCED PILATES', style: GoogleFonts.manrope(
              fontSize: 24, fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Colors.white, letterSpacing: -1.2)),
            Text('with Sarah Jenkins', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: kLime)),
          ],
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          decoration: BoxDecoration(
            color: _kDark26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kDark33),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duration', style: GoogleFonts.manrope(
                fontSize: 12, color: _kGrayA1)),
              Text('60 min', style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaitlistCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kLime.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLime.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: kLime, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: kBg, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You're on the waitlist", style: GoogleFonts.manrope(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kLime)),
                  Text("We'll notify you if a spot opens up.", style: GoogleFonts.manrope(
                    fontSize: 14, color: _kGrayA1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: kLime.withValues(alpha: 0.20), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR STATUS', style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _kGray71, letterSpacing: 1.2)),
                  Text('Position: #3', style: GoogleFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: Colors.white)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                ),
                child: Text('Leave Waitlist', style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleDetails() {
    return Column(
      children: [
        _buildScheduleRow(Icons.calendar_today, 'Tuesday, Oct 24', 'Starts at 18:30'),
        const SizedBox(height: 16),
        _buildScheduleRow(Icons.location_on_outlined, 'Studio A • OmniPlex North', 'Level 2, High Intensity'),
      ],
    );
  }

  Widget _buildScheduleRow(IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _kDark26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w600, color: _kGrayD4)),
            Text(sub, style: GoogleFonts.manrope(
              fontSize: 12, color: _kGray71)),
          ],
        ),
      ],
    );
  }

  // ─────────────────── RECURRING BOOKING ───────────────────

  Widget _buildRecurringSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecurringHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDaySelector(),
              const SizedBox(height: 32),
              _buildTimeAndDuration(),
              const SizedBox(height: 32),
              _buildBookingSummary(),
              const SizedBox(height: 32),
              _buildConfirmButton(),
              const SizedBox(height: 16),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'REMAINING SESSION WILL BE ADDED TO YOUR ',
                      style: GoogleFonts.manrope(
                        fontSize: 10, color: _kGray71, letterSpacing: 1.0)),
                    TextSpan(
                      text: 'INDIVIDUAL WAITLIST',
                      style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 1.0)),
                    TextSpan(
                      text: ' AUTOMATICALLY',
                      style: GoogleFonts.manrope(
                        fontSize: 10, color: _kGray71, letterSpacing: 1.0)),
                  ]),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecurringHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kDark26, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 24),
          Text('Book Repeatedly', style: GoogleFonts.manrope(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.45)),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT DAYS', style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _kGray71, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_dayLabels.length, (i) {
            final selected = _selectedDays[i] == true;
            return GestureDetector(
              onTap: () => setState(() {
                if (_selectedDays[i] == true) {
                  _selectedDays.remove(i);
                } else {
                  _selectedDays[i] = true;
                }
              }),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: selected ? kLime : _kDark26,
                  borderRadius: BorderRadius.circular(8),
                  border: selected
                      ? Border.all(color: kLime, width: 2)
                      : null,
                  boxShadow: selected
                      ? [BoxShadow(
                          color: kLime.withValues(alpha: 0.40),
                          blurRadius: 0, spreadRadius: 2)]
                      : null,
                ),
                child: Center(
                  child: Text(_dayLabels[i], style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: selected ? kBg : _kGray71)),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTimeAndDuration() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TIME', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _kGray71, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kDark26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kDark33),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('07:00', style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DURATION', style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _kGray71, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kDark26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kDark33),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Entire Month', style: GoogleFonts.manrope(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kDark16,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDark33),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('8 BOOKINGS', style: GoogleFonts.manrope(
                    fontSize: 24, fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Colors.white, letterSpacing: -1.2)),
                  Text('Found for October 2023', style: GoogleFonts.manrope(
                    fontSize: 12, color: _kGrayA1)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kYellow.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kYellow.withValues(alpha: 0.30)),
                ),
                child: Text('ACTION REQUIRED', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kYellow, letterSpacing: 0.05)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildBookingRow(Icons.check_circle, 'Tue, Oct 03 • 07:00', 'Available', Colors.white, Colors.white),
          Divider(color: _kDark33.withValues(alpha: 0.50), height: 24),
          _buildBookingRow(Icons.error, 'Thu, Oct 05 • 07:00', 'CLASS FULL', _kRed.withValues(alpha: 0.80), _kRed),
          Divider(color: _kDark33.withValues(alpha: 0.50), height: 24),
          _buildBookingRow(Icons.check_circle_outline, 'Tue, Oct 10 • 07:00', 'Available', _kGray71, Colors.white),
          const SizedBox(height: 24),
          Divider(color: _kDark33, height: 1),
          const SizedBox(height: 20),
          Text('RECOMMENDED ALTERNATIVES', style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w900,
            color: _kGray71, letterSpacing: 2.0)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildAltSlot('08:00 SLOT', 'Thu, Oct 05')),
              const SizedBox(width: 8),
              Expanded(child: _buildAltSlot('07:00 SLOT', 'Wed, Oct 04')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingRow(IconData icon, String date, String status, Color iconColor, Color dateColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 12),
            Text(date, style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: dateColor)),
          ],
        ),
        Text(status, style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: status == 'CLASS FULL' ? _kRed : _kGray71)),
      ],
    );
  }

  Widget _buildAltSlot(String time, String date) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 11),
      decoration: BoxDecoration(
        color: _kDark26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kDark33),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time, style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: kLime, letterSpacing: 0.02)),
          const SizedBox(height: 6),
          Text(date, style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
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
          Text('CONFIRM 7 BOOKINGS', style: GoogleFonts.manrope(
            fontSize: 18, fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: kBg, letterSpacing: -0.45)),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: kBg, size: 20),
        ],
      ),
    );
  }
}
