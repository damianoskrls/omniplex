import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../models/workout_share_details.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/health_workout_service.dart';
import '../services/share_photo_service.dart';
import '../theme/app_colors.dart';
import '../widgets/workout_share_fullscreen.dart';
import '../l10n/tr.dart';


bool _isVideoUrl(String? url) {
  if (url == null) return false;
  final lower = url.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.mov') ||
         lower.endsWith('.webm') || lower.endsWith('.avi');
}

/// Replaces localhost/127.0.0.1 in stored URLs with the actual server base URL.
String _resolveMediaUrl(String url, String apiBase) {
  final base = apiBase.replaceAll(RegExp(r'/$'), '');
  // Extract just the origin (scheme+host+port) from base
  final baseUri = Uri.tryParse(base);
  if (baseUri == null) return url;
  final serverOrigin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';

  // Replace any localhost/127.0.0.1 origin
  return url
    .replaceFirst(RegExp(r'http://localhost(:\d+)?'), serverOrigin)
    .replaceFirst(RegExp(r'http://127\.0\.0\.1(:\d+)?'), serverOrigin);
}

/// Thumbnail: shows first frame of video or image. Tappable to open full player.
class _MediaThumb extends StatefulWidget {
  const _MediaThumb({required this.url, this.size = 56});
  final String url;
  final double size;
  @override
  State<_MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends State<_MediaThumb> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (_isVideoUrl(widget.url)) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() => _initialized = true);
        });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideoUrl(widget.url)) {
      return Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_initialized && _ctrl != null)
              SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(
                width: _ctrl!.value.size.width,
                height: _ctrl!.value.size.height,
                child: VideoPlayer(_ctrl!),
              )))
            else
              const Icon(Icons.play_circle_fill, color: Colors.white54, size: 28),
            const Icon(Icons.play_circle_fill, color: Colors.white54, size: 22),
          ],
        ),
      );
    }
    return Container(
      width: widget.size, height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Image.network(widget.url, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: AppColors.textSecondary, size: 28)),
    );
  }
}

/// Full-size media. Video starts only after a tap and stops when disposed.
class _MediaFull extends StatefulWidget {
  const _MediaFull({super.key, required this.url, this.poster, this.paused = false});
  final String url;
  final String? poster;
  final bool paused;
  @override
  State<_MediaFull> createState() => _MediaFullState();
}

class _MediaFullState extends State<_MediaFull> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _open(widget.url);
  }

  Future<void> _open(String url) async {
    if (!_isVideoUrl(url)) return;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.seekTo(Duration.zero);
      await ctrl.pause();
      if (!mounted || _ctrl != ctrl) {
        await ctrl.dispose();
        return;
      }
      setState(() => _ready = true);
    } catch (_) {
      if (mounted && _ctrl == ctrl) setState(() => _ready = false);
    }
  }

  @override
  void didUpdateWidget(_MediaFull oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && _ctrl?.value.isPlaying == true) {
      _ctrl?.pause();
    }
    if (oldWidget.url != widget.url) {
      _ctrl?.pause();
      _ctrl?.dispose();
      _ctrl = null;
      _ready = false;
      _open(widget.url);
    }
  }

  Future<void> _toggle() async {
    final ctrl = _ctrl;
    if (ctrl == null || !_ready) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
    } else if (!widget.paused) {
      await ctrl.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.pause();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideoUrl(widget.url)) {
      final playing = _ctrl?.value.isPlaying == true;
      return GestureDetector(
        onTap: _toggle,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity, height: 220, color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_ready && _ctrl != null)
                  FittedBox(fit: BoxFit.contain, child: SizedBox(
                    width: _ctrl!.value.size.width,
                    height: _ctrl!.value.size.height,
                    child: VideoPlayer(_ctrl!),
                  ))
                else if (widget.poster != null)
                  Image.network(widget.poster!, width: double.infinity, height: 220, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const CircularProgressIndicator(color: Colors.white))
                else
                  const CircularProgressIndicator(color: Colors.white),
                if ((_ready && !playing) || (!_ready && widget.poster != null))
                  const Icon(Icons.play_circle_fill, color: Colors.white70, size: 64),
              ],
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity, height: 220,
        child: Image.network(widget.url, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surfaceLight,
            child: const Icon(Icons.fitness_center, size: 64, color: AppColors.textSecondary),
          )),
      ),
    );
  }
}

