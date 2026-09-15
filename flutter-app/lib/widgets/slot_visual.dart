import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/tenant_config.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';

class AnimatedSlotIcon extends StatefulWidget {
  const AnimatedSlotIcon({super.key, required this.iconKey, this.size = 44, this.color = AppColors.lime});

  final String iconKey;
  final double size;
  final Color color;

  @override
  State<AnimatedSlotIcon> createState() => _AnimatedSlotIconState();
}

class _AnimatedSlotIconState extends State<AnimatedSlotIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.08).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _iconAsset(widget.iconKey);
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: EdgeInsets.all(widget.size * 0.18),
        child: SvgPicture.asset(asset, colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn)),
      ),
    );
  }

  String _iconAsset(String key) {
    const icons = {
      'cross_training': 'assets/icons/cross_training.svg',
      'crossfit':       'assets/icons/cross_training.svg',
      'strength':       'assets/icons/strength.svg',
      'trx':            'assets/icons/trx.svg',
      'pilates':        'assets/icons/pilates.svg',
      'yoga':           'assets/icons/yoga.svg',
      'cycling':        'assets/icons/cycling.svg',
      'hiit':           'assets/icons/hiit.svg',
      'stretching':     'assets/icons/stretching.svg',
      'boxing':         'assets/icons/hiit.svg',
      'swimming':       'assets/icons/stretching.svg',
      'running':        'assets/icons/cross_training.svg',
    };
    return icons[key] ?? 'assets/icons/fitness.svg';
  }
}

class SlotVisual extends StatelessWidget {
  const SlotVisual({
    super.key,
    required this.config,
    this.imageUrl,
    this.iconKey,
    this.size = 52,
  });

  final TenantConfig config;
  final String? imageUrl;
  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(config, imageUrl);
    if (resolved != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          resolved,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    if (iconKey != null && iconKey!.isNotEmpty) {
      return AnimatedSlotIcon(iconKey: iconKey!, size: size);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.schedule, color: AppColors.purple),
    );
  }
}

class ServiceImage extends StatelessWidget {
  const ServiceImage({
    super.key,
    required this.config,
    this.imageUrl,
    this.height = 120,
    this.borderRadius = 20,
    this.fallbackIcon = Icons.fitness_center,
  });

  final TenantConfig config;
  final String? imageUrl;
  final double height;
  final double borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(config, imageUrl);
    if (resolved == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.purple.withValues(alpha: 0.3), AppColors.pink.withValues(alpha: 0.2)]),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(fallbackIcon, size: height * 0.35, color: Colors.white54),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        resolved,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: height,
          color: AppColors.surfaceLight,
          child: Icon(fallbackIcon, size: 40, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
