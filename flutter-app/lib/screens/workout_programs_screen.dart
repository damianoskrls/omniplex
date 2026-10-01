import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/health_workout_service.dart';
import '../theme/app_colors.dart';

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
        _error = e is ApiException ? e.message : 'Δεν φορτώθηκαν τα προγράμματα';
        _loading = false;
      });
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
              ? _ErrorView(message: _error!, onRetry: () {
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
                              widget.serviceTitle == null
                                  ? 'Διάλεξε πρόγραμμα από τις υπηρεσίες σου'
                                  : 'Προγράμματα για ${widget.serviceTitle}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          );
                        }
                        final program = _programs[i - 1];
                        return _ProgramPickCard(
                          program: program,
                          onOpen: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => WorkoutSessionScreen(program: program)),
                            );
                            if (changed == true && mounted) {
                              setState(() { _loading = true; _error = null; });
                              await _load();
                            }
                          },
                        );
                      },
                    ),
    );
  }
}

class _ProgramPickCard extends StatelessWidget {
  const _ProgramPickCard({required this.program, required this.onOpen});
  final Map<String, dynamic> program;
  final VoidCallback onOpen;

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
    final label = finished ? 'Ολοκληρώθηκε' : (done > 0 ? 'Συνέχισε' : 'Ξεκίνα');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (names.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(names.join(' · '), style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
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
                  Text(total == 0 ? 'Χωρίς ασκήσεις' : '$done από $total',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const Spacer(),
                  Text(label, style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 13)),
                  Icon(Icons.chevron_right_rounded, color: primary, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
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
        const SnackBar(content: Text('Δεν δόθηκε πρόσβαση στο ρολόι')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _restart() async {
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
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
            ? const Center(child: Text('Αυτό το πρόγραμμα δεν έχει ασκήσεις', style: TextStyle(color: AppColors.textSecondary)))
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
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, color: primary, size: 64),
          const SizedBox(height: 16),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            continuing ? 'Συνεχίζεις τώρα;' : 'Αρχίζεις τώρα;',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Με το ναι ξεκινάει ο χρόνος. Οι ασκήσεις περνάνε μία-μία και στο τέλος βλέπεις ενδεικτικές θερμίδες από το προφίλ σου.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _syncWatch ? null : _enableWatch,
              icon: Icon(_syncWatch ? Icons.watch_rounded : Icons.watch_outlined, color: primary),
              label: Text(
                _syncWatch ? 'Το ρολόι θα συγχρονιστεί' : 'Συγχρονισμός με ρολόι',
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
              child: Text(continuing ? 'Ναι, συνεχίζω' : 'Ναι, ξεκινάω', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseView(int index, Color primary, Color onFill) {
    final exercise = _exercises[index];
    final title = exercise['exercise_name']?.toString() ?? 'Άσκηση';
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_clock(_elapsed), style: TextStyle(color: primary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('${index + 1} από ${_exercises.length}',
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
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
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              if (muscle != null && muscle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(muscle, style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
              ],
              if (kcal != null) ...[
                const SizedBox(height: 6),
                Text('περίπου $kcal kcal', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (sets != null && reps != null)
                    Expanded(child: _StatBox(label: 'Επαναλήψεις', value: '$sets×$reps', color: primary)),
                  if (sets != null && reps != null && (rest != null || dur != null))
                    const SizedBox(width: 10),
                  if (rest != null)
                    Expanded(child: _StatBox(label: 'Ξεκούραση', value: _formatSecs(rest), color: primary))
                  else if (dur != null)
                    Expanded(child: _StatBox(label: 'Διάρκεια', value: _formatSecs(dur), color: primary)),
                ],
              ),
              if (desc != null && desc.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(desc, style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 15)),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(notes, style: const TextStyle(color: Colors.white70, height: 1.4)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _togglePause,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(paused ? 'Συνέχεια' : 'Παύση', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _confirmStop,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Στοπ', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                  child: Text(_busy ? 'Αποθήκευση...' : 'Την έκανα',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              if (_done.isNotEmpty)
                TextButton(onPressed: _busy ? null : _undo, child: const Text('Προηγούμενη άσκηση')),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmStop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Στοπ προπόνησης;', style: TextStyle(color: Colors.white)),
        content: const Text('Ο χρόνος σταματάει και βλέπεις τη σύνοψη.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Όχι')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Στοπ')),
        ],
      ),
    );
    if (ok == true) _stopSession();
  }

  Widget _doneView(Color primary, Color onFill) {
    final timed = _startedAt != null;
    final elapsed = _elapsed;
    final kcal = _totalKcal;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 12),
        Center(child: Icon(_stopped ? Icons.stop_circle_outlined : Icons.check_circle_rounded, color: primary, size: 72)),
        const SizedBox(height: 16),
        Text(_stopped ? 'Σταμάτησες την προπόνηση' : 'Τελείωσες το πρόγραμμα',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (timed) ...[
          _SummaryRow(label: 'Χρόνος', value: _clock(elapsed)),
          _SummaryRow(label: 'Ασκήσεις', value: '${_done.length} από ${_exercises.length}'),
          if (kcal != null) _SummaryRow(label: 'Θερμίδες', value: 'περίπου $kcal kcal'),
          if (_watchKcal != null) _SummaryRow(label: 'Ρολόι', value: '$_watchKcal kcal'),
          if (_watchHr != null) _SummaryRow(label: 'Παλμοί', value: '$_watchHr bpm'),
          if (_syncWatch && _watchKcal == null && _watchHr == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Δεν βρέθηκαν μετρήσεις από το ρολόι για αυτό το διάστημα.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Οι θερμίδες είναι ενδεικτικές, από το βάρος και τον στόχο σου. Οι μετρήσεις ρολογιού φαίνονται χωριστά.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 13),
          ),
          if (_kcalByExercise.isNotEmpty) ...[
            const SizedBox(height: 18),
            ..._exercises.map((ex) {
              final id = ex['id']?.toString();
              final n = id == null ? null : _kcalByExercise[id];
              if (n == null) return const SizedBox.shrink();
              return _SummaryRow(label: ex['exercise_name']?.toString() ?? 'Άσκηση', value: '$n kcal');
            }),
          ],
        ] else
          const Text('Οι ασκήσεις σημειώθηκαν για σήμερα. Αύριο ξεκινάς ξανά από την αρχή.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _restart,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: onFill,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Ξανά από την αρχή', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
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
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
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
              AppStrings.of(context).programsNoProgram,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context).programsNoAssigned,
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
              message,
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
              child: Text(AppStrings.of(context).retryBtn),
            ),
          ],
        ),
      ),
    );
  }
}
