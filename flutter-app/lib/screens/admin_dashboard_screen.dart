import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/omni_design.dart';
import '../services/auth_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kDark16 = Color(0xFF161616);
  static const _kBorder26 = Color(0xFF262626);
  static const _kDark1C = Color(0xFF1C1C1C);
  static const _kRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<AuthService>().api;
      final data = await api.fetchAdminDashboard();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKeyMetrics(),
                  const SizedBox(height: 32),
                  _buildRevenueChart(),
                  const SizedBox(height: 32),
                  _buildManagementSection(),
                  const SizedBox(height: 32),
                  _buildAlertsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.90),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Dashboard', style: GoogleFonts.spaceGrotesk(
                fontSize: 24, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.6)),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text('FITNESS CLUB ATHENS', style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: kLime, letterSpacing: 1.1)),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, color: kLime, size: 12),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kDark16,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder26),
                ),
                child: const Center(child: Icon(Icons.search, color: Colors.white, size: 16)),
              ),
              const SizedBox(width: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _kDark16,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder26),
                    ),
                    child: const Center(child: Icon(Icons.notifications_outlined, color: Colors.white, size: 16)),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: kCyan, shape: BoxShape.circle)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('KEY METRICS', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGray9C, letterSpacing: 1.2)),
            Text('REAL-TIME', style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700, color: kLime)),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.85,
          children: [
            _buildMetricCard(
              label: 'ACTIVE MEMBERS',
              value: _data != null ? '${_data!['active_members'] ?? _data!['total_clients'] ?? '—'}' : '—',
              badge: _loading ? null : '+', badgeColor: kLime,
              accentBorder: kLime,
            ),
            _buildMetricCard(
              label: "TODAY'S BOOKINGS",
              value: _data != null ? '${_data!['today_bookings'] ?? '—'}' : '—',
              accentBorder: kCyan,
            ),
            _buildMetricCard(
              label: 'TOTAL CLIENTS',
              value: _data != null ? '${_data!['total_clients'] ?? '—'}' : '—',
              accentBorder: Colors.white.withValues(alpha: 0.20),
            ),
            _buildMetricCard(
              label: 'PENDING',
              value: _data != null ? '${_data!['pending_clients'] ?? '—'}' : '—',
              badge: (_data?['pending_clients'] ?? 0) > 0 ? '!' : null,
              badgeColor: _kRed,
              accentBorder: Colors.white.withValues(alpha: 0.20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    String? badge,
    Color? badgeColor,
    String? sub,
    Color? subColor,
    required Color accentBorder,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.85, -1),
          end: Alignment(0.85, 1),
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accentBorder, width: 2),
          top: BorderSide(color: accentBorder.withValues(alpha: 0.50)),
          right: BorderSide(color: accentBorder.withValues(alpha: 0.50)),
          bottom: BorderSide(color: accentBorder.withValues(alpha: 0.50)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: _kGray6B, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: GoogleFonts.spaceGrotesk(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Text(badge, style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor)),
              ],
              if (sub != null) ...[
                const SizedBox(width: 8),
                Text(sub, style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700, color: subColor)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.85, -1),
          end: Alignment(0.85, 1),
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
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Revenue Performance', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('LAST 7 DAYS', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kGray6B, letterSpacing: 1.0)),
                ],
              ),
              Row(
                children: [
                  Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF262626), shape: BoxShape.circle)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _RevenuePainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection() {
    final items = [
      (Icons.people_outline, 'MEMBERS', null, null),
      (Icons.badge_outlined, 'STAFF', null, null),
      (Icons.card_membership_outlined, 'PACKAGES', null, null),
      (Icons.event_outlined, 'CLASSES', null, null),
      (Icons.language_outlined, 'COMMUNITY', '+3', kCyan),
      (Icons.store_outlined, 'MARKET', null, null),
      (Icons.fitness_center_outlined, 'PROGRAMS', null, null),
      (Icons.mail_outline, 'REQUESTS', '12', kLime),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MANAGEMENT & OPERATIONS', style: GoogleFonts.spaceGrotesk(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _kGray9C, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.80,
          children: items.map((item) => _buildMgmtItem(item.$1, item.$2, item.$3, item.$4)).toList(),
        ),
      ],
    );
  }

  Widget _buildMgmtItem(IconData icon, String label, String? badge, Color? badgeColor) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _kDark16,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder26),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            if (badge != null)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: badgeColor, borderRadius: BorderRadius.circular(9999)),
                  child: Text(badge, style: GoogleFonts.manrope(
                    fontSize: 8, fontWeight: FontWeight.w800, color: kBg)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: _kGray9C, letterSpacing: 0.12),
          textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CRITICAL ALERTS', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGray9C, letterSpacing: 1.2)),
            Text('VIEW ALL', style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _kGray6B, decoration: TextDecoration.underline)),
          ],
        ),
        const SizedBox(height: 16),
        _buildAlertCard(
          icon: Icons.warning_amber_rounded, iconColor: _kRed,
          iconBg: _kRed.withValues(alpha: 0.10),
          borderColor: _kRed,
          title: 'System Maintenance Failure',
          detail: 'Automated locker system in Zone B is offline.',
        ),
        const SizedBox(height: 12),
        _buildAlertCard(
          icon: Icons.emoji_events_outlined, iconColor: kLime,
          iconBg: kLime.withValues(alpha: 0.10),
          borderColor: kLime,
          title: 'Monthly Target Reached!',
          detail: 'Retention rate hit 94.2% - New record.',
        ),
      ],
    );
  }

  Widget _buildAlertCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    required String title,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDark1C,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(detail, style: GoogleFonts.manrope(
                  fontSize: 10, color: _kGray6B)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _RevenuePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const values = [0.45, 0.55, 0.50, 0.65, 0.80, 0.70, 0.88];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const yLabels = ['€0', '€5k', '€10k'];

    final chartLeft = 28.0;
    final chartRight = size.width;
    final chartTop = 0.0;
    final chartBottom = size.height - 20;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = chartBottom - (i / 2) * (chartBottom - chartTop);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    // Y labels
    final yStyle = TextStyle(color: const Color(0xFF666666), fontSize: 10,
        fontFamily: 'Inter');
    for (int i = 0; i < yLabels.length; i++) {
      final y = chartBottom - (i / 2) * (chartBottom - chartTop);
      final tp = TextPainter(
        text: TextSpan(text: yLabels[i], style: yStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Points
    List<Offset> points = [];
    final w = chartRight - chartLeft;
    for (int i = 0; i < values.length; i++) {
      final x = chartLeft + (i / (values.length - 1)) * w;
      final y = chartBottom - values[i] * (chartBottom - chartTop);
      points.add(Offset(x, y));
    }

    // Area fill
    final path = Path()..moveTo(points.first.dx, chartBottom);
    for (final p in points) { path.lineTo(p.dx, p.dy); }
    path.lineTo(points.last.dx, chartBottom);
    path.close();
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFFCCFF00).withValues(alpha: 0.20), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = const Color(0xFFCCFF00)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // Dots
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = const Color(0xFFCCFF00));
      canvas.drawCircle(p, 2, Paint()..color = const Color(0xFF0A0A0A));
    }

    // X labels
    for (int i = 0; i < days.length; i++) {
      final x = chartLeft + (i / (values.length - 1)) * w;
      final tp = TextPainter(
        text: TextSpan(text: days[i], style: yStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
