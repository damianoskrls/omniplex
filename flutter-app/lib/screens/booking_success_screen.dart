import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app.dart';
import '../theme/app_colors.dart';
import '../widgets/preparation_tips_card.dart';
import '../widgets/ui_kit.dart';
import 'home_screen.dart';

class BookingSuccessScreen extends StatefulWidget {
  const BookingSuccessScreen({
    super.key,
    required this.serviceName,
    required this.date,
    required this.time,
    this.staffName,
    this.preparationTips = const [],
  });

  final String serviceName;
  final DateTime date;
  final String time;
  final String? staffName;
  final List<String> preparationTips;

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> with TickerProviderStateMixin {
  late final AnimationController _main;
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  late final Animation<double> _check;
  bool _navigated = false;
  Timer? _autoNavTimer;

  static const _autoNavDelay = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _main = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

    _scale = CurvedAnimation(parent: _main, curve: const Interval(0, 0.55, curve: Curves.elasticOut));
    _check = CurvedAnimation(parent: _main, curve: const Interval(0.35, 0.75, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _main, curve: const Interval(0.45, 1, curve: Curves.easeOut));
    _slide = CurvedAnimation(parent: _main, curve: const Interval(0.5, 1, curve: Curves.easeOutCubic));

    _main.forward();
    _autoNavTimer = Timer(_autoNavDelay, _goToBookings);
  }

  void _goToBookings() {
    if (!mounted || _navigated) return;
    _autoNavTimer?.cancel();
    _navigated = true;
    final nav = appNavigatorKey.currentState ?? Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    HomeScreen.selectTab(1);
  }

  @override
  void dispose() {
    _autoNavTimer?.cancel();
    _main.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE d MMMM', 'el_GR').format(widget.date);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1035), AppColors.bg, Color(0xFF102A1E)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ...List.generate(12, (i) => _FloatingParticle(index: i, controller: _pulse)),
              SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      ScaleTransition(
                        scale: _scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, _) => Container(
                                width: 140 + math.sin(_pulse.value * math.pi * 2) * 8,
                                height: 140 + math.sin(_pulse.value * math.pi * 2) * 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.lime.withValues(alpha: 0.25), width: 2),
                                ),
                              ),
                            ),
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.lime, Color(0xFF8AE62E)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.lime.withValues(alpha: 0.45),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: FadeTransition(
                                opacity: _check,
                                child: ScaleTransition(
                                  scale: _check,
                                  child: const Icon(Icons.check_rounded, size: 64, color: AppColors.bg),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(_slide),
                          child: Column(
                            children: [
                              Text(
                                'Η κράτηση ολοκληρώθηκε!',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Το ραντεβού σου καταχωρήθηκε με επιτυχία.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 28),
                              SurfaceCard(
                                child: Column(
                                  children: [
                                    Text(
                                      widget.serviceName,
                                      style: Theme.of(context).textTheme.titleLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 14),
                                    _SummaryRow(icon: Icons.calendar_today, label: dateLabel),
                                    const SizedBox(height: 8),
                                    _SummaryRow(icon: Icons.schedule, label: widget.time),
                                    if (widget.staffName != null && widget.staffName!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _SummaryRow(icon: Icons.person_outline, label: widget.staffName!),
                                    ],
                                  ],
                                ),
                              ),
                              if (widget.preparationTips.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                PreparationTipsCard(tips: widget.preparationTips),
                              ],
                              const SizedBox(height: 28),
                              Text(
                                'Θα μεταφερθείς στις κρατήσεις σου σε λίγα δευτερόλεπτα',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _goToBookings,
                                  child: const Text('Δες τις κρατήσεις μου'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.lime),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}

class _FloatingParticle extends StatelessWidget {
  const _FloatingParticle({required this.index, required this.controller});
  final int index;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.lime, AppColors.purple, AppColors.teal, AppColors.orange, AppColors.pink];
    final color = colors[index % colors.length];
    final size = 6.0 + (index % 4) * 3;
    final top = 40.0 + (index * 47) % 520;
    final left = 20.0 + (index * 73) % 300;

    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = (controller.value + index * 0.08) % 1.0;
        final dy = math.sin(t * math.pi * 2) * 18;
        final opacity = 0.15 + math.sin(t * math.pi * 2).abs() * 0.35;
        return Positioned(
          top: top + dy,
          left: left,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: opacity * 0.8), blurRadius: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
