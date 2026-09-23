import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';
import 'admin_dashboard_screen.dart';
import 'admin_members_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_staff_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_AdminShellScreenState>();
    state?._setTab(index);
  }

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;

  void _setTab(int i) => setState(() => _index = i);

  static const _screens = [
    AdminDashboardScreen(),
    AdminMembersScreen(),
    AdminRequestsScreen(),
    AdminStaffScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.pie_chart_outline, 'DASHBOARD', 0),
          _navItem(Icons.group_outlined, 'MEMBERS', 1),
          _navItem(Icons.inbox_outlined, 'REQUESTS', 2),
          _navItem(Icons.badge_outlined, 'STAFF', 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _index == idx;
    return GestureDetector(
      onTap: () => _setTab(idx),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? kLime : const Color(0xFF6B7280), size: 20),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: active ? kLime : const Color(0xFF6B7280), letterSpacing: 0.9)),
        ],
      ),
    );
  }
}
