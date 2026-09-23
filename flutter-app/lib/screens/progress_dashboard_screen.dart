import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kD1 = Color(0xFFD1D5DB);
  static const _kDark1C = Color(0xFF1C1C1C);

  int _trendMode = 0; // 0=W, 1=M, 2=3M

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildWeightCard(),
                    const SizedBox(height: 16),
                    _buildMetricRow(),
                    const SizedBox(height: 32),
                    _buildWeightTrendSection(),
                    const SizedBox(height: 32),
                    _buildCoachInsightsCard(),
                    const SizedBox(height: 32),
                    _buildBodyComparisonSection(),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
          Positioned(
            right: 24, bottom: 96,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: kLime,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: kLime.withValues(alpha: 0.30), blurRadius: 20)],
              ),
              child: const Icon(Icons.add, color: kBg, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Container(
        color: kBg.withValues(alpha: 0.80),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBorder26.withValues(alpha: 0.50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Center(child: Icon(Icons.chevron_left, color: Colors.white, size: 20)),
            ),
            Text('My Progress', style: GoogleFonts.spaceGrotesk(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.5)),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBorder26.withValues(alpha: 0.50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Center(child: Icon(Icons.share_outlined, color: Colors.white, size: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kLime.withValues(alpha: 0.20)),
        boxShadow: [BoxShadow(
          color: kLime.withValues(alpha: 0.20), blurRadius: 15)],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CURRENT WEIGHT', style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: kLime, letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('82.5', style: GoogleFonts.spaceGrotesk(
                            fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(width: 4),
                          Text('kg', style: GoogleFonts.manrope(
                            fontSize: 14, color: _kGray9C)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kLime.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: kLime.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_downward, color: kLime, size: 14),
                        const SizedBox(width: 4),
                        Text('0.5 kg', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700, color: kLime)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('GOAL: 80.0 KG', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kGray6B, letterSpacing: 0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kBorder26,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.85,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: -16, right: -16,
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kLime.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.percent,
            iconBg: kCyan.withValues(alpha: 0.10),
            iconColor: kCyan,
            label: 'BODY FAT',
            value: '18.2',
            unit: '%',
            change: '1.2%',
            changeColor: kCyan,
            changeDown: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.fitness_center,
            iconBg: Colors.white.withValues(alpha: 0.05),
            iconColor: Colors.white,
            label: 'MUSCLE MASS',
            value: '38.5',
            unit: 'kg',
            change: '0.8 kg',
            changeColor: kLime,
            changeDown: false,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required String change,
    required Color changeColor,
    required bool changeDown,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: _kGray9C, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: GoogleFonts.spaceGrotesk(
                fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 2),
              Text(unit, style: GoogleFonts.manrope(
                fontSize: 10, color: _kGray6B)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                changeDown ? Icons.arrow_downward : Icons.arrow_upward,
                color: changeColor, size: 12),
              const SizedBox(width: 4),
              Text(change, style: GoogleFonts.manrope(
                fontSize: 10, color: changeColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTrendSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('WEIGHT TREND', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 2.4)),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: ['W', 'M', '3M'].asMap().entries.map((e) {
                  final active = _trendMode == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _trendMode = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? _kBorder26 : Colors.transparent,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(e.value, style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: active ? Colors.white : _kGray6B, letterSpacing: 0.25)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kDark1C,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: SizedBox(
            height: 240,
            child: CustomPaint(
              size: const Size(double.infinity, 240),
              painter: _WeightChartPainter(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoachInsightsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COACH INSIGHTS', style: GoogleFonts.spaceGrotesk(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _kGray6B, letterSpacing: 2.4)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kCyan.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kCyan.withValues(alpha: 0.10)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kCyan.withValues(alpha: 0.30), width: 2),
                  color: const Color(0xFF3A3C42),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"Great consistency this week! Your weight drop is steady, and muscle mass is increasing. Increase your protein intake by 15g tomorrow."',
                      style: GoogleFonts.manrope(
                        fontSize: 14, color: _kD1, height: 1.6)),
                    const SizedBox(height: 12),
                    Text('— COACH ALEXANDER', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: kCyan, letterSpacing: 1.0)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBodyComparisonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('BODY COMPARISON', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 2.4)),
            Text('View All', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700, color: kLime)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 192,
                decoration: BoxDecoration(
                  color: _kBorder26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Center(child: Icon(Icons.person_outline, color: Color(0xFF3A3C42), size: 60)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12, bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 11, 8, 6),
                        decoration: BoxDecoration(
                          color: kBg.withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('MONTH 1', style: GoogleFonts.manrope(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 0.9)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 192,
                decoration: BoxDecoration(
                  color: _kBorder26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kLime.withValues(alpha: 0.30)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Center(child: Icon(Icons.person, color: Color(0xFF3A3C42), size: 60)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12, bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 11, 8, 6),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('CURRENT', style: GoogleFonts.manrope(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: kBg, letterSpacing: 0.9)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_rounded, 'HOME', false),
          _buildNavItem(Icons.calendar_today, 'SCHEDULE', false),
          _buildNavItem(Icons.show_chart, 'PROGRESS', true),
          _buildNavItem(Icons.fitness_center_outlined, 'PROGRAMS', false),
          _buildProfileNav(),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? kLime : _kGray6B, size: 22),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: active ? kLime : _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }

  Widget _buildProfileNav() {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kGray6B),
              color: const Color(0xFF3A3C42),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 14),
          ),
          const SizedBox(height: 4),
          Text('PROFILE', style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * 0.05, size.height * 0.15),
      Offset(size.width * 0.20, size.height * 0.25),
      Offset(size.width * 0.35, size.height * 0.20),
      Offset(size.width * 0.50, size.height * 0.35),
      Offset(size.width * 0.65, size.height * 0.45),
      Offset(size.width * 0.80, size.height * 0.60),
      Offset(size.width * 0.95, size.height * 0.65),
    ];

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF262626)
      ..strokeWidth = 0.5;
    for (int i = 0; i < 5; i++) {
      final y = size.height * 0.10 + (size.height * 0.75 / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Area fill
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.lineTo(points.last.dx, size.height);
    path.lineTo(points.first.dx, size.height);
    path.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFCCFF00).withValues(alpha: 0.15),
          const Color(0xFFCCFF00).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = const Color(0xFFCCFF00)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Points
    final dotPaint = Paint()..color = const Color(0xFFCCFF00);
    final dotBg = Paint()..color = const Color(0xFF1C1C1C);
    for (final p in points) {
      canvas.drawCircle(p, 5, dotBg);
      canvas.drawCircle(p, 3.5, dotPaint);
    }

    // Day labels
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final textStyle = TextStyle(
      color: const Color(0xFF666666),
      fontSize: 10,
      fontFamily: 'Inter',
    );
    for (int i = 0; i < 7; i++) {
      final x = size.width * 0.05 + (size.width * 0.90 / 6) * i;
      final tp = TextPainter(
        text: TextSpan(text: days[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 18));
    }

    // Y labels
    const yLabels = ['82', '82.5', '83', '83.5', '84'];
    for (int i = 0; i < 5; i++) {
      final y = size.height * 0.10 + (size.height * 0.75 / 4) * i;
      final tp = TextPainter(
        text: TextSpan(text: yLabels[4 - i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_WeightChartPainter oldDelegate) => false;
}
