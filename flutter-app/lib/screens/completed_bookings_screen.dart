import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import 'workout_complete_screen.dart';
import 'goals_screen.dart';

class CompletedBookingsScreen extends StatefulWidget {
  const CompletedBookingsScreen({super.key});

  @override
  State<CompletedBookingsScreen> createState() => _CompletedBookingsScreenState();
}

class _CompletedBookingsScreenState extends State<CompletedBookingsScreen> {
  List<Booking> _completed = [];
  List<Booking> _pendingConfirm = [];
  UserStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthService>().api;
      final results = await Future.wait([
        api.fetchMyBookings(),
        api.fetchMyStats(),
      ]);
      final bookings = results[0] as List<Booking>;
      setState(() {
        _pendingConfirm = bookings.where((b) => b.needsCheckIn).toList()
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
        _completed = bookings.where((b) => b.isCompleted && !b.needsCheckIn).toList()
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
        _stats = results[1] as UserStats;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openWorkoutComplete(Booking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(
          booking: booking,
          api: context.read<AuthService>().api,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).completedTitle),
      ),
      body: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: Text(AppStrings.of(context).retryBtn)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.lime,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (_stats != null) _KpiSection(stats: _stats!, totalCompleted: _completed.length),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(AppStrings.of(context).completedHistory, style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GoalsScreen()),
                            ),
                            child: Text(AppStrings.of(context).completedGoalsBtn),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_pendingConfirm.isNotEmpty) ...[
                        Text(AppStrings.of(context).completedPendingSection, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        ...List.generate(_pendingConfirm.length, (index) {
                          final booking = _pendingConfirm[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: index < _pendingConfirm.length - 1 ? 12 : 16),
                            child: _PendingConfirmCard(
                              booking: booking,
                              onConfirm: () => _openWorkoutComplete(booking),
                            ),
                          );
                        }),
                      ],
                      if (_completed.isEmpty && _pendingConfirm.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: EmptyState(
                            icon: Icons.check_circle_outline,
                            title: AppStrings.of(context).completedNoneTitle,
                            subtitle: AppStrings.of(context).completedNoneSubtitle,
                          ),
                        )
                      else if (_completed.isNotEmpty) ...[
                        if (_pendingConfirm.isNotEmpty)
                          Text(AppStrings.of(context).completedCompletedSection, style: Theme.of(context).textTheme.titleMedium),
                        if (_pendingConfirm.isNotEmpty) const SizedBox(height: 10),
                        ...List.generate(_completed.length, (index) {
                          final booking = _completed[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: index < _completed.length - 1 ? 12 : 0),
                            child: _CompletedCard(
                              booking: booking,
                              index: index,
                              onOpenTips: () => _openWorkoutComplete(booking),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.stats, required this.totalCompleted});

  final UserStats stats;
  final int totalCompleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.of(context).completedPerformance, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.fitness_center,
                color: AppColors.lime,
                value: '${stats.sessionsThisMonth}',
                label: AppStrings.of(context).completedThisMonth,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: Icons.flag_outlined,
                color: AppColors.purple,
                value: '${stats.goal.targetSessions}',
                label: AppStrings.of(context).completedMonthGoal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                icon: Icons.stars_rounded,
                color: AppColors.orange,
                value: '${stats.loyaltyPoints}',
                label: AppStrings.of(context).completedPoints,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.of(context).completedGoalProgress,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (stats.goalMet)
                    PillChip(
                      label: AppStrings.of(context).completedAchieved,
                      color: const Color(0x3322C55E),
                      textColor: AppColors.lime,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: stats.goalProgressPct / 100,
                  minHeight: 10,
                  backgroundColor: AppColors.border,
                  color: AppColors.lime,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.of(context).completedStats(stats.sessionsThisMonth, stats.goal.targetSessions, totalCompleted),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _PendingConfirmCard extends StatelessWidget {
  const _PendingConfirmCard({required this.booking, required this.onConfirm});

  final Booking booking;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final locale = LanguageService.instance.isGreek ? 'el_GR' : 'en_US';
    final dateFmt = DateFormat('EEE d MMM, HH:mm', locale);
    return SurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.serviceName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(dateFmt.format(booking.startsAt), style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                PillChip(
                  label: AppStrings.of(context).completedNoCheckin,
                  color: const Color(0x33F97316),
                  textColor: AppColors.orange,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onConfirm, child: Text(AppStrings.of(context).confirmAttendance)),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({
    required this.booking,
    required this.index,
    this.onOpenTips,
  });

  final Booking booking;
  final int index;
  final VoidCallback? onOpenTips;

  @override
  Widget build(BuildContext context) {
    final locale = LanguageService.instance.isGreek ? 'el_GR' : 'en_US';
    final dateFmt = DateFormat('EEE d MMM, HH:mm', locale);
    final accent = AppColors.cardGradient(index).first;

    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.serviceName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(dateFmt.format(booking.startsAt), style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                if (booking.staffName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(AppStrings.of(context).withStaff(booking.staffName), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    PillChip(
                      label: AppStrings.of(context).completedLabel,
                      color: const Color(0x3320B2AA),
                      textColor: AppColors.teal,
                    ),
                    if (booking.feedbackRating != null) ...[
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) {
                          return Icon(
                            i < booking.feedbackRating! ? Icons.star : Icons.star_border,
                            size: 16,
                            color: AppColors.orange,
                          );
                        }),
                      ),
                    ],
                  ],
                ),
                if (booking.feedbackNote != null && booking.feedbackNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    booking.feedbackNote!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
                if (onOpenTips != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onOpenTips,
                      child: Text(
                        booking.feedbackRating == null ? AppStrings.of(context).completedFeedbackBtn : AppStrings.of(context).completedViewTipsBtn,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