class WorkoutProgramsScreen extends StatefulWidget {
  const WorkoutProgramsScreen({super.key, this.serviceId, this.serviceTitle});
  final String? serviceId;
  final String? serviceTitle;

  @override
  State<WorkoutProgramsScreen> createState() => _WorkoutProgramsScreenState();
}

bool _programMatchesService(Map<String, dynamic> program, String? serviceId) {
  if (serviceId == null) return true;
  if (program['service_id'] == serviceId) return true;
  final extra = program['service_ids'];
  if (extra is List) {
    for (final id in extra) {
      if (id == serviceId) return true;
    }
  }
  return false;
}

List<Map<String, dynamic>> _mergePrograms(List<Map<String, dynamic>> rows) {
  final byId = <String, Map<String, dynamic>>{};
  final order = <String>[];
  for (final row in rows) {
    final id = row['program_id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final name = row['service_name']?.toString();
    final existing = byId[id];
    if (existing == null) {
      final copy = Map<String, dynamic>.from(row);
      copy['service_names'] = name == null || name.isEmpty ? <String>[] : <String>[name];
      byId[id] = copy;
      order.add(id);
    } else if (name != null && name.isNotEmpty) {
      final names = (existing['service_names'] as List).cast<String>();
      if (!names.contains(name)) names.add(name);
    }
  }
  return order.map((id) => byId[id]!).toList();
}

Set<String> _doneIds(Map<String, dynamic> program) {
  final raw = program['done_exercise_ids'];
  if (raw is! List) return {};
  return raw.map((e) => e.toString()).toSet();
}

String? _field(Map<String, dynamic> program, String key) {
  final value = program[key]?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

int? _difficultyOf(Map<String, dynamic> program) {
  final raw = program['difficulty'];
  final n = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  if (n == null || n < 1 || n > 5) return null;
  return n;
}

String? _programImage(BuildContext context, Map<String, dynamic> program) {
  final raw = _field(program, 'image_url');
  if (raw == null) return null;
  return _resolveMediaUrl(raw, context.read<AuthService>().api.config.apiBaseUrl);
}

List<Map<String, dynamic>> _exercisesOf(Map<String, dynamic> program) {
  return (program['exercises'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      [];
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

String _formatSecs(int s) {
  final minutes = s ~/ 60;
  final seconds = s % 60;
  if (minutes > 0 && seconds == 0) return "$minutes'";
  if (minutes > 0) return "$minutes:${seconds.toString().padLeft(2, '0')}";
  return '$seconds"';
}

String _clock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

class _WorkoutProgramsScreenState extends State<WorkoutProgramsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _programs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final userId = auth.user?.id;
    if (userId == null) {
      setState(() { _loading = false; _error = AppStrings.of(context).programsUserNotFound; });
      return;
    }
    try {
      final all = await auth.api.fetchMyPrograms(userId);
      final filtered = (widget.serviceId != null
          ? all.where((p) => _programMatchesService(p, widget.serviceId)).toList()
          : all).where((p) {
            final cat = p['service_category']?.toString();
            return cat != 'nutrition' && cat != 'nutrition_consultation';
          }).toList();
      if (mounted) setState(() { _programs = _mergePrograms(filtered); _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e is ApiException ? e.message : tr('Δεν φορτώθηκαν τα προγράμματα');
        _loading = false;
      });
    }
  }

  Future<void> _openProgram(Map<String, dynamic> program, {bool fromStart = false}) async {
    if (fromStart) {
      final userId = context.read<AuthService>().user?.id;
      final programId = program['program_id']?.toString();
      if (userId == null || programId == null) return;
      try {
        await context.read<AuthService>().api.resetProgramSession(userId, programId);
        program['done_exercise_ids'] = <String>[];
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
        return;
      }
    }
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => WorkoutSessionScreen(program: program)),
    );
    if (changed == true && mounted) {
      setState(() { _loading = true; _error = null; });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.serviceTitle;
    if (title != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border),
          ),
        ),
        body: _buildBody(context),
      );
    }
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.lime,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        setState(() { _loading = true; _error = null; });
        await _load();
      },
      child: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? _ErrorView(message: tr(_error!), onRetry: () {
                  setState(() { _loading = true; _error = null; });
                  _load();
                })
              : _programs.isEmpty
                  ? _EmptyView()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: _programs.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              tr(widget.serviceTitle == null
                                  ? 'Διάλεξε πρόγραμμα από τις υπηρεσίες σου'
                                  : tr('Προγράμματα για ${widget.serviceTitle}')),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          );
                        }
                        final program = _programs[i - 1];
                        return _ProgramPickCard(
                          program: program,
                          onOpen: () => _openProgram(program),
                          onRestart: () => _openProgram(program, fromStart: true),
                        );
                      },
                    ),
    );
  }
}

