enum EventKind {
  blurred,

  blocked,

  closedApp,

  unlocked,

  emergency,
}

class HistoryEvent {
  HistoryEvent({
    required this.time,
    required this.kind,
    required this.blockId,
    this.blockName = '',
    this.target = '',
    List<String>? matched,
    this.where = '',
    this.count = 1,
    this.note = '',
  }) : matched = matched ?? const [];

  final DateTime time;
  final EventKind kind;
  final String blockId;
  final String blockName;

  final String target;

  final List<String> matched;

  final String where;

  /// grouped count
  final int count;
  final String note;

  bool get isHidden => kind == EventKind.blurred || kind == EventKind.blocked || kind == EventKind.closedApp;
  bool get isUnlock => kind == EventKind.unlocked || kind == EventKind.emergency;

  Map<String, Object?> toJson() => {
        'time': time.toIso8601String(),
        'kind': kind.name,
        'blockId': blockId,
        if (blockName.isNotEmpty) 'blockName': blockName,
        if (target.isNotEmpty) 'target': target,
        if (matched.isNotEmpty) 'matched': matched,
        if (where.isNotEmpty) 'where': where,
        if (count != 1) 'count': count,
        if (note.isNotEmpty) 'note': note,
      };

  static HistoryEvent? fromJson(Map<String, Object?> json) {
    final time = DateTime.tryParse(json['time'] as String? ?? '');
    final kind = EventKind.values.where((k) => k.name == json['kind']).firstOrNull;
    if (time == null || kind == null) return null;
    return HistoryEvent(
      time: time,
      kind: kind,
      blockId: json['blockId'] as String? ?? '',
      blockName: json['blockName'] as String? ?? '',
      target: json['target'] as String? ?? '',
      matched: [for (final m in (json['matched'] as List? ?? const [])) m as String],
      where: json['where'] as String? ?? '',
      count: (json['count'] as num? ?? 1).toInt(),
      note: json['note'] as String? ?? '',
    );
  }
}

/// stats
class HistoryStats {
  HistoryStats(this.events, {required this.now, DateTime? since}) : since = since ?? now;

  final List<HistoryEvent> events;
  final DateTime now;

  /// caps the streak
  final DateTime since;

  DateTime get _today => DateTime(now.year, now.month, now.day);
  DateTime get _weekStart => _today.subtract(Duration(days: now.weekday - 1));

  int _sum(Iterable<HistoryEvent> e) => e.fold(0, (n, ev) => n + ev.count);

  int get hiddenToday => _sum(events.where((e) => e.isHidden && !e.time.isBefore(_today)));
  int get hiddenThisWeek => _sum(events.where((e) => e.isHidden && !e.time.isBefore(_weekStart)));
  int get unlocksThisWeek => events.where((e) => e.isUnlock && !e.time.isBefore(_weekStart)).length;

  int hiddenTodayFor(String blockId) =>
      _sum(events.where((e) => e.isHidden && e.blockId == blockId && !e.time.isBefore(_today)));

  /// days in a row without an unlock
  int get daysWithoutUnlock {
    final unlockDays = {
      for (final e in events.where((e) => e.isUnlock)) DateTime(e.time.year, e.time.month, e.time.day),
    };
    final first = DateTime(since.year, since.month, since.day);
    var days = 0;
    var day = _today;
    while (!day.isBefore(first) && !unlockDays.contains(day) && days < 3650) {
      days++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return days;
  }
}
