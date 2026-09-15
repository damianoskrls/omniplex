import 'package:flutter/material.dart';
import '../config/tenant_config.dart';
import '../models/booking.dart';

class StaffAvatar extends StatelessWidget {
  const StaffAvatar({
    super.key,
    required this.staff,
    required this.config,
    this.radius = 24,
  });

  final StaffMember staff;
  final TenantConfig config;
  final double radius;

  String? get _imageUrl {
    final path = staff.avatarUrl;
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${config.apiBaseUrl.replaceAll(RegExp(r'/$'), '')}$path';
  }

  @override
  Widget build(BuildContext context) {
    final color = staff.colorHex != null
        ? Color(int.parse('FF${staff.colorHex!.replaceAll('#', '')}', radix: 16))
        : Theme.of(context).colorScheme.primary;

    final imageUrl = _imageUrl;
    if (imageUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : '?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
      ),
    );
  }
}
