import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/omni_design.dart';
import '../services/auth_service.dart';
import 'member_home_v2_screen.dart';
import 'unified_schedule_screen.dart';
import 'qr_access_screen.dart';
import 'messages_screen.dart';
import 'member_profile_screen.dart';

class OmniMemberShellScreen extends StatefulWidget {
  const OmniMemberShellScreen({super.key});

  static final _key = GlobalKey<_OmniMemberShellScreenState>();

  static void selectTab(int index) {
    _key.currentState?._setTab(index);
  }

  static void openNotifications() {
    _key.currentState?._setTab(0);
  }

  static void openMessages({String? threadId}) {
    _key.currentState?._setTab(3);
  }

  @override
  State<OmniMemberShellScreen> createState() => _OmniMemberShellScreenState();
}

class _OmniMemberShellScreenState extends State<OmniMemberShellScreen> {
  int _tab = 0;

  void _setTab(int i) => setState(() => _tab = i);

  static const _kBorder26 = Color(0xFF262626);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userName = auth.user?.fullName ?? 'there';

    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(
        index: _tab,
        children: [
          MemberHomeV2Screen(userName: userName, onTabChange: _setTab),
          const UnifiedScheduleScreen(),
          const QrAccessScreen(),
          const MessagesScreen(),
          const MemberProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: BoxDecoration(
        color: kBg,
        border: const Border(top: BorderSide(color: _kBorder26)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined, Icons.home, 'HOME'),
              _navItem(1, Icons.calendar_today_outlined, Icons.calendar_today, 'SCHEDULE'),
              _navItem(2, Icons.qr_code_outlined, Icons.qr_code, 'QR'),
              _navItem(3, Icons.chat_bubble_outline, Icons.chat_bubble, 'MESSAGES'),
              _navItem(4, Icons.person_outline, Icons.person, 'PROFILE'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: active ? kLime : const Color(0xFF6B7280),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? kLime : const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
