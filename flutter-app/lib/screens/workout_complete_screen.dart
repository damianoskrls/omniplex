import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../models/workout_share_details.dart';
import '../services/share_photo_service.dart';
import '../theme/app_colors.dart';
import '../widgets/preparation_tips_card.dart';
import '../widgets/ui_kit.dart';
import '../models/workout_health.dart';
import '../services/health_workout_service.dart';
import '../widgets/workout_health_panel.dart';
import '../widgets/workout_share_fullscreen.dart';
import 'home_screen.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  const WorkoutCompleteScreen({super.key, required this.booking, required this.api});

  final Booking booking;
  final ApiService api;

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  bool _attendedConfirmed = false;
  int _rating = 0;
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _error;
  List<String> _postTips = [];
  UserStats? _stats;
  File? _photoFile;
  bool _savingPhoto = false;
  final _shareService = SharePhotoService();
  final _picker = ImagePicker();

  bool _healthLoading = false;
  String? _healthError;
  List<WorkoutHealthSummary> _healthCandidates = [];
  WorkoutHealthSummary? _selectedHealth;
  bool _healthUnsupported = false;
  bool _healthPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _postTips = widget.booking.postWorkoutTips;
    _loadFresh();
    _syncHealthWorkouts();
  }

  Future<void> _syncHealthWorkouts() async {
    setState(() {
      _healthLoading = true;
      _healthError = null;
      _healthUnsupported = false;
      _healthPermissionDenied = false;
    });
    try {
      final result = await HealthWorkoutService.instance.loadForBooking(widget.booking);
      if (!mounted) return;
      setState(() {
        _healthCandidates = result.candidates;
        _selectedHealth = result.bestMatch;
        _healthUnsupported = result.unsupported;
        _healthPermissionDenied = result.permissionDenied;
      });
    } catch (e) {
      if (mounted) setState(() => _healthError = e.toString());
    } finally {
      if (mounted) setState(() => _healthLoading = false);
    }
  }

  Future<void> _loadFresh() async {
    try {
      final detail = await widget.api.fetchBookingDetail(widget.booking.id);
      final stats = await widget.api.fetchMyStats();
      if (mounted) {
        setState(() {
          _postTips = detail.postWorkoutTips;
          _stats = stats;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  WorkoutShareDetails _shareDetails(TenantConfig config) {
    return WorkoutShareDetails(
      gymName: config.appName,
      workoutTitle: widget.booking.scheduleLabel ?? widget.booking.serviceName,
      startsAt: widget.booking.startsAt,
      endsAt: widget.booking.endsAt,
      trainerName: widget.booking.staffName.isNotEmpty ? widget.booking.staffName : null,
      durationMins: widget.booking.durationMins,
      accentColorHex: config.primaryColor,
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    final config = context.read<TenantConfig>();
    final bytes = await picked.readAsBytes();
    final logoBytes = await _shareService.loadLogoBytes(
      logoUrl: config.logoUrl,
      apiBaseUrl: config.apiBaseUrl,
    );
    final watermarked = await _shareService.composeWorkoutShare(
      photoBytes: bytes,
      details: _shareDetails(config),
      logoBytes: logoBytes,
    );
    if (mounted && watermarked != null) {
      setState(() => _photoFile = watermarked);
    }
  }

  Future<void> _sharePhoto() async {
    if (_photoFile == null) return;
    Rect? origin;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    await _shareService.shareWorkoutPhoto(_photoFile!, sharePositionOrigin: origin);
  }

  Future<void> _savePhoto() async {
    if (_photoFile == null || _savingPhoto) return;
    setState(() => _savingPhoto = true);
    try {
      await _shareService.saveToGallery(_photoFile!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).workoutCompletePhotoSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).workoutCompletePhotoError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  void _openFullscreenPhoto() {
    if (_photoFile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutShareFullscreen(imageFile: _photoFile!),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_attendedConfirmed) {
      setState(() => _error = AppStrings.of(context).workoutCompleteRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.api.completeWorkout(
        bookingId: widget.booking.id,
        attended: true,
        rating: _rating > 0 ? _rating : null,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        healthWorkout: _selectedHealth?.toApiPayload(),
      );

      if (mounted) {
        final points = result['points_earned'] as int? ?? 0;
        final statsJson = result['stats'];
        if (statsJson is Map<String, dynamic>) {
          setState(() => _stats = UserStats.fromJson(statsJson));
        }

        await context.read<AuthService>().refreshUser();

        final msg = points > 0
            ? AppStrings.of(context).workoutCompleteConfirmedPoints(points)
            : (result['message'] as String? ?? AppStrings.of(context).workoutCompleteConfirmed);
        final health = result['health_workout'];
        final healthMsg = health is Map && health['calories_kcal'] != null
            ? AppStrings.of(context).workoutCompleteCaloriesFromWatch(health['calories_kcal'] as int)
            : '';

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg$healthMsg')));

        if (_photoFile != null) {
          await _sharePhoto();
        }

        final nav = appNavigatorKey.currentState ?? Navigator.of(context);
        nav.popUntil((route) => route.isFirst);
        HomeScreen.selectTab(1);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<TenantConfig>();
    final dateFmt = DateFormat('EEE d MMM, HH:mm', LanguageService.instance.isGreek ? 'el_GR' : 'en_US');
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(context).workoutCompleteTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GradientCard(
            colors: [AppColors.teal, AppColors.lime.withValues(alpha: 0.6)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.of(context).workoutCompleteQuestion,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.booking.scheduleLabel ?? widget.booking.serviceName,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
                Text(
                  dateFmt.format(widget.booking.startsAt),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          if (widget.booking.isInProgress) ...[
            const SizedBox(height: 12),
            SurfaceCard(
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.lime, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.of(context).workoutCompleteEarlyMsg,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SurfaceCard(
            child: CheckboxListTile(
              value: _attendedConfirmed,
              onChanged: widget.booking.isInProgress
                  ? null
                  : (v) => setState(() => _attendedConfirmed = v ?? false),
              title: Text(
                AppStrings.of(context).workoutCompleteCheckbox,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                widget.booking.isInProgress
                    ? AppStrings.of(context).workoutCompleteAfterEnd
                    : AppStrings.of(context).workoutCompleteRequired,
              ),
              activeColor: AppColors.lime,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),
          WorkoutHealthPanel(
            loading: _healthLoading,
            permissionDenied: _healthPermissionDenied,
            unsupported: _healthUnsupported,
            candidates: _healthCandidates,
            selected: _selectedHealth,
            error: _healthError,
            onSelect: (w) => setState(() => _selectedHealth = w),
            onSync: _syncHealthWorkouts,
          ),
          if (config.featureLoyaltyPoints && stats != null) ...[
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.of(context).workoutCompleteGoalTarget(stats.goal.targetSessions),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: stats.goalProgressPct / 100,
                      minHeight: 10,
                      backgroundColor: AppColors.border,
                      color: stats.goalMet ? AppColors.lime : AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.of(context).workoutCompleteSessions(stats.sessionsThisMonth, stats.goal.targetSessions),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (stats.goalMet)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        AppStrings.of(context).workoutCompleteGoalAchieved,
                        style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          PreparationTipsCard(
            tips: _postTips,
            title: AppStrings.of(context).workoutCompleteRecovery,
            icon: Icons.favorite_outline,
          ),
          const SizedBox(height: 24),
          Text(AppStrings.of(context).workoutCompleteHowWas, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.lime,
                  size: 36,
                ),
              );
            }),
          ),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: AppStrings.of(context).workoutCompleteComment,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.of(context).workoutCompletePhotoTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_photoFile != null) ...[
            WorkoutShareThumbnail(
              imageFile: _photoFile!,
              onTap: _openFullscreenPhoto,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(AppStrings.of(context).workoutCompleteCameraLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _photoFile != null && !_savingPhoto ? _savePhoto : null,
                  icon: _savingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(AppStrings.of(context).workoutCompleteSaveLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _photoFile != null ? _sharePhoto : null,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Instagram'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context).workoutCompletePhotoNote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.orange)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting || !_attendedConfirmed || widget.booking.isInProgress ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                    )
                  : Text(AppStrings.of(context).workoutCompleteBtn),
            ),
          ),
        ],
      ),
    );
  }
}