class _ProgramPickCard extends StatelessWidget {
  const _ProgramPickCard({required this.program, required this.onOpen, required this.onRestart});
  final Map<String, dynamic> program;
  final VoidCallback onOpen;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final name = program['program_name'] as String? ?? s.programsDefaultName;
    final exercises = _exercisesOf(program);
    final done = _doneIds(program).length;
    final total = exercises.length;
    final finished = total > 0 && done >= total;
    final names = (program['service_names'] as List?)?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() ?? [];
    final primary = context.tenantPrimary;
    final partial = done > 0 && !finished;
    final label = finished ? 'Ολοκληρώθηκε' : (partial ? 'Συνέχισε' : tr('Ξεκίνα'));
    final image = _programImage(context, program);
    final description = _field(program, 'program_description');
    final focus = _field(program, 'focus');
    final difficulty = _difficultyOf(program);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            Image.network(
              image,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: partial ? null : onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (names.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(tr(names.join(' · ')), style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  Text(tr(name), style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                  if (difficulty != null || focus != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (difficulty != null)
                          _MetaChip(label: tr('Δυσκολία $difficulty/5'), color: primary),
                        if (focus != null)
                          _MetaChip(label: tr(focus), color: primary),
                      ],
                    ),
                  ],
                  if (description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr(description),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.35, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(tr(total == 0 ? 'Χωρίς ασκήσεις' : tr('$done από $total')),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      if (!partial) ...[
                        const Spacer(),
                        Text(tr(label), style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 13)),
                        Icon(Icons.chevron_right_rounded, color: primary, size: 18),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (partial) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: AppColors.onFill(primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(tr('Συνέχισε'), style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRestart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(tr('Από την αρχή'), style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(tr(label), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key, required this.program});
  final Map<String, dynamic> program;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  late final List<Map<String, dynamic>> _exercises;
  late final Set<String> _done;
  bool _busy = false;
  bool _changed = false;
  bool _stopped = false;
  bool _syncWatch = false;
  DateTime? _startedAt;
  DateTime? _endedAt;
  DateTime? _pauseMark;
  Duration _pausedFor = Duration.zero;
  Timer? _ticker;
  Map<String, int> _kcalByExercise = {};
  int? _totalKcal;
  int? _watchKcal;
  int? _watchHr;
  bool _sharingPhoto = false;
  final _sharePhotos = SharePhotoService();

  @override
  void initState() {
    super.initState();
    _exercises = _exercisesOf(widget.program);
    _done = _doneIds(widget.program);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _begin() {
    _ticker?.cancel();
    setState(() {
      _startedAt = DateTime.now();
      _endedAt = null;
      _pauseMark = null;
      _pausedFor = Duration.zero;
      _stopped = false;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _endedAt == null && _pauseMark == null) setState(() {});
    });
    _loadCalories();
  }

  void _togglePause() {
    if (_startedAt == null || _endedAt != null) return;
    if (_pauseMark != null) {
      _pausedFor += DateTime.now().difference(_pauseMark!);
      _pauseMark = null;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _endedAt == null && _pauseMark == null) setState(() {});
      });
    } else {
      _pauseMark = DateTime.now();
      _ticker?.cancel();
    }
    setState(() {});
  }

  void _stopSession() {
    _stopClock();
    setState(() => _stopped = true);
    _loadCalories();
    _loadWatch();
  }

  void _stopClock() {
    if (_pauseMark != null) {
      _pausedFor += DateTime.now().difference(_pauseMark!);
      _pauseMark = null;
    }
    _endedAt ??= DateTime.now();
    _ticker?.cancel();
  }

  Duration get _elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    final end = _endedAt ?? _pauseMark ?? DateTime.now();
    final d = end.difference(start) - _pausedFor;
    return d.isNegative ? Duration.zero : d;
  }

  List<Map<String, dynamic>> get _caloriePayload => _exercises.map((ex) => {
    'id': ex['id']?.toString(),
    'name': ex['exercise_name']?.toString(),
    'sets': _asInt(ex['exercise_sets']),
    'reps': ex['exercise_reps']?.toString(),
    'duration_secs': _asInt(ex['duration_secs']),
    'rest_secs': _asInt(ex['rest_secs']),
  }).toList();

  Future<void> _loadCalories() async {
    final userId = context.read<AuthService>().user?.id;
    if (userId == null) return;
    try {
      final res = await context.read<AuthService>().api.estimateWorkoutCalories(
        userId,
        exercises: _caloriePayload,
        durationSecs: _elapsed.inSeconds,
      );
      if (!mounted) return;
      final map = <String, int>{};
      for (final row in (res['exercises'] as List? ?? [])) {
        if (row is! Map) continue;
        final id = row['id']?.toString();
        final kcal = _asInt(row['kcal']);
        if (id != null && kcal != null) map[id] = kcal;
      }
      setState(() {
        _kcalByExercise = map;
        _totalKcal = _asInt(res['total_kcal']);
      });
    } catch (_) {}
  }

  Future<void> _enableWatch() async {
    final ok = await HealthWorkoutService.instance.requestPermissions();
    if (!mounted) return;
    setState(() => _syncWatch = ok);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Δεν δόθηκε πρόσβαση στο ρολόι'))),
      );
    }
  }

