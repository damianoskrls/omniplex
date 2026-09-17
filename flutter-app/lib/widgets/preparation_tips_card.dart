import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'ui_kit.dart';

class PreparationTipsCard extends StatelessWidget {
  const PreparationTipsCard({
    super.key,
    required this.tips,
    this.title = 'Προετοιμασία',
    this.icon = Icons.lightbulb_outline,
  });

  final List<String> tips;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.lime, size: 20),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(tip, style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
