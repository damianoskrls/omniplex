import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({
    super.key,
    required this.title,
    this.body,
    this.imageUrl,
    this.when,
  });

  final String title;
  final String? body;
  final String? imageUrl;
  final DateTime? when;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Ειδοποίηση'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.lime,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: AppColors.surface,
                    child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Σύσπασε ή κάνε pinch για zoom',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          if (when != null) ...[
            const SizedBox(height: 8),
            Text(
              DateFormat('d MMMM yyyy, HH:mm', 'el_GR').format(when!),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ],
          if (body != null && body!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              body!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