  Future<void> _loadWatch() async {
    if (!_syncWatch || _startedAt == null || _endedAt == null) return;
    final window = await HealthWorkoutService.instance.loadWindow(_startedAt!, _endedAt!);
    if (!mounted) return;
    setState(() {
      _watchKcal = window.calories;
      _watchHr = window.avgHeartRate;
    });
  }

  String? get _programId => widget.program['program_id']?.toString();

  int get _currentIndex {
    for (var i = 0; i < _exercises.length; i++) {
      final id = _exercises[i]['id']?.toString();
      if (id != null && !_done.contains(id)) return i;
    }
    return _exercises.length;
  }

  Future<void> _markDone() async {
    final index = _currentIndex;
    if (index >= _exercises.length || _busy) return;
    final id = _exercises[index]['id']?.toString();
    final programId = _programId;
    final userId = context.read<AuthService>().user?.id;
    if (id == null || programId == null || userId == null) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().api.checkProgramExercise(userId, programId, id);
      if (!mounted) return;
      final finishedNow = _done.length + 1 >= _exercises.length;
      if (finishedNow) {
        _stopClock();
        _loadCalories();
        _loadWatch();
      }
      setState(() {
        _done.add(id);
        _changed = true;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
    }
  }

  Future<void> _undo() async {
    if (_busy) return;
    final previous = _exercises.lastWhere(
      (ex) => _done.contains(ex['id']?.toString()),
      orElse: () => {},
    );
    final id = previous['id']?.toString();
    final programId = _programId;
    final userId = context.read<AuthService>().user?.id;
    if (id == null || programId == null || userId == null) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().api.undoProgramExercise(userId, programId, id);
      if (!mounted) return;
      setState(() {
        _done.remove(id);
        _changed = true;
        _busy = false;
        if (_startedAt != null && _endedAt != null) {
          final elapsed = _endedAt!.difference(_startedAt!);
          _endedAt = null;
          _startedAt = DateTime.now().subtract(elapsed);
        }
      });
      if (_startedAt != null && _endedAt == null) {
        _ticker?.cancel();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && _endedAt == null) setState(() {});
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
    }
  }

