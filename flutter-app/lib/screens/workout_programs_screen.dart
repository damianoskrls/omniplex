import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
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

/// Full-size media: plays video with controls, or shows image.
class _MediaFull extends StatefulWidget {
  const _MediaFull({required this.url});
  final String url;
  @override
  State<_MediaFull> createState() => _MediaFullState();
}

class _MediaFullState extends State<_MediaFull> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (_isVideoUrl(widget.url)) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) {
            _ctrl!.setLooping(true);
            _ctrl!.play();
            setState(() => _initialized = true);
          }
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
      return GestureDetector(
        onTap: () => _ctrl?.value.isPlaying == true ? _ctrl?.pause() : _ctrl?.play(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity, height: 220, color: Colors.black,
            child: _initialized && _ctrl != null
              ? FittedBox(fit: BoxFit.contain, child: SizedBox(
                  width: _ctrl!.value.size.width,
                  height: _ctrl!.value.size.height,
                  child: VideoPlayer(_ctrl!),
                ))
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
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
  const WorkoutProgramsScreen({super.key});

  @override
  State<WorkoutProgramsScreen> createState() => _WorkoutProgramsScreenState();
}

class _WorkoutProgramsScreenState extends State<WorkoutProgramsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _programs = [];
  final Set<String> _expanded = {};

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
      final data = await auth.api.fetchMyPrograms(userId);
      if (mounted) setState(() { _programs = data; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      itemCount: _programs.length,
                      itemBuilder: (context, i) => _ProgramCard(
                        program: _programs[i],
                        expanded: _expanded.contains(_programs[i]['assignment_id'] as String? ?? '$i'),
                        onToggle: () {
                          final key = _programs[i]['assignment_id'] as String? ?? '$i';
                          setState(() {
                            if (_expanded.contains(key)) {
                              _expanded.remove(key);
                            } else {
                              _expanded.add(key);
                            }
                          });
                        },
                      ),
                    ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.expanded,
    required this.onToggle,
  });

  final Map<String, dynamic> program;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final name = program['program_name'] as String? ?? s.programsDefaultName;
    final desc = program['program_description'] as String?;
    final exercises = (program['exercises'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? [];
    final assignedAt = program['assigned_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B4FCF), Color(0xFF7C5CFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fitness_center, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.layers_outlined, size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              s.exerciseCount(exercises.length),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            if (assignedAt != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                _fmtDate(assignedAt),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (desc != null && desc.isNotEmpty && expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                desc,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
          if (expanded && exercises.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            ...exercises.asMap().entries.map((entry) =>
              _ExerciseRow(exercise: entry.value, index: entry.key)),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String iso) {
    final parts = iso.split('T').first.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0].substring(2)}';
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.index});

  final Map<String, dynamic> exercise;
  final int index;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final name = exercise['exercise_name'] as String? ?? s.exerciseDefaultName;
    final muscle = exercise['muscle_group'] as String?;
    final rawAnimUrl = exercise['animation_url'] as String?;
    final apiBase = context.read<AuthService>().api.config.apiBaseUrl;
    final animUrl = rawAnimUrl != null ? _resolveMediaUrl(rawAnimUrl, apiBase) : null;
    final sets = exercise['exercise_sets'] as int?;
    final reps = exercise['exercise_reps'] as int?;
    final durSecs = exercise['duration_secs'] as int?;
    final restSecs = exercise['rest_secs'] as int?;
    final desc = exercise['exercise_description'] as String?;

    return InkWell(
      onTap: animUrl != null && animUrl.isNotEmpty
          ? () => _showExerciseDetail(context, animUrl)
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            // animation thumbnail or placeholder
            GestureDetector(
              onTap: animUrl != null && animUrl.isNotEmpty
                  ? () => _showExerciseDetail(context, animUrl)
                  : null,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.hardEdge,
                child: animUrl != null && animUrl.isNotEmpty
                    ? _MediaThumb(url: animUrl, size: 56)
                    : const Icon(
                        Icons.fitness_center,
                        color: AppColors.textSecondary,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (muscle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      muscle,
                      style: const TextStyle(color: AppColors.purple, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (sets != null && reps != null)
                        _Chip(label: s.exerciseSetsReps(sets, reps), color: AppColors.lime),
                      if (sets != null && reps == null && durSecs != null)
                        _Chip(label: s.exerciseSetsDuration(sets, _formatSecs(durSecs)), color: AppColors.teal),
                      if (sets != null && reps != null && durSecs != null)
                        _Chip(label: _formatSecs(durSecs), color: AppColors.teal),
                      if (restSecs != null)
                        _Chip(label: s.exerciseRestLabel(_formatSecs(restSecs)), color: AppColors.orange),
                    ],
                  ),
                ],
              ),
            ),
            if (animUrl != null && animUrl.isNotEmpty)
              const Icon(Icons.play_circle_outline, color: AppColors.lime, size: 24),
          ],
        ),
      ),
    );
  }

  String _formatSecs(int s) {
    if (s >= 60) {
      final m = s ~/ 60;
      final rem = s % 60;
      return rem == 0 ? '${m}λ' : '${m}λ${rem}δ';
    }
    return '${s}δ';
  }

  void _showExerciseDetail(BuildContext context, String? animUrl) {
    final s = AppStrings.of(context);
    final name = exercise['exercise_name'] as String? ?? s.exerciseDefaultName;
    final desc = exercise['exercise_description'] as String?;
    final muscle = exercise['muscle_group'] as String?;
    final sets = exercise['exercise_sets'] as int?;
    final reps = exercise['exercise_reps'] as int?;
    final durSecs = exercise['duration_secs'] as int?;
    final restSecs = exercise['rest_secs'] as int?;
    final notes = exercise['notes'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (animUrl != null && animUrl.isNotEmpty)
                _MediaFull(url: animUrl),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (muscle != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    muscle,
                    style: const TextStyle(color: AppColors.purple, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Stats row
              Row(
                children: [
                  if (sets != null)
                    _StatBox(label: s.exerciseSets, value: '$sets'),
                  if (reps != null) ...[
                    const SizedBox(width: 10),
                    _StatBox(label: s.exerciseReps, value: '$reps'),
                  ],
                  if (durSecs != null) ...[
                    const SizedBox(width: 10),
                    _StatBox(label: s.exerciseDuration, value: _formatSecs(durSecs)),
                  ],
                  if (restSecs != null) ...[
                    const SizedBox(width: 10),
                    _StatBox(label: s.exerciseRest, value: _formatSecs(restSecs)),
                  ],
                ],
              ),
              if (desc != null && desc.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  s.exerciseInstructions,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                ),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.exerciseTrainerNotes,
                        style: const TextStyle(color: AppColors.lime, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.lime,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
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
