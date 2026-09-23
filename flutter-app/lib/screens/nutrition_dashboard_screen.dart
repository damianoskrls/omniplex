import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class NutritionDashboardScreen extends StatelessWidget {
  const NutritionDashboardScreen({super.key});

  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kD1 = Color(0xFFD1D5DB);
  static const _kPurple = Color(0xFFBF00FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCaloriesCard(),
                      const SizedBox(height: 32),
                      _buildMealTimeline(),
                      const SizedBox(height: 32),
                      _buildHydrationCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      child: Container(
        color: kBg.withValues(alpha: 0.80),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
            Column(
              children: [
                Text("TODAY'S NUTRITION", style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 0.9)),
                Text('MONDAY, 24 MAY', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: kLime, letterSpacing: 1.0)),
              ],
            ),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBorder26.withValues(alpha: 0.50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Center(child: Icon(Icons.calendar_month_outlined, color: Colors.white, size: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL CALORIES', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kGray6B, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('1,840', style: GoogleFonts.spaceGrotesk(
                        fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(width: 4),
                      Text('/ 2,400 kcal', style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, color: _kGray9C)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('REMAINING', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kCyan, letterSpacing: 1.0)),
                  Text('560', style: GoogleFonts.spaceGrotesk(
                    fontSize: 18, fontWeight: FontWeight.w700, color: kCyan)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Donut chart placeholder
          Center(
            child: SizedBox(
              width: 180, height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: _DonutPainter(),
                  ),
                  Text('76%', style: GoogleFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: _kGray9C)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Macro bars
          Row(
            children: [
              Expanded(child: _buildMacroBar('PROTEIN', '142g', '/ 180g', 0.79, kCyan)),
              const SizedBox(width: 16),
              Expanded(child: _buildMacroBar('CARBS', '98g', '/ 220g', 0.45, _kPurple)),
              const SizedBox(width: 16),
              Expanded(child: _buildMacroBar('FATS', '54g', '/ 65g', 0.83, kLime)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String label, String value, String target, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: _kBorder26,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _kGray9C, letterSpacing: 1.0),
          textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 2),
            Text(target, style: GoogleFonts.manrope(
              fontSize: 8, color: _kGray6B)),
          ],
        ),
      ],
    );
  }

  Widget _buildMealTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('MEAL TIMELINE', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 2.4)),
            Text('+ LOG MACRO', style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: kLime, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 24),
        // Breakfast (completed)
        _buildMealRow(
          title: 'Breakfast',
          subtitle: 'Completed at 08:30 AM',
          kcal: '420 kcal',
          dot: kLime,
          isActive: false,
          items: [
            _MealItem('Oatmeal w/ Berries', _kPurple),
            _MealItem('Whey Isolate', kCyan),
          ],
        ),
        const SizedBox(height: 12),
        // Lunch (current — highlighted)
        _buildLunchCard(),
        const SizedBox(height: 12),
        // Afternoon Snack (upcoming)
        _buildMealRow(
          title: 'Afternoon Snack',
          subtitle: 'Estimated: 04:30 PM',
          kcal: '220 kcal',
          dot: _kBorder26,
          isActive: false,
          dimmed: true,
        ),
        const SizedBox(height: 12),
        // Dinner (upcoming)
        _buildMealRow(
          title: 'Dinner',
          subtitle: 'Estimated: 08:00 PM',
          kcal: '520 kcal',
          dot: _kBorder26,
          isActive: false,
          dimmed: true,
        ),
      ],
    );
  }

  Widget _buildMealRow({
    required String title,
    required String subtitle,
    required String kcal,
    required Color dot,
    required bool isActive,
    bool dimmed = false,
    List<_MealItem> items = const [],
  }) {
    return Opacity(
      opacity: dimmed ? 0.50 : 1.0,
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              Container(width: 1, height: 48, color: _kBorder26.withValues(alpha: 0.30)),
            ],
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(subtitle, style: GoogleFonts.manrope(
                          fontSize: 10, color: _kGray6B)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(kcal, style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: items.map((item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616).withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(item.name, style: GoogleFonts.manrope(
                              fontSize: 10, color: _kD1)),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLunchCard() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: kLime,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.20), blurRadius: 7.5)],
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: kBg, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x66262626), Color(0x99161616)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kLime.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Lunch', style: GoogleFonts.manrope(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('NOW', style: GoogleFonts.manrope(
                            fontSize: 8, fontWeight: FontWeight.w900,
                            color: kBg, letterSpacing: 0.23)),
                        ),
                      ],
                    ),
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(text: '680', style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        TextSpan(text: 'kcal', style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, color: _kGray6B)),
                      ]),
                    ),
                  ],
                ),
                Text('Scheduled: 01:30 PM', style: GoogleFonts.manrope(
                  fontSize: 10, color: _kGray9C)),
                const SizedBox(height: 12),
                // Food items
                _buildFoodItem(Icons.set_meal, 'Grilled Chicken', '180g • 42g Protein'),
                const SizedBox(height: 8),
                _buildFoodItem(Icons.rice_bowl, 'Brown Rice', '150g • 34g Carbs'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: kBg, size: 14),
                            const SizedBox(width: 8),
                            Text('MARK EATEN', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: kBg, letterSpacing: -0.6)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _kBorder26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 8),
                          Text('SCAN FOOD', style: GoogleFonts.manrope(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodItem(IconData icon, String name, String detail) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kBorder26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _kGray6B, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(detail, style: GoogleFonts.manrope(
                  fontSize: 9, color: _kGray6B)),
              ],
            ),
          ),
          const Icon(Icons.add, color: Color(0xFF9CA3AF), size: 14),
        ],
      ),
    );
  }

  Widget _buildHydrationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: kCyan.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.water_drop_outlined, color: kCyan, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hydration', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('1.8L / 3.0L Target', style: GoogleFonts.manrope(
                  fontSize: 10, color: _kGray9C)),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _kBorder26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.remove, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text('1.8', style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white), textAlign: TextAlign.center),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: kCyan,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: kBg, size: 14),
              ),
            ],
          ),
        ],
      ),
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
          _buildNavItem(Icons.search, 'SEARCH', false),
          _buildNavItem(Icons.restaurant_outlined, 'NUTRITION', true),
          _buildNavItem(Icons.fitness_center_outlined, 'MY GYMS', false),
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

class _MealItem {
  final String name;
  final Color color;
  const _MealItem(this.name, this.color);
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 16.0;

    final bgPaint = Paint()
      ..color = const Color(0xFF262626)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final limePaint = Paint()
      ..color = const Color(0xFFCCFF00)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      2 * 3.14159 * 0.76,
      false,
      limePaint,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => false;
}
