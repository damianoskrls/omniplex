import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import 'tenant_logo.dart';

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.greeting,
    required this.name,
    this.subtitle,
    this.avatarLetter,
    this.onAvatarTap,
    this.onNotificationsTap,
    this.onMessagesTap,
    this.onCheckinTap,
    this.onLogoTap,
    this.onSwitchGym,
    this.notificationCount = 0,
    this.messageCount = 0,
  });

  final String greeting;
  final String name;
  final String? subtitle;
  final String? avatarLetter;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onMessagesTap;
  final VoidCallback? onCheckinTap;
  final VoidCallback? onLogoTap;
  final VoidCallback? onSwitchGym;
  final int notificationCount;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Omniplex back chip (only when coming from Omniplex)
          if (onSwitchGym != null)
            GestureDetector(
              onTap: onSwitchGym,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textSecondary, size: 12),
                    const SizedBox(width: 6),
                    SvgPicture.asset(
                      'assets/icons/omniplex_icon.svg',
                      width: 14, height: 14,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Omniplex',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Row 1: gym logo (left) + action icons + avatar (right)
          Row(
            children: [
              // Gym logo — tappable
              GestureDetector(
                onTap: onLogoTap,
                child: const TenantLogo(size: 40, borderRadius: 12, showShadow: false),
              ),
              const Spacer(),
              // Action icons row
              if (onCheckinTap != null)
                _HeaderIconButton(
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: onCheckinTap!,
                ),
              if (onCheckinTap != null) const SizedBox(width: 8),
              if (onMessagesTap != null)
                _HeaderIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: onMessagesTap!,
                  badgeCount: messageCount,
                ),
              if (onMessagesTap != null) const SizedBox(width: 8),
              if (onNotificationsTap != null)
                _HeaderIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: onNotificationsTap!,
                  badgeCount: notificationCount,
                ),
              if (onNotificationsTap != null) const SizedBox(width: 8),
              // Avatar
              if (avatarLetter != null)
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.purple, AppColors.pink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      avatarLetter!.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderLogoButton extends StatelessWidget {
  const _HeaderLogoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(6),
        child: const TenantLogo(size: 32, borderRadius: 10, showShadow: false),
      ),
    );
  }
}

class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor ?? Colors.white),
      ),
    );
  }
}

class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.colors,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });

  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  BoxDecoration get _decoration => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Container(
        decoration: _decoration,
        padding: padding,
        child: child,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: _decoration,
        padding: padding,
        child: child,
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
    this.centerAction,
    this.centerIcon = Icons.qr_code_2_rounded,
    this.centerColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;
  final VoidCallback? centerAction;
  final IconData centerIcon;
  final Color? centerColor;

  Widget _buildTab(BuildContext context, int i, FloatingNavItem item) {
    final selected = i == selectedIndex;
    final primary = context.tenantPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(item.icon, size: 22, color: selected ? primary : AppColors.textSecondary),
                  if (item.badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.tenantPrimary;
    final accentColor = centerColor ?? primary;
    if (centerAction != null && items.length >= 2) {
      final mid = items.length ~/ 2;
      final leftItems  = items.sublist(0, mid);
      final rightItems = items.sublist(mid);
      final leftOffset  = 0;
      final rightOffset = mid;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              ...leftItems.asMap().entries.map((e) => _buildTab(context, leftOffset + e.key, e.value)),
              // Center QR button — gradient pill
              GestureDetector(
                onTap: centerAction,
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(centerIcon, color: Colors.white, size: 28),
                ),
              ),
              ...rightItems.asMap().entries.map((e) => _buildTab(context, rightOffset + e.key, e.value)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) => _buildTab(context, i, items[i])),
        ),
      ),
    );
  }
}

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });
  final IconData icon;
  final String label;
  final int badgeCount;
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 40, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

String greetingForHour() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Καλημέρα';
  if (h < 18) return 'Καλησπέρα';
  return 'Καληνύχτα';
}
