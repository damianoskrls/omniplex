import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../models/service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/slot_visual.dart';
import '../widgets/ui_kit.dart';
import 'booking_flow_screen.dart';
import 'nutrition_consultation_booking_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<BookService> _services = [];
  bool _loading = true;
  String? _error;
  bool _nutritionConsultCanBook = false;
  BookService? _nutritionConsultService;
  Map<String, dynamic> _nutritionCredits = {};
  Map<String, dynamic>? _nutritionPendingBooking;
  Map<String, dynamic>? _nutritionUpcomingBooking;
  List<Map<String, dynamic>> _nutritionists = [];
  bool _needsNutritionistChoice = false;
  bool _hasNutritionAccess = false;

  bool get _showNutritionCard =>
      _nutritionConsultService != null
      && (_hasNutritionAccess
          || _nutritionCredits['has_access'] == true
          || _nutritionConsultCanBook
          || _nutritionPendingBooking != null
          || _nutritionUpcomingBooking != null);

  int get _bookableCount {
    var count = _services.where((s) => s.canBook).length;
    if (_nutritionConsultCanBook) count += 1;
    return count;
  }

  int get _activeCount {
    var count = _services.length;
    if (_showNutritionCard) count += 1;
    return count;
  }
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
      final config = context.read<TenantConfig>();
      final services = await api.fetchServices();
      var consultCanBook = false;
      BookService? consultService;
      Map<String, dynamic> credits = {};
      Map<String, dynamic>? pendingBooking;
      Map<String, dynamic>? upcomingBooking;
      List<Map<String, dynamic>> nutritionists = [];
      var needsNutritionistChoice = false;
      var hasNutritionAccess = false;
      if (config.featureNutrition) {
        try {
          hasNutritionAccess = await api.fetchNutritionAccess();
          final consult = await api.fetchNutritionConsultation();
          consultCanBook = consult.canBook;
          consultService = consult.service;
          credits = consult.credits;
          pendingBooking = consult.pendingBooking;
          upcomingBooking = consult.upcomingBooking;
          nutritionists = consult.nutritionists;
          needsNutritionistChoice = consult.needsNutritionistChoice;
        } on ApiException catch (_) {}
      }
      setState(() {
        _services = services;
        _nutritionConsultCanBook = consultCanBook;
        _nutritionConsultService = consultService;
        _nutritionCredits = credits;
        _nutritionPendingBooking = pendingBooking;
        _nutritionUpcomingBooking = upcomingBooking;
        _nutritionists = nutritionists;
        _needsNutritionistChoice = needsNutritionistChoice;
        _hasNutritionAccess = hasNutritionAccess;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _creditsLabel(BookService service) {
    final s = AppStrings.of(context);
    if (service.isUnlimited) return s.servicesUnlimited;
    if (!service.canBook) return s.servicesNoCredits;
    return s.servicesCredits(service.creditsRemaining);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: const CircularProgressIndicator(color: AppColors.lime));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: Text(AppStrings.of(context).retryBtn)),
          ],
        ),
      );
    }

    if (_services.isEmpty && !_showNutritionCard) {
      return EmptyState(
        icon: Icons.card_membership_outlined,
        title: AppStrings.of(context).servicesNoPackages,
        subtitle: AppStrings.of(context).servicesNoPackagesSub,
      );
    }

    final config = context.read<TenantConfig>();

    return RefreshIndicator(
      color: AppColors.lime,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (_showNutritionCard) ...[
            GradientCard(
              colors: const [Color(0xFF0f766e), Color(0xFF134e4a)],
              onTap: (_nutritionConsultCanBook || _nutritionPendingBooking != null || _nutritionUpcomingBooking != null)
                  ? () async {
                      final booked = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NutritionConsultationBookingScreen(
                            service: _nutritionConsultService!,
                            credits: _nutritionCredits,
                            pendingBooking: _nutritionPendingBooking,
                            upcomingBooking: _nutritionUpcomingBooking,
                            nutritionists: _nutritionists,
                            needsNutritionistChoice: _needsNutritionistChoice,
                          ),
                        ),
                      );
                      if (booked == true) _load();
                    }
                  : null,
              child: Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nutritionConsultService!.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        Text(
                          _nutritionPendingBooking != null
                              ? AppStrings.of(context).servicesPendingNutrition
                              : _nutritionUpcomingBooking != null
                                  ? AppStrings.of(context).servicesConfirmedNutrition
                                  : _nutritionConsultCanBook
                                  ? _nutritionConsultService!.isUnlimited
                                      ? AppStrings.of(context).servicesUnlimitedNutrition
                                      : AppStrings.of(context).servicesNutritionCredits(_nutritionCredits['remaining'] ?? 0)
                                  : _nutritionCredits['has_access'] == true
                                      ? AppStrings.of(context).servicesNoNutritionist
                                      : AppStrings.of(context).servicesContactForVisits,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (_nutritionConsultCanBook || _nutritionPendingBooking != null || _nutritionUpcomingBooking != null)
                    const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...List.generate(_services.length, (index) {
            final service = _services[index];
            final renewal = service.creditsValidUntil != null
                ? DateFormat('d MMM yyyy', LanguageService.instance.isGreek ? 'el_GR' : 'en_US').format(service.creditsValidUntil!)
                : null;
            final colors = AppColors.cardGradient(index);

            return Padding(
              padding: EdgeInsets.only(bottom: index < _services.length - 1 ? 14 : 0),
              child: GradientCard(
                colors: service.canBook ? colors : [AppColors.surfaceLight, AppColors.surface],
                onTap: service.canBook
                    ? () async {
                        final booked = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => BookingFlowScreen(service: service)),
                        );
                        if (booked == true) _load();
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (service.imageUrl != null) ...[
                      ServiceImage(
                        config: config,
                        imageUrl: service.imageUrl,
                        height: 110,
                        borderRadius: 16,
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: service.canBook ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: service.canBook ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${service.durationMins}\'',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: service.canBook ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (service.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        service.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: service.canBook ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (service.category != null) PillChip(label: service.category!),
                        PillChip(
                          label: _creditsLabel(service),
                          color: service.canBook
                              ? AppColors.lime.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                          textColor: service.canBook ? AppColors.lime : AppColors.textSecondary,
                        ),
                      ],
                    ),
                    if (renewal != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.autorenew,
                            size: 14,
                            color: service.canBook ? Colors.white70 : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.of(context).servicesRenewal(renewal),
                            style: TextStyle(
                              fontSize: 12,
                              color: service.canBook ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (service.canBook) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            AppStrings.of(context).servicesBook,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.lime),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16, color: AppColors.lime.withValues(alpha: 0.9)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
