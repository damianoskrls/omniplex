import 'package:intl/intl.dart';

class WorkoutShareDetails {
  WorkoutShareDetails({
    required this.gymName,
    required this.workoutTitle,
    required this.startsAt,
    required this.endsAt,
    this.trainerName,
    this.durationMins,
    this.accentColorHex = '#B8F55E',
  });

  final String gymName;
  final String workoutTitle;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? trainerName;
  final int? durationMins;
  final String accentColorHex;

  String get dateLine => DateFormat('EEEE d MMMM yyyy', 'el_GR').format(startsAt);

  String get timeLine => DateFormat('HH:mm', 'el_GR').format(startsAt);

  String? get durationLine {
    final mins = durationMins ?? endsAt.difference(startsAt).inMinutes;
    if (mins <= 0) return null;
    if (mins < 60) return '$mins′';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '${h}ώ $m′' : '${h}ώ';
  }

  String? get trainerLine {
    final name = trainerName?.trim();
    if (name == null || name.isEmpty) return null;
    return 'με $name';
  }
}
