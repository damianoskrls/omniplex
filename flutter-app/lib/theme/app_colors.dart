import 'package:flutter/material.dart';

class AppColors {
  // Static dark-theme neutrals — never change per tenant
  static const bg           = Color(0xFF0F0F12);
  static const surface      = Color(0xFF1A1A22);
  static const surfaceLight = Color(0xFF242430);
  static const border       = Color(0xFF2E2E3A);
  static const textPrimary  = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9CA3AF);

  // Fixed palette colors used for gradients / variety
  static const purple = Color(0xFF7C5CFC);
  static const orange = Color(0xFFFF8A4C);
  static const teal   = Color(0xFF4FD1C5);
  static const pink   = Color(0xFFFF6B9D);

  // Default primary — updated at app startup from tenant config
  // All 300+ references to AppColors.lime automatically use the tenant color
  static Color _lime = const Color(0xFFB8F55E);
  static Color get lime => _lime;
  static void setTenantPrimary(Color color) { _lime = color; }

  static const cardGradients = [
    [Color(0xFF5B4FCF), Color(0xFF7C5CFC)],
    [Color(0xFFE86A3A), Color(0xFFFF8A4C)],
    [Color(0xFF2A9D8F), Color(0xFF4FD1C5)],
    [Color(0xFFD63384), Color(0xFFFF6B9D)],
  ];

  static List<Color> cardGradient(int index) {
    final pair = cardGradients[index % cardGradients.length];
    return pair;
  }

  static Color fromHex(String hex) {
    final h = hex.trim().replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    if (h.length == 8) return Color(int.parse(h, radix: 16));
    return lime;
  }
}

/// InheritedWidget that carries the tenant's runtime primary color
/// so widgets can read it via context.tenantPrimary without Provider.
class AppColorsTheme extends InheritedWidget {
  const AppColorsTheme({
    super.key,
    required this.primary,
    required this.accent,
    required super.child,
  });

  final Color primary;
  final Color accent;

  static AppColorsTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppColorsTheme>();

  @override
  bool updateShouldNotify(AppColorsTheme old) =>
      primary != old.primary || accent != old.accent;
}

extension TenantColors on BuildContext {
  /// The tenant's primary brand color (replaces AppColors.lime in most places)
  Color get tenantPrimary {
    return AppColorsTheme.maybeOf(this)?.primary ?? AppColors.lime;
  }

  /// The tenant's accent color
  Color get tenantAccent {
    return AppColorsTheme.maybeOf(this)?.accent ?? AppColors.purple;
  }
}
