import 'block.dart';
import 'i18n.dart';
import 'state.dart';
import 'unlock.dart';

/// shared block text for the app, helper and extension
class Describe {
  const Describe._();

  static const monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const monthsHu = [
    'január', 'február', 'március', 'április', 'május', 'június',
    'július', 'augusztus', 'szeptember', 'október', 'november', 'december',
  ];

  static String month(int m) => isHu ? monthsHu[m - 1] : monthsEn[m - 1];

  /// year only if not this year
  static String day(DateTime d, DateTime now) {
    if (isHu) return d.year == now.year ? '${month(d.month)} ${d.day}.' : '${d.year}. ${month(d.month)} ${d.day}.';
    return d.year == now.year ? '${d.day} ${month(d.month)}' : '${d.day} ${month(d.month)} ${d.year}';
  }

  /// "until" form
  static String until(DateTime d, DateTime now) {
    if (!isHu) return day(d, now);
    final base = d.year == now.year ? '${month(d.month)} ${d.day}' : '${d.year}. ${month(d.month)} ${d.day}';
    return '$base-ig';
  }

  static String time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String minutes(int m) {
    if (m < 60) return tr('$m min', '$m perc');
    if (m % 60 == 0) return tr(m == 60 ? '1 hour' : '${m ~/ 60} hours', '${m ~/ 60} óra');
    return tr('${m ~/ 60} h ${m % 60} min', '${m ~/ 60} óra ${m % 60} perc');
  }

  /// "24 keywords, 9 sites", or "Empty".
  static String contents(Block b) {
    final parts = <String>[];
    void add(int n, String one, String many, String hu) {
      if (n > 0) parts.add(tr('$n ${n == 1 ? one : many}', '$n $hu'));
    }

    add(b.wordCount, 'keyword', 'keywords', 'kulcsszó');
    add(b.sites.length, 'site', 'sites', 'oldal');
    add(b.apps.length, 'app', 'apps', 'app');
    return parts.isEmpty ? tr('Empty', 'Üres') : parts.join(', ');
  }

  /// (before, bold, after)
  static (String, String, String) lockLineParts(Block b, DateTime now) {
    if (b.isPaused(now)) {
      final t = time(b.pausedUntil!);
      return isHu ? ('Korábban feloldva, ', '$t-kor', ' visszakapcsol') : ('Unlocked early, back on at ', t, '');
    }
    if (!b.enabled) return (tr('Off', 'Kikapcsolva'), '', '');
    if (b.isLocked(now) && b.lock == LockKind.untilDate) {
      return (tr('Locked until ', 'Zárolva '), until(b.lockedUntil!, now), '');
    }
    if (!b.schedule.always && !b.schedule.contains(now)) {
      final next = b.schedule.nextStart(now);
      if (next != null) {
        final t = time(next);
        final unlock = switch (b.lock) {
          LockKind.wait => tr(', ${minutes(b.waitMinutes)} wait to unlock', ', ${minutes(b.waitMinutes)} várakozással oldható fel'),
          LockKind.type => tr(', type to unlock', ', begépeléssel oldható fel'),
          _ => '',
        };
        return isHu ? ('', '$t-kor', ' bekapcsol$unlock') : ('Turns on at ', t, unlock);
      }
    }
    final line = switch (b.lock) {
      LockKind.none => tr('No lock', 'Nincs zárolás'),
      LockKind.untilDate =>
        tr('Lock ended ${day(b.lockedUntil ?? now, now)}', 'A zárolás lejárt: ${day(b.lockedUntil ?? now, now)}'),
      LockKind.wait =>
        tr('${minutes(b.waitMinutes)} wait to unlock early', '${minutes(b.waitMinutes)} várakozás a korábbi feloldáshoz'),
      LockKind.type => tr('Type a sentence to unlock early', 'Egy mondat begépelésével oldható fel'),
    };
    return (line, '', '');
  }

  static String lockLine(Block b, DateTime now) {
    final (a, bold, c) = lockLineParts(b, now);
    return '$a$bold$c';
  }

  /// "Wait 30 min, then type a sentence".
  static String unlockSteps(Block b) {
    final s = Unlocker.stepsFor(b);
    final m = minutes(s.waitMinutes);
    if (s.wait && s.type) return tr('Wait $m, then type a sentence', '$m várakozás, aztán egy mondat begépelése');
    if (s.wait) return tr('Wait $m', '$m várakozás');
    if (s.type) return tr('Type a sentence', 'Egy mondat begépelése');
    return tr('Nothing, turn it off any time', 'Semmi, bármikor kikapcsolhatod');
  }

  static String relock(Block b) => b.relockMinutes == null
      ? tr('Stays off until you turn it on', 'Kikapcsolva marad, amíg vissza nem kapcsolod')
      : tr('Turns back on after ${minutes(b.relockMinutes!)}', '${minutes(b.relockMinutes!)} után visszakapcsol');

  static String emergency(Block b, DateTime now) {
    final limit = b.emergencyPerMonth;
    if (limit == null) return tr('No limit', 'Korlátlan');
    if (limit == 0) return tr('None', 'Nincs');
    final left = Unlocker.emergencyLeft(b, now)!;
    return tr('$limit a month, $left left in ${month(now.month)}', 'Havonta $limit, ebben a hónapban még $left');
  }

  static String summary(Block b) {
    final when = b.schedule.always
        ? tr('Always on', 'Mindig bekapcsolva')
        : tr('On ${b.schedule.describe()}', 'Bekapcsolva: ${b.schedule.describe()}');
    final s = Unlocker.stepsFor(b);
    final m = minutes(s.waitMinutes);
    final how = switch ((s.wait, s.type)) {
      (true, true) => tr('to unlock early you wait $m and type a sentence', 'korábbi feloldáshoz $m várakozás és egy mondat kell'),
      (true, false) => tr('to unlock early you wait $m', 'korábbi feloldáshoz $m várakozás kell'),
      (false, true) => tr('to unlock early you type a sentence', 'korábbi feloldáshoz egy mondatot kell begépelni'),
      _ => tr('turn it off any time', 'bármikor kikapcsolható'),
    };
    return '$when, $how.';
  }
}

/// sent to the extension
class BrowserRules {
  const BrowserRules._();

  static Map<String, Object?> build(NoLookState state, DateTime now, {String? deviceId}) => {
        'type': 'rules',
        'at': now.toIso8601String(),
        'settings': {
          'blurStrength': state.settings.blurStrength.name,
          'twoClickReveal': state.settings.twoClickReveal,
          'sayKeyword': state.settings.sayKeyword,
          'lang': currentLang.name,
          'language': state.settings.language.name,
        },
        'blocks': [
          for (final b in state.blocks)
            if (deviceId == null || b.runsOn(deviceId))
              {
                'id': b.id,
                'name': b.name,
                'color': b.color.name,
                'iconText': b.iconText,
                'iconName': b.iconName,
                'on': b.isOn(now),
                'active': b.isActive(now),
                'locked': b.isLocked(now),
                'lockLine': Describe.lockLine(b, now),
                'lockBold': Describe.lockLineParts(b, now).$2,
                'keywords': b.keywords,
                'spoilerWords': b.spoilerWords,
                'topicWords': b.topicWords,
                'sites': b.sites,
                // the extension ignores apps
                'apps': [for (final a in b.apps) a.toJson()],
                'matchMode': b.matchMode.name,
              },
        ],
      };
}
