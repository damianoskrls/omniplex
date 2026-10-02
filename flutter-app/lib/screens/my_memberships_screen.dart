import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';
import '../l10n/tr.dart';


class MyMembershipsScreen extends StatefulWidget {
  const MyMembershipsScreen({super.key});

  @override
  State<MyMembershipsScreen> createState() => _MyMembershipsScreenState();
}

class _MyMembershipsScreenState extends State<MyMembershipsScreen> {
  int _tab = 0; // 0=Active, 1=Expired

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Lime top glow
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
                  stops: const [0.0, 0.35, 0.6],
                ),
              ),
            ),
          ),
          // Cyan bottom-right glow
          Positioned(
            right: 0, top: 384,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kCyan.withValues(alpha: 0.08), Colors.transparent],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildTabs(),
                        const SizedBox(height: 28),
                        _buildSectionLabel(),
                        const SizedBox(height: 16),
                        _buildClassPackCard(),
                        const SizedBox(height: 20),
                        _buildMonthlyCard(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(tr('My Memberships'), style: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.6)),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kBorder2),
          ),
          child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    const tabs = ['Active', 'Expired'];
    return Stack(
      children: [
        const Positioned(
          left: 0, right: 0, bottom: 0,
          child: Divider(color: kBorder, thickness: 1, height: 1),
        ),
        Row(
          children: List.generate(2, (i) {
            final active = _tab == i;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Padding(
                padding: EdgeInsets.only(right: i == 0 ? 32 : 0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(tr(tabs[i]), style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: active ? Colors.white : kGray,
                        letterSpacing: 0.35)),
                    ),
                    if (active)
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: [
                            BoxShadow(color: kLime.withValues(alpha: 0.5), blurRadius: 12),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 3),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSectionLabel() {
    return Text(tr('2 ACTIVE MEMBERSHIPS'), style: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: kGray, letterSpacing: 0.3));
  }

  Widget _buildClassPackCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2024),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(Icons.fitness_center, color: kGray, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Fitness Club Athens'), style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(tr('10 Class Pack'), style: GoogleFonts.inter(
                      fontSize: 12, color: kGray)),
                  ],
                ),
              ),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2024),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: kBorder2),
                ),
                child: Center(
                  child: Text(tr('PACK'), style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kGray, letterSpacing: 0.25)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('Classes Remaining'), style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
              Text(tr('8 / 10'), style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: kLime)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 8, color: const Color(0xFF1F2024),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.80,
                child: Container(
                  decoration: BoxDecoration(
                    color: kLime,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: [
                      BoxShadow(color: kLime.withValues(alpha: 0.5), blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: kBorder, thickness: 1, height: 1),
          // Expires row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: kGray, size: 14),
                const SizedBox(width: 8),
                Text(tr('Expires'), style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                const Spacer(),
                Text(tr('Oct 28'), style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          const Divider(color: kBorder, thickness: 1, height: 1),
          const SizedBox(height: 16),
          _viewDetailsButton(),
        ],
      ),
    );
  }

  Widget _buildMonthlyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2024),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(Icons.bolt, color: kGray, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Urban Fitness'), style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(tr('Monthly Unlimited'), style: GoogleFonts.inter(
                      fontSize: 12, color: kGray)),
                  ],
                ),
              ),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 7),
                  ],
                ),
                child: Center(
                  child: Text(tr('Active'), style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kBg, letterSpacing: 0.25)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Unlimited Access banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1D2410),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.all_inclusive, color: kLime, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Unlimited Access'), style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: kLime, letterSpacing: -0.35)),
                      Text(tr('No visit limits this cycle'), style: GoogleFonts.inter(
                        fontSize: 12, color: kGray)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: kBorder, thickness: 1, height: 1),
          // Renews row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.sync, color: kGray, size: 14),
                const SizedBox(width: 8),
                Text(tr('Renews'), style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                const Spacer(),
                Text(tr('Nov 5'), style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          const Divider(color: kBorder, thickness: 1, height: 1),
          const SizedBox(height: 16),
          _viewDetailsButton(),
        ],
      ),
    );
  }

  Widget _viewDetailsButton() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(tr('View Details'), style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 0.3)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white, size: 14),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_outlined, 'Home', false),
      (Icons.search, 'Search', false),
      (Icons.calendar_today_outlined, 'Schedule', false),
      (Icons.fitness_center_outlined, 'My Gyms', false),
      (Icons.person_outline, 'Profile', true),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          final active = item.$3;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, color: active ? kLime : kDim, size: 20),
              const SizedBox(height: 6),
              Text(tr(item.$2),
                style: active
                  ? GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: kLime)
                  : GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: kDim)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
