import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../models/booking.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import 'workout_programs_screen.dart';
import '../l10n/tr.dart';


const _kAccent = Color(0xFF7B3EAD);
const _kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF4452D8), Color(0xFF5D49C5), Color(0xFF7B3EAD),
    Color(0xFFA4308D), Color(0xFFC52473),
  ],
);

class GymDashboardScreen extends StatefulWidget {
  const GymDashboardScreen({super.key});

  @override
  State<GymDashboardScreen> createState() => _GymDashboardScreenState();
}

class _GymDashboardScreenState extends State<GymDashboardScreen> {
  List<Booking> _bookings = [];
  List<MembershipCredit> _credits = [];
  int _totalBalanceCents = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AuthService>().api;
      final config = context.read<TenantConfig>();

      final bookingsFuture = api.fetchMyBookings();
      final creditsFuture = api.fetchMyCredits();
      final bookings = await bookingsFuture;
      final credits = await creditsFuture;

      int debtCents = 0;
      if (config.featureOnlinePayments) {
        try {
          final payResult = await api.fetchMyPayments();
          debtCents = payResult.totalBalanceCents;
        } on ApiException catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _credits = credits;
        _totalBalanceCents = debtCents;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Booking? get _nextBooking {
    final now = DateTime.now();
    final upcoming = _bookings
        .where((b) => b.isUpcoming && !b.isNutritionConsultation)
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<MembershipCredit> get _gymCredits =>
      _credits.where((c) => !c.isNutritionProgram && !c.isNutritionConsultation).toList();

  int get _totalRemaining {
    int total = 0;
    for (final c in _gymCredits) {
      if (!c.isUnlimited) total += c.remaining;
    }
    return total;
  }

  bool get _hasUnlimited => _gymCredits.any((c) => c.isUnlimited);

  @override
  Widget build(BuildContext context) {
    final config = context.read<TenantConfig>();

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kAccent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(tr(_error!), style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: Text(tr('Δοκίμασε ξανά'))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kAccent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          _GymHeroCard(config: config),
          const SizedBox(height: 16),
          _NextWorkoutCard(booking: _nextBooking),
          const SizedBox(height: 16),
          SurfaceCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WorkoutProgramsScreen(serviceTitle: tr('Προπόνηση'))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tenantPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.playlist_play_rounded, color: context.tenantPrimary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Προγράμματα γυμναστικής'),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      SizedBox(height: 3),
                      Text(tr('Διάλεξε πρόγραμμα και σημείωσε κάθε άσκηση'),
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.fitness_center_outlined,
                  label: tr('Υπόλοιπο'),
                  value: _hasUnlimited ? '∞' : _gymCredits.isEmpty ? '—' : '$_totalRemaining',
                  subtitle: tr('συνεδρίες'),
                  gradient: _kBrandGradient,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _totalBalanceCents > 0
                    ? _StatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: tr('Οφειλή'),
                        value: '€${(_totalBalanceCents / 100).toStringAsFixed(0)}',
                        subtitle: tr('οφειλόμενο'),
                        color: AppColors.orange,
                      )
                    : _StatCard(
                        icon: Icons.check_circle_outline,
                        label: tr('Λογαριασμός'),
                        value: 'OK',
                        subtitle: tr('χωρίς οφειλές'),
                        color: AppColors.teal,
                      ),
              ),
            ],
          ),
          if (_gymCredits.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(tr('Ενεργά Πακέτα'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ..._gymCredits.take(4).map((c) => _PackageRow(credit: c)),
          ],
        ],
      ),
    );
  }
}

// ── Gym Hero Card ─────────────────────────────────────────────────────────────

class _GymHeroCard extends StatelessWidget {
  const _GymHeroCard({required this.config});
  final TenantConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _kBrandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4452D8).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(config.appName),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text(tr('Μέλος'),
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: Colors.greenAccent),
                SizedBox(width: 6),
                Text(tr('Ενεργό'),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Next Workout Card ─────────────────────────────────────────────────────────

class _NextWorkoutCard extends StatelessWidget {
  const _NextWorkoutCard({this.booking});
  final Booking? booking;

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isTomorrow(DateTime dt) {
    final t = DateTime.now().add(const Duration(days: 1));
    return dt.year == t.year && dt.month == t.month && dt.day == t.day;
  }

  @override
  Widget build(BuildContext context) {
    if (booking == null) {
      return SurfaceCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.event_available_outlined,
                  color: AppColors.textSecondary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Επόμενη Προπόνηση'),
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(tr('Δεν υπάρχει προγραμματισμένη κράτηση'),
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final locale = LanguageService.instance.isGreek ? 'el_GR' : 'en_US';
    final b = booking!;
    final String dayLabel;
    if (_isToday(b.startsAt)) {
      dayLabel = tr('Σήμερα');
    } else if (_isTomorrow(b.startsAt)) {
      dayLabel = tr('Αύριο');
    } else {
      dayLabel = DateFormat('EEEE d MMM', locale).format(b.startsAt);
    }
    final timeLabel = DateFormat('HH:mm', locale).format(b.startsAt);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.directions_run_rounded, color: _kAccent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Επόμενη Προπόνηση'),
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(tr(b.serviceName), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(tr('$dayLabel · $timeLabel'),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    if (b.staffName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(tr(b.staffName),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PillChip(
            label: tr(dayLabel == 'Σήμερα' ? 'Σήμερα' : tr('Επόμενο')),
            color: _kAccent.withValues(alpha: 0.15),
            textColor: _kAccent,
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.gradient,
    this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kAccent;
    final isGrad = gradient != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        color: isGrad ? null : c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: isGrad ? null : Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isGrad ? Colors.white : c),
          const SizedBox(height: 8),
          Text(tr(value),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: isGrad ? Colors.white : c,
                height: 1,
              )),
          const SizedBox(height: 3),
          Text(tr(subtitle),
              style: TextStyle(
                fontSize: 12,
                color: isGrad ? Colors.white70 : AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}

// ── Package Row ───────────────────────────────────────────────────────────────

class _PackageRow extends StatelessWidget {
  const _PackageRow({required this.credit});
  final MembershipCredit credit;

  @override
  Widget build(BuildContext context) {
    final title = credit.planName ?? credit.serviceName ?? tr('Πακέτο');
    final isUnlim = credit.isUnlimited;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.card_membership_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr(title),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(
              tr(isUnlim ? '∞' : '${credit.remaining} / ${credit.totalSessions}'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: _kAccent, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