  Future<void> _restart({bool andBegin = false}) async {
    final programId = _programId;
    final userId = context.read<AuthService>().user?.id;
    if (programId == null || userId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().api.resetProgramSession(userId, programId);
      if (!mounted) return;
      _ticker?.cancel();
      setState(() {
        _done.clear();
        _startedAt = null;
        _endedAt = null;
        _pauseMark = null;
        _pausedFor = Duration.zero;
        _stopped = false;
        _watchKcal = null;
        _watchHr = null;
        _changed = true;
        _busy = false;
      });
      if (andBegin) _begin();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final name = widget.program['program_name'] as String? ?? s.programsDefaultName;
    final primary = context.tenantPrimary;
    final index = _currentIndex;
    final finished = _exercises.isNotEmpty && index >= _exercises.length;
    final onFill = AppColors.onFill(primary);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ),
        body: _exercises.isEmpty
            ? Center(child: Text(tr('Αυτό το πρόγραμμα δεν έχει ασκήσεις'), style: TextStyle(color: AppColors.textSecondary)))
            : (finished || _stopped)
                ? _doneView(primary, onFill)
                : _startedAt == null
                    ? _startView(name, primary, onFill)
                    : _exerciseView(index, primary, onFill),
      ),
    );
  }

  Widget _startView(String name, Color primary, Color onFill) {
    final continuing = _done.isNotEmpty;
    final image = _programImage(context, widget.program);
    final description = _field(widget.program, 'program_description');
    final focus = _field(widget.program, 'focus');
    final protein = _field(widget.program, 'protein_note');
    final difficulty = _difficultyOf(widget.program);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                image,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Icon(Icons.timer_outlined, color: primary, size: 64),
            const SizedBox(height: 16),
          ],
          Text(tr(name), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          if (difficulty != null || focus != null) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (difficulty != null) _MetaChip(label: tr('Δυσκολία $difficulty/5'), color: primary),
                if (focus != null) _MetaChip(label: tr(focus), color: primary),
              ],
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: 14),
            Text(tr(description), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 15)),
          ],
          if (protein != null) ...[
            const SizedBox(height: 12),
            Text(tr(protein), textAlign: TextAlign.center, style: TextStyle(color: primary, height: 1.4, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Text(
            tr(continuing ? 'Συνεχίζεις τώρα;' : tr('Αρχίζεις τώρα;')),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            tr(continuing
                ? 'Συνεχίζεις από εκεί που σταμάτησες, ή ξεκινάς τις ασκήσεις από την αρχή. Με το ναι ξεκινάει ο χρόνος.'
                : tr('Με το ναι ξεκινάει ο χρόνος. Οι ασκήσεις περνάνε μία-μία και στο τέλος βλέπεις ενδεικτικές θερμίδες από το προφίλ σου.')),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _syncWatch ? null : _enableWatch,
              icon: Icon(_syncWatch ? Icons.watch_rounded : Icons.watch_outlined, color: primary),
              label: Text(
                _syncWatch ? 'Το ρολόι θα συγχρονιστεί' : tr('Συγχρονισμός με ρολόι'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: _syncWatch ? primary : AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _begin,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: onFill,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(tr(continuing ? 'Ναι, συνεχίζω' : tr('Ναι, ξεκινάω')), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          if (continuing) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _restart(andBegin: true),
                icon: const Icon(Icons.replay_rounded),
                label: Text(tr('Ξεκίνα από την αρχή'), style: TextStyle(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
    );
  }

  Widget _exerciseView(int index, Color primary, Color onFill) {
    final exercise = _exercises[index];
    final title = exercise['exercise_name']?.toString() ?? tr('Άσκηση');
    final muscle = exercise['muscle_group']?.toString();
    final notes = exercise['notes']?.toString();
    final desc = exercise['exercise_description']?.toString();
    final rawUrl = exercise['animation_url']?.toString();
    final rawPoster = exercise['thumbnail_url']?.toString();
    final apiBase = context.read<AuthService>().api.config.apiBaseUrl;
    final media = rawUrl == null || rawUrl.isEmpty ? null : _resolveMediaUrl(rawUrl, apiBase);
    final poster = rawPoster == null || rawPoster.isEmpty ? null : _resolveMediaUrl(rawPoster, apiBase);
    final sets = _asInt(exercise['exercise_sets']);
    final reps = exercise['exercise_reps'];
    final dur = _asInt(exercise['duration_secs']);
    final rest = _asInt(exercise['rest_secs']);
    final kcal = _kcalByExercise[exercise['id']?.toString()];
    final paused = _pauseMark != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(tr(_clock(_elapsed)), style: TextStyle(color: primary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SessionAction(
                    icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    label: tr(paused ? 'Συνέχεια' : tr('Παύση')),
                    onTap: _togglePause,
                  ),
                  const SizedBox(width: 8),
                  _SessionAction(
                    icon: Icons.stop_rounded,
                    label: tr('Διακοπή'),
                    onTap: _confirmStop,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(tr('${index + 1} από ${_exercises.length}'),
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _ShareIconButton(busy: _sharingPhoto, onTap: _pickSharePhoto),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: index / _exercises.length,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              if (media != null)
                _MediaFull(
                  key: ValueKey('${exercise['id']}-$media'),
                  url: media,
                  poster: poster,
                  paused: paused,
                ),
              if (media != null) const SizedBox(height: 16),
              Text(tr(title), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              if (muscle != null && muscle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(tr(muscle), style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
              ],
              if (kcal != null) ...[
                const SizedBox(height: 6),
                Text(tr('περίπου $kcal kcal'), style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (sets != null && reps != null)
                    Expanded(child: _StatBox(label: tr('Επαναλήψεις'), value: '$sets×$reps', color: primary)),
                  if (sets != null && reps != null && (rest != null || dur != null))
                    const SizedBox(width: 10),
                  if (rest != null)
                    Expanded(child: _StatBox(label: tr('Ξεκούραση'), value: _formatSecs(rest), color: primary))
                  else if (dur != null)
                    Expanded(child: _StatBox(label: tr('Διάρκεια'), value: _formatSecs(dur), color: primary)),
                ],
              ),
              if (desc != null && desc.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(tr(desc), style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 15)),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(tr(notes), style: const TextStyle(color: Colors.white70, height: 1.4)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _markDone,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: onFill,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(tr(_busy ? 'Αποθήκευση...' : 'Επόμενη άσκηση'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              if (_done.isNotEmpty)
                TextButton(onPressed: _busy ? null : _undo, child: Text(tr('Προηγούμενη άσκηση'))),
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _askShareCaption() async {
    final controller = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('Τι να γράφει στη φωτογραφία;'), style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Το λογότυπο, η μέρα και η ώρα μπαίνουν μόνα τους. Εδώ γράφεις ό,τι θέλεις εσύ, όχι το όνομα του προγράμματος.'),
              style: TextStyle(color: AppColors.textSecondary, height: 1.35, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 80,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: tr('π.χ. Τα κατάφερα σήμερα'),
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Άκυρο'))),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(tr('Έτοιμο'))),
        ],
      ),
    );
    controller.dispose();
    return caption;
  }

  Future<void> _pickSharePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              title: Text(tr('Κάμερα'), style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: Text(tr('Συλλογή'), style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;
    final caption = await _askShareCaption();
    if (caption == null || !mounted) return;
    setState(() => _sharingPhoto = true);
    try {
      final config = context.read<TenantConfig>();
      final bytes = await picked.readAsBytes();
      final logoBytes = await _sharePhotos.loadLogoBytes(
        logoUrl: config.logoUrl,
        apiBaseUrl: config.apiBaseUrl,
      );
      final now = DateTime.now();
      final file = await _sharePhotos.composeWorkoutShare(
        photoBytes: bytes,
        logoBytes: logoBytes,
        details: WorkoutShareDetails(
          gymName: config.appName,
          workoutTitle: '',
          caption: caption,
          startsAt: _startedAt ?? now,
          endsAt: now,
          accentColorHex: config.primaryColor,
        ),
      );
      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Δεν μπόρεσε να ετοιμαστεί η φωτογραφία'))),
        );
        return;
      }
      await _showShareSheet(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Δεν μπόρεσε να ετοιμαστεί η φωτογραφία'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingPhoto = false);
    }
  }

  Future<void> _showShareSheet(File file) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Φωτογραφία προπόνησης'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              tr('Πάνω είναι το κείμενό σου, η μέρα και η ώρα. Κάτω το λογότυπο.'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                builder: (_) => WorkoutShareFullscreen(imageFile: file),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await _sharePhotos.saveToGallery(file);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(tr('Αποθηκεύτηκε στη συλλογή'))),
                          );
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(tr('Δεν αποθηκεύτηκε η φωτογραφία'))),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: Text(tr('Κατέβασμα')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final box = ctx.findRenderObject() as RenderBox?;
                      final origin = box != null && box.hasSize
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      await _sharePhotos.shareWorkoutPhoto(file, sharePositionOrigin: origin);
                    },
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmStop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('Διακοπή προπόνησης;'), style: TextStyle(color: Colors.white)),
        content: Text(tr('Ο χρόνος σταματάει και βλέπεις τη σύνοψη.'), style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Όχι'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Διακοπή'))),
        ],
      ),
    );
    if (ok == true) _stopSession();
  }

  String? _exerciseThumb(Map<String, dynamic> exercise) {
    final apiBase = context.read<AuthService>().api.config.apiBaseUrl;
    for (final key in ['thumbnail_url', 'animation_url']) {
      final raw = exercise[key]?.toString();
      if (raw == null || raw.isEmpty || _isVideoUrl(raw)) continue;
      return _resolveMediaUrl(raw, apiBase);
    }
    return null;
  }

  Widget _doneView(Color primary, Color onFill) {
    final timed = _startedAt != null;
    final elapsed = _elapsed;
    final kcal = _totalKcal;
    final finished = _exercises.where((ex) {
      final id = ex['id']?.toString();
      return id != null && _done.contains(id);
    }).toList();
    final shown = finished.isNotEmpty ? finished : _exercises;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Center(child: Icon(_stopped ? Icons.stop_circle_outlined : Icons.check_circle_rounded, color: primary, size: 64)),
        const SizedBox(height: 12),
        Text(tr(_stopped ? 'Σταμάτησες την προπόνηση' : tr('Τελείωσες το πρόγραμμα')),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (timed) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _FinishChip(icon: Icons.timer_outlined, label: tr(_clock(elapsed)), color: primary),
              _FinishChip(icon: Icons.fitness_center, label: tr('${_done.length}/${_exercises.length}'), color: primary),
              if (kcal != null) _FinishChip(icon: Icons.local_fire_department_outlined, label: tr('~$kcal kcal'), color: primary),
              if (_watchKcal != null) _FinishChip(icon: Icons.watch_rounded, label: tr('$_watchKcal kcal'), color: primary),
              if (_watchHr != null) _FinishChip(icon: Icons.favorite_rounded, label: tr('$_watchHr bpm'), color: primary),
            ],
          ),
          if (_syncWatch && _watchKcal == null && _watchHr == null) ...[
            const SizedBox(height: 10),
            Text(
              tr('Δεν βρέθηκαν μετρήσεις από το ρολόι για αυτό το διάστημα.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            tr('Οι θερμίδες είναι ενδεικτικές, από το βάρος και τον στόχο σου.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final ex in shown)
                    SizedBox(
                      width: width,
                      child: _ExerciseResultCard(
                        name: ex['exercise_name']?.toString() ?? tr('Άσκηση'),
                        imageUrl: _exerciseThumb(ex),
                        kcal: _kcalByExercise[ex['id']?.toString()],
                        color: primary,
                      ),
                    ),
                ],
              );
            },
          ),
        ] else
          Text(tr('Οι ασκήσεις σημειώθηκαν για σήμερα. Αύριο ξεκινάς ξανά από την αρχή.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _sharingPhoto ? null : _pickSharePhoto,
            icon: _sharingPhoto
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.ios_share_rounded),
            label: Text(tr('Φωτογραφία για share'), style: TextStyle(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _changed),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: onFill,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(tr('Τέλος προγράμματος'), style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : _restart,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(tr('Ξανά από την αρχή'), style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _ShareIconButton extends StatelessWidget {
  const _ShareIconButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _FinishChip extends StatelessWidget {
  const _FinishChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(tr(label), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ExerciseResultCard extends StatelessWidget {
  const _ExerciseResultCard({
    required this.name,
    required this.color,
    this.imageUrl,
    this.kcal,
  });
  final String name;
  final String? imageUrl;
  final int? kcal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 88,
              width: double.infinity,
              child: imageUrl == null
                  ? ColoredBox(
                      color: AppColors.surfaceLight,
                      child: Icon(Icons.fitness_center, color: color, size: 28),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: AppColors.surfaceLight,
                        child: Icon(Icons.fitness_center, color: color, size: 28),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, height: 1.2),
          ),
          if (kcal != null) ...[
            const SizedBox(height: 6),
            Text(tr('~$kcal kcal'), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _SessionAction extends StatelessWidget {
  const _SessionAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 4),
              Text(tr(label), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(label), style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(tr(value), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center, size: 40, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              tr(AppStrings.of(context).programsNoProgram),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              tr(AppStrings.of(context).programsNoAssigned),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              tr(message),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: Colors.black,
              ),
              child: Text(tr(AppStrings.of(context).retryBtn)),
            ),
          ],
        ),
      ),
    );
  }
}
