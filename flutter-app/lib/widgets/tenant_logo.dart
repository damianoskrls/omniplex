import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';

class TenantLogo extends StatelessWidget {
  const TenantLogo({
    super.key,
    this.size = 72,
    this.borderRadius = 22,
    this.showShadow = true,
  });

  final double size;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final config     = context.read<TenantConfig>();
    final networkUrl = resolveMediaUrl(config, config.logoUrl);
    final primary    = _parseColor(config.primaryColor);

    Widget child = networkUrl != null
        ? Image.network(
            networkUrl,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallback(primary),
          )
        : _fallback(primary);

    if (showShadow) {
      child = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }

  Widget _fallback(Color primary) {
    // Show first letter of app name as generic logo
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(Icons.business_center_outlined, color: Colors.white, size: size * 0.45),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.purple;
    }
  }
}
