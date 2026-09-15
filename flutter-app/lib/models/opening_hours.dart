class DayHours {
  const DayHours({
    required this.open,
    required this.close,
    this.closed = false,
  });

  final String open;
  final String close;
  final bool closed;

  factory DayHours.fromJson(Map<String, dynamic> json) {
    return DayHours(
      open: json['open'] as String? ?? '09:00',
      close: json['close'] as String? ?? '21:00',
      closed: json['closed'] as bool? ?? false,
    );
  }
}

/// Weekly schedule: 0 = Monday … 6 = Sunday (matches gym-admin settings).
class OpeningHoursConfig {
  const OpeningHoursConfig(this.days);

  final Map<int, DayHours> days;

  factory OpeningHoursConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const OpeningHoursConfig({});
    final parsed = <int, DayHours>{};
    for (final entry in json.entries) {
      final key = int.tryParse(entry.key);
      if (key == null || key < 0 || key > 6) continue;
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        parsed[key] = DayHours.fromJson(value);
      }
    }
    return OpeningHoursConfig(parsed);
  }

  /// Dart [DateTime.weekday]: 1 = Mon … 7 = Sun.
  bool isDateOpen(DateTime date) => isWeekdayOpen(date.weekday);

  bool isWeekdayOpen(int dartWeekday) {
    final wd = dartWeekday - 1;
    final day = days[wd];
    if (day == null) return true;
    return !day.closed;
  }

  DateTime? nextOpenDate({required DateTime from, int maxDays = 60}) {
    final start = DateTime(from.year, from.month, from.day);
    for (var i = 0; i <= maxDays; i++) {
      final candidate = start.add(Duration(days: i));
      if (isDateOpen(candidate)) return candidate;
    }
    return null;
  }
}
