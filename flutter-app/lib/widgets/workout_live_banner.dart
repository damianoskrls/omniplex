import 'dart:async';
import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/health_workout_service.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

// Shows live HR + calories during an in-progress booking.
// Polls Health every 30 seconds. Disappears when the booking ends.
class WorkoutLiveBanner extends StatefulWidget {
  const WorkoutLiveBanner({super.key, required this.booking});

  final Booking booking;

  @override
  State<WorkoutLiveBanner> createState() => _WorkoutLiveBannerState();
}

class _WorkoutLiveBannerState extends State<WorkoutLiveBanner> {
  Timer? _timer;
  int? _calories;
  int? _heartRate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final from = widget.booking.startsAt;
    final to = DateTime.now();
    if (!to.isAfter(from)) return;
    final result = await HealthWorkoutService.instance.loadWindow(from, to);
    if (mounted) {
      setState(() {
        _calories = result.calories ?? _calories;
        _heartRate = result.avgHeartRate ?? _heartRate;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _calories != null || _heartRate != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D2C12), Color(0xFF162412)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fitness_center, color: AppColors.lime, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('Σε εξέλιξη'),
                      style: const TextStyle(color: AppColors.lime, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tr(widget.booking.serviceName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
          if (_loading && !hasData)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime),
            )
          else if (hasData)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_heartRate != null) ...[
                  const Icon(Icons.favorite, color: Color(0xFFFF6B6B), size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '$_heartRate',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(width: 2),
                  const Text('bpm', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(width: 10),
                ],
                if (_calories != null) ...[
                  const Icon(Icons.local_fire_department, color: Color(0xFFFF9B3B), size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '$_calories',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(width: 2),
                  const Text('kcal', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
