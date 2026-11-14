import 'dart:convert';

import 'block.dart';
import 'state.dart';

class PairedDevice {
  PairedDevice({
    required this.id,
    required this.name,
    required this.os,
    required this.key,
    this.host = '',
    this.port = 0,
    this.lastSeen,
    DateTime? pairedAt,
  }) : pairedAt = pairedAt ?? DateTime.now();

  final String id;
  String name;

  /// "Windows", "Android", ...
  String os;

  /// shared key from pairing
  final String key;

  String host;
  int port;
  DateTime? lastSeen;
  final DateTime pairedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'os': os,
        'key': key,
        'host': host,
        'port': port,
        'lastSeen': lastSeen?.toIso8601String(),
        'pairedAt': pairedAt.toIso8601String(),
      };

  factory PairedDevice.fromJson(Map<String, Object?> j) => PairedDevice(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        os: j['os'] as String? ?? '',
        key: j['key'] as String? ?? '',
        host: j['host'] as String? ?? '',
        port: (j['port'] as num? ?? 0).toInt(),
        lastSeen: DateTime.tryParse(j['lastSeen'] as String? ?? ''),
        pairedAt: DateTime.tryParse(j['pairedAt'] as String? ?? ''),
      );
}

/// FNV-1a of the json minus [Block.updatedAt]
String blockFingerprint(Block b) {
  final j = b.toJson()..remove('updatedAt');
  var h = 0x811c9dc5;
  for (final c in utf8.encode(jsonEncode(j))) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

extension BlockSync on NoLookState {
  /// stamp changed blocks with [now], record deletions. runs on every save
  bool stampChanges(DateTime now) {
    var changed = false;
    final ids = <String>{};
    for (final b in blocks) {
      ids.add(b.id);
      final f = blockFingerprint(b);
      if (fingerprints[b.id] != f || b.updatedAt == null) {
        if (fingerprints[b.id] != f) b.updatedAt = now;
        b.updatedAt ??= now;
        fingerprints[b.id] = f;
        changed = true;
      }
    }
    for (final id in fingerprints.keys.toList()) {
      if (!ids.contains(id)) {
        fingerprints.remove(id);
        deletedBlocks[id] = now;
        changed = true;
      }
    }
    // drop old tombstones
    deletedBlocks.removeWhere((_, t) => now.difference(t).inDays > 60);
    return changed;
  }

  Map<String, Object?> syncPayload() => {
        'blocks': [for (final b in blocks) b.toJson()],
        'deleted': {for (final e in deletedBlocks.entries) e.key: e.value.toIso8601String()},
      };

  /// newest wins, true if anything changed
  bool mergeFrom(Map<String, Object?> payload) {
    var changed = false;
    final deleted = <String, DateTime>{
      for (final e in ((payload['deleted'] as Map?) ?? const {}).entries)
        if (DateTime.tryParse(e.value as String? ?? '') case final d?) e.key as String: d,
    };
    for (final e in deleted.entries) {
      final local = block(e.key);
      // deleted there after our last edit
      if (local != null && !(local.updatedAt?.isAfter(e.value) ?? false)) {
        blocks.remove(local);
        fingerprints.remove(local.id);
        changed = true;
      }
      if (deletedBlocks[e.key] == null || deletedBlocks[e.key]!.isBefore(e.value)) deletedBlocks[e.key] = e.value;
    }
    for (final raw in (payload['blocks'] as List? ?? const [])) {
      final theirs = Block.fromJson((raw as Map).cast());
      final when = theirs.updatedAt;
      if (when == null) continue;
      final gone = deletedBlocks[theirs.id];
      if (gone != null && !when.isAfter(gone)) continue;
      final i = blocks.indexWhere((b) => b.id == theirs.id);
      if (i == -1) {
        blocks.add(theirs);
      } else {
        final mine = blocks[i];
        if (mine.updatedAt != null && !when.isAfter(mine.updatedAt!)) continue;
        if (blockFingerprint(mine) == blockFingerprint(theirs)) {
          mine.updatedAt = when;
          continue;
        }
        blocks[i] = theirs;
      }
      // not a local change
      fingerprints[theirs.id] = blockFingerprint(theirs);
      deletedBlocks.remove(theirs.id);
      changed = true;
    }
    return changed;
  }
}
