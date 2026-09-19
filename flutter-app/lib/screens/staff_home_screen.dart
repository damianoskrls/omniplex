import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import 'community_screen.dart';
import 'staff_schedule_screen.dart';
import 'staff_leaves_screen.dart';
import 'staff_profile_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _index = 0;

  List<_StaffTab> _buildTabs(BuildContext context) {
    final s = AppStrings.of(context);
    return [
      _StaffTab(icon: Icons.calendar_today_outlined, label: s.staffScheduleTab),
      _StaffTab(icon: Icons.people_outline, label: s.staffCommunityTab),
      _StaffTab(icon: Icons.beach_access_outlined, label: s.staffLeavesTab),
      _StaffTab(icon: Icons.person_outline, label: s.staffProfileTab),
    ];
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const StaffScheduleScreen(),
      const CommunityScreen(),
      const StaffLeavesScreen(),
      const StaffProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthService>();
    final config = context.read<TenantConfig>();
    final user   = auth.user;
    if (user == null) return Scaffold(body: Center(child: const CircularProgressIndicator(color: AppColors.lime)));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StaffHeader(user: user, gymName: config.appName),
            Expanded(child: _screens[_index]),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
        ),
        child: SafeArea(
          child: Row(
            children: List.generate(4, (i) {
              final t = _buildTabs(context)[i];
              final sel = _index == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _index = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon,
                            size: 22,
                            color: sel ? AppColors.lime : AppColors.textSecondary),
                        const SizedBox(height: 3),
                        Text(t.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                              color: sel ? AppColors.lime : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _StaffTab {
  const _StaffTab({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _StaffHeader extends StatelessWidget {
  const _StaffHeader({required this.user, required this.gymName});
  final dynamic user;
  final String gymName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.lime.withValues(alpha: 0.4)),
            ),
            child: user.avatarUrl != null && (user.avatarUrl as String).isNotEmpty
                ? ClipOval(child: Image.network(user.avatarUrl as String, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initials(user.fullName as String)))
                : _initials(user.fullName as String),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName as String,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                Text(user.staffRole as String? ?? gymName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Staff badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.lime.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge_outlined, size: 13, color: AppColors.lime),
                const SizedBox(width: 4),
                Text(gymName, style: TextStyle(fontSize: 11, color: AppColors.lime, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials(String name) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w800, fontSize: 18),
    ),
  );
}
