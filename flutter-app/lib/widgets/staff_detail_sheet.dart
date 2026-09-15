import 'package:flutter/material.dart';
import '../config/tenant_config.dart';
import '../models/booking.dart';
import '../theme/app_colors.dart';
import 'staff_avatar.dart';
import 'ui_kit.dart';

Future<void> showStaffDetailSheet(
  BuildContext context, {
  required StaffMember staff,
  required TenantConfig config,
  bool canSelect = false,
  bool isSelected = false,
  VoidCallback? onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final imageUrl = _staffImageUrl(staff, config);

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openStaffPhotoFullscreen(ctx, staff: staff, config: config, imageUrl: imageUrl),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      if (imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 280,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _LargeAvatarFallback(staff: staff, config: config),
                          ),
                        )
                      else
                        _LargeAvatarFallback(staff: staff, config: config),
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_out_map, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Μεγέθυνση', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  staff.fullName,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.headlineMedium,
                ),
                if (staff.role != null) ...[
                  const SizedBox(height: 6),
                  PillChip(label: staff.role!, color: AppColors.purple.withValues(alpha: 0.2), textColor: AppColors.purple),
                ],
                if (staff.bio != null && staff.bio!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Σχετικά', style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    staff.bio!,
                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    'Δεν υπάρχει διαθέσιμη περιγραφή.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
                if (canSelect) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        onSelect?.call();
                        Navigator.pop(ctx);
                      },
                      child: Text(isSelected ? 'Επιλεγμένος' : 'Επιλογή γυμναστή'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _openStaffPhotoFullscreen(
  BuildContext context, {
  required StaffMember staff,
  required TenantConfig config,
  String? imageUrl,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _LargeAvatarFallback(staff: staff, config: config, height: 320),
                      )
                    : _LargeAvatarFallback(staff: staff, config: config, height: 320),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              staff.fullName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    },
  );
}

String? _staffImageUrl(StaffMember staff, TenantConfig config) {
  final path = staff.avatarUrl;
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return '${config.apiBaseUrl.replaceAll(RegExp(r'/$'), '')}$path';
}

class _LargeAvatarFallback extends StatelessWidget {
  const _LargeAvatarFallback({
    required this.staff,
    required this.config,
    this.height = 280,
  });

  final StaffMember staff;
  final TenantConfig config;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.4),
            AppColors.pink.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: StaffAvatar(staff: staff, config: config, radius: 64),
    );
  }
}
