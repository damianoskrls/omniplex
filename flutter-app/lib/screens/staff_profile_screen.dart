import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class StaffProfileScreen extends StatelessWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthService>();
    final config = context.read<TenantConfig>();
    final user   = auth.user;
    if (user == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Profile card
        SurfaceCard(
          child: Row(
            children: [
              _Avatar(user: user),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    if (user.staffRole != null && user.staffRole!.isNotEmpty)
                      Text(user.staffRole!,
                          style: TextStyle(fontSize: 13, color: AppColors.lime, fontWeight: FontWeight.w600)),
                    if (user.email.isNotEmpty)
                      Text(user.email,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gym badge
        SurfaceCard(
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center, color: AppColors.lime, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Γυμναστήριο',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(config.appName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (user.bio != null && user.bio!.isNotEmpty) ...[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Βιογραφικό',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(user.bio!,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Actions
        SurfaceCard(
          child: Column(
            children: [
              _ActionRow(
                icon: Icons.logout,
                label: 'Αποσύνδεση',
                color: AppColors.orange,
                onTap: () => _logout(context, auth, config),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(config.appName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Future<void> _logout(BuildContext context, AuthService auth, TenantConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Αποσύνδεση;'),
        content: Text('Θα αποσυνδεθείς από το ${config.appName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Άκυρο')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('Αποσύνδεση'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PushService.instance.unregisterFromCurrentGym(auth);
    await auth.logout();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user.avatarUrl != null && (user.avatarUrl as String).isNotEmpty;
    final colorHex  = user.colorHex as String?;
    Color bg = AppColors.lime.withValues(alpha: 0.15);
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        bg = Color(int.parse(colorHex.replaceAll('#', '0xFF'))).withValues(alpha: 0.2);
      } catch (_) {}
    }

    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: hasAvatar
          ? ClipOval(child: Image.network(user.avatarUrl as String, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials(user.fullName as String)))
          : _initials(user.fullName as String),
    );
  }

  Widget _initials(String name) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w800, fontSize: 22),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right, color: c.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }
}
