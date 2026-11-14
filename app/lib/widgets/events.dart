import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import 'common.dart';

IconData eventIcon(HistoryEvent e) => switch (e.kind) {
      EventKind.blurred => e.target.contains('youtube') ? Symbols.smart_display_rounded : Symbols.visibility_off_rounded,
      EventKind.blocked => Symbols.block_rounded,
      EventKind.closedApp => Symbols.close_rounded,
      EventKind.unlocked => Symbols.lock_open_rounded,
      EventKind.emergency => Symbols.emergency_rounded,
    };

String eventTitle(HistoryEvent e) {
  final elsewhere = e.where.isNotEmpty && e.where != 'this PC' && e.where != 'this phone' && e.kind == EventKind.closedApp;
  final n = e.count;
  final covered = e.where == 'this phone';
  return switch (e.kind) {
    EventKind.blurred when covered => n == 1
        ? tr('Covered a post on ${e.target}', 'Eltakart poszt: ${e.target}')
        : tr('Covered $n posts on ${e.target}', '$n eltakart poszt: ${e.target}'),
    EventKind.blurred when e.target.contains('youtube') =>
      n == 1 ? tr('Blurred a YouTube video', 'Elrejtett YouTube-videó') : tr('Blurred $n YouTube videos', '$n elrejtett YouTube-videó'),
    EventKind.blurred => n == 1
        ? tr('Blurred a post on ${e.target}', 'Elrejtett poszt: ${e.target}')
        : tr('Blurred $n posts on ${e.target}', '$n elrejtett poszt: ${e.target}'),
    EventKind.blocked => tr('Blocked ${e.target}', 'Letiltva: ${e.target}'),
    EventKind.closedApp => elsewhere
        ? tr('Closed ${e.target} on ${e.where}', 'Bezárva: ${e.target} (${e.where})')
        : tr('Closed ${e.target}', 'Bezárva: ${e.target}'),
    EventKind.unlocked => tr('Unlocked ${e.blockName} early', '${e.blockName} korábban feloldva'),
    EventKind.emergency => tr('Emergency unlock for ${e.blockName}', 'Vészfeloldás: ${e.blockName}'),
  };
}

String _quoted(List<String> m) => m.map((k) => isHu ? '„$k”' : '"$k"').join(', ');

/// event subtitle
String eventSubtitle(HistoryEvent e, {required bool sayKeyword, bool withBlock = true, bool withWhere = false}) {
  final parts = <String>[
    if (withBlock && e.blockName.isNotEmpty && !e.isUnlock) e.blockName,
    if (e.matched.isNotEmpty && sayKeyword) tr('matched ${_quoted(e.matched)}', 'találat: ${_quoted(e.matched)}'),
    if (e.isUnlock && e.note.isNotEmpty) e.note,
    if (withWhere && e.where.isNotEmpty && !e.isUnlock) where(e.where),
  ];
  final s = parts.join(', ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

String where(String w) {
  if (!isHu) return const {'Chrome', 'Edge', 'Firefox'}.contains(w) ? 'in $w' : 'on $w';
  return switch (w) {
    'this PC' => 'ezen a gépen',
    'this phone' => 'ezen a telefonon',
    'Chrome' => 'Chrome-ban',
    'Edge' => 'Edge-ben',
    'Firefox' => 'Firefoxban',
    _ => '$w eszközön',
  };
}

/// short age string
String ago(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return tr('now', 'most');
  if (d.inMinutes < 60) return tr('${d.inMinutes} min', '${d.inMinutes} perce');
  if (d.inHours < 24) return tr('${d.inHours} h', '${d.inHours} órája');
  return tr('${d.inDays} d', '${d.inDays} napja');
}

class EventRow extends StatelessWidget {
  const EventRow(this.e, {super.key, required this.end, required this.sayKeyword, this.withWhere = false});

  final HistoryEvent e;
  final String end;
  final bool sayKeyword;
  final bool withWhere;

  @override
  Widget build(BuildContext context) => NlRow(
        icon: eventIcon(e),
        title: eventTitle(e),
        subtitle: eventSubtitle(e, sayKeyword: sayKeyword, withWhere: withWhere),
        end: RowEnd(end),
      );
}
