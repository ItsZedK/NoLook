import 'schedule.dart';

/// card colours
enum BlockColor { teal, violet, peach, grey }

/// lock type
enum LockKind {
  /// no lock
  none,

  /// until [Block.lockedUntil]
  untilDate,

  /// wait [Block.waitMinutes]
  wait,

  /// type [Block.sentence]
  type,
}

enum EarlyUnlock { wait, type, both }

enum MatchMode { blur, hide }

/// [ids]: lowercase exe names on windows, package names on android
class AppRef {
  const AppRef({required this.name, required this.ids});

  final String name;
  final List<String> ids;

  bool matches(String id) {
    final lower = id.toLowerCase();
    return ids.any((i) => i.toLowerCase() == lower);
  }

  Map<String, Object?> toJson() => {'name': name, 'ids': ids};

  factory AppRef.fromJson(Map<String, Object?> json) => AppRef(
        name: json['name'] as String? ?? '',
        ids: [for (final i in (json['ids'] as List? ?? const [])) i as String],
      );

  @override
  bool operator ==(Object other) => other is AppRef && other.name == name && _sameList(other.ids, ids);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(ids));
}

bool _sameList(List a, List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class Block {
  Block({
    required this.id,
    required this.name,
    this.color = BlockColor.teal,
    this.iconText,
    this.iconName,
    this.presetId,
    List<String>? keywords,
    List<String>? spoilerWords,
    List<String>? topicWords,
    List<String>? sites,
    List<AppRef>? apps,
    this.enabled = true,
    this.schedule = const Schedule.always(),
    this.lock = LockKind.none,
    this.lockedUntil,
    this.earlyUnlock = EarlyUnlock.both,
    this.waitMinutes = 30,
    this.sentence = '',
    this.relockMinutes = 60,
    this.emergencyPerMonth = 3,
    this.matchMode = MatchMode.blur,
    this.imageText = false,
    List<String>? devices,
    this.pausedUntil,
    this.unlockStartedAt,
    List<DateTime>? emergencyUses,
    DateTime? createdAt,
    this.updatedAt,
  })  : keywords = keywords ?? [],
        spoilerWords = spoilerWords ?? [],
        topicWords = topicWords ?? [],
        sites = sites ?? [],
        apps = apps ?? [],
        devices = devices ?? [],
        emergencyUses = emergencyUses ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  BlockColor color;

  /// fallback when [iconName] is null
  String? iconText;

  /// material symbols name
  String? iconName;

  String? presetId;

  /// always hidden
  List<String> keywords;

  /// only with a topic word or keyword
  List<String> spoilerWords;

  /// context for spoiler words, not hidden alone
  List<String> topicWords;

  List<String> sites;
  List<AppRef> apps;

  /// switch state, can still be paused/off schedule
  bool enabled;
  Schedule schedule;

  LockKind lock;
  DateTime? lockedUntil;
  EarlyUnlock earlyUnlock;
  int waitMinutes;
  String sentence;

  /// relock after an early unlock, null = stay off
  int? relockMinutes;

  /// per month, null = unlimited
  int? emergencyPerMonth;

  MatchMode matchMode;
  bool imageText;

  /// empty = all devices
  List<String> devices;

  /// off until this after an early unlock
  DateTime? pausedUntil;

  DateTime? unlockStartedAt;

  List<DateTime> emergencyUses;

  final DateTime createdAt;

  /// for sync, newest wins
  DateTime? updatedAt;

  bool isLocked(DateTime now) {
    if (!enabled) return false;
    return switch (lock) {
      LockKind.none => false,
      LockKind.untilDate => lockedUntil != null && now.isBefore(lockedUntil!),
      LockKind.wait || LockKind.type => true,
    };
  }

  /// on and not paused
  bool isOn(DateTime now) => enabled && !isPaused(now);

  bool isPaused(DateTime now) => pausedUntil != null && now.isBefore(pausedUntil!);

  /// on and in schedule
  bool isActive(DateTime now) => isOn(now) && schedule.contains(now);

  bool runsOn(String deviceId) => devices.isEmpty || devices.contains(deviceId);

  int get wordCount => keywords.length + spoilerWords.length + topicWords.length;

  int get thingCount => wordCount + sites.length + apps.length;

  Block copy() => Block.fromJson(toJson());

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'color': color.name,
        'iconText': iconText,
        'iconName': iconName,
        'presetId': presetId,
        'keywords': keywords,
        'spoilerWords': spoilerWords,
        'topicWords': topicWords,
        'sites': sites,
        'apps': [for (final a in apps) a.toJson()],
        'enabled': enabled,
        'schedule': schedule.toJson(),
        'lock': lock.name,
        'lockedUntil': lockedUntil?.toIso8601String(),
        'earlyUnlock': earlyUnlock.name,
        'waitMinutes': waitMinutes,
        'sentence': sentence,
        'relockMinutes': relockMinutes,
        'emergencyPerMonth': emergencyPerMonth,
        'matchMode': matchMode.name,
        'imageText': imageText,
        'devices': devices,
        'pausedUntil': pausedUntil?.toIso8601String(),
        'unlockStartedAt': unlockStartedAt?.toIso8601String(),
        'emergencyUses': [for (final d in emergencyUses) d.toIso8601String()],
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Block.fromJson(Map<String, Object?> json) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    List<String> strings(Object? v) => [for (final s in (v as List? ?? const [])) s as String];

    return Block(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      color: pick(BlockColor.values, json['color'], BlockColor.teal),
      iconText: json['iconText'] as String?,
      iconName: json['iconName'] as String?,
      presetId: json['presetId'] as String?,
      keywords: strings(json['keywords']),
      spoilerWords: strings(json['spoilerWords']),
      topicWords: strings(json['topicWords']),
      sites: strings(json['sites']),
      apps: [for (final a in (json['apps'] as List? ?? const [])) AppRef.fromJson((a as Map).cast())],
      enabled: json['enabled'] as bool? ?? true,
      schedule: Schedule.fromJson((json['schedule'] as Map?)?.cast()),
      lock: pick(LockKind.values, json['lock'], LockKind.none),
      lockedUntil: date(json['lockedUntil']),
      earlyUnlock: pick(EarlyUnlock.values, json['earlyUnlock'], EarlyUnlock.both),
      waitMinutes: (json['waitMinutes'] as num? ?? 30).toInt(),
      sentence: json['sentence'] as String? ?? '',
      relockMinutes: (json['relockMinutes'] as num?)?.toInt(),
      emergencyPerMonth: (json['emergencyPerMonth'] as num?)?.toInt(),
      matchMode: pick(MatchMode.values, json['matchMode'], MatchMode.blur),
      imageText: json['imageText'] as bool? ?? false,
      devices: strings(json['devices']),
      pausedUntil: date(json['pausedUntil']),
      unlockStartedAt: date(json['unlockStartedAt']),
      emergencyUses: [for (final d in (json['emergencyUses'] as List? ?? const [])) DateTime.parse(d as String)],
      createdAt: date(json['createdAt']),
      updatedAt: date(json['updatedAt']),
    );
  }
}
