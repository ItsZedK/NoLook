import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../platform/os.dart';
import '../controller.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/app_picker.dart';
import '../widgets/block_card.dart';
import '../widgets/common.dart';
import '../widgets/lists.dart';
import 'devices.dart';
import 'edit_block.dart';
import 'unlock.dart';

class BlockPage extends StatelessWidget {
  const BlockPage({super.key, required this.app, required this.id});

  final NoLook app;
  final String id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) {
        final b = app.state.block(id);
        if (b == null) return const SizedBox();
        return _build(context, b);
      });

  void _change(BuildContext context, Block b, void Function(Block copy) edit) {
    final copy = b.copy();
    edit(copy);
    final problems = app.updateBlock(copy);
    if (problems.isNotEmpty) toast(context, problems.first);
  }

  /// offer new preset words/sites
  Widget? _presetBanner(BuildContext context, Block b, Preset? preset) {
    if (preset == null) return null;
    final m = preset.missingFrom(b);
    final n = m.keywords.length + m.spoilerWords.length + m.topicWords.length + m.sites.length;
    if (n == 0) return null;
    final c = context.nl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NlCard(
        color: c.primaryContainer,
        child: Row(children: [
          Ms(Symbols.new_releases_rounded, color: c.onPrimaryContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('The ${preset.name} preset has $n new ${n == 1 ? 'entry' : 'entries'}', 'A(z) ${preset.name} sablonban $n új elem van'),
                  style: body(16, weight: FontWeight.w600, color: c.onPrimaryContainer)),
              Text(
                [...m.keywords, ...m.topicWords, ...m.spoilerWords, ...m.sites].take(6).join(', ') + (n > 6 ? '...' : ''),
                style: body(13, color: c.onPrimaryContainer.withValues(alpha: .8)),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Btn(tr('Add them', 'Hozzáadás'), onPressed: () => _change(context, b, (x) => x
            ..keywords = [...x.keywords, ...m.keywords]
            ..spoilerWords = [...x.spoilerWords, ...m.spoilerWords]
            ..topicWords = [...x.topicWords, ...m.topicWords]
            ..sites = [...x.sites, ...m.sites])),
        ]),
      ),
    );
  }

  Widget _build(BuildContext context, Block b) {
    final c = context.nl;
    final now = app.now;
    final locked = b.isLocked(now);
    final phone = context.isPhone;
    final (bg, fg) = c.block(b.color);
    final preset = presets.where((p) => p.id == b.presetId).firstOrNull;
    final devices = 1 + app.state.browsersSeen.length;
    final presetBanner = _presetBanner(context, b, preset);

    final hero = ClipRRect(
      borderRadius: BorderRadius.circular(phone ? 24 : 28),
      child: Container(
        color: bg,
        child: Stack(children: [
          Positioned(
            right: -60,
            bottom: -90,
            child: Blob(size: 260, color: fg.withValues(alpha: .06), radii: const [.58, .42, .40, .60, .55, .45, .55, .45]),
          ),
          Padding(
            padding: EdgeInsets.all(phone ? 20 : 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                BlockIcon(b, size: 64, color: fg),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: display(phone ? 24 : 30, color: fg, height: 1.15)),
                    if (preset != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(tr('From the ${preset.name} preset', 'A(z) ${preset.name} sablonból'), style: body(15, color: fg.withValues(alpha: .75))),
                      ),
                  ]),
                ),
                NlSwitch(
                  value: b.isOn(now),
                  locked: locked,
                  scale: 1.2,
                  tooltip: locked ? tr('Locked, click to unlock early', 'Zárolva, kattints a korábbi feloldáshoz') : null,
                  onTap: () => tapSwitch(context, app, b),
                ),
              ]),
              const SizedBox(height: 20),
              Wrap(spacing: 28, runSpacing: 12, children: [
                for (final (n, label) in [
                  ('${app.stats.hiddenTodayFor(b.id)}', tr('hidden today', 'elrejtve ma')),
                  ('${app.state.totals[b.id] ?? 0}', tr('hidden in total', 'elrejtve összesen')),
                  ('$devices', devices == 1 ? tr('device', 'eszköz') : tr('devices', 'eszköz')),
                ])
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n, style: display(30, color: fg)),
                    Text(label, style: body(14, color: fg.withValues(alpha: .75))),
                  ]),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: c.wash.withValues(alpha: .5), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Ms(lockIcon(b, now), size: 20, color: fg, fill: lockIcon(b, now) == Symbols.lock_rounded),
                  const SizedBox(width: 10),
                  Expanded(child: lockText(b, now, fg, size: 15)),
                  if (locked && !phone)
                    Text(tr('Tap the switch to unlock early', 'A kapcsolóval oldhatod fel korábban'), style: body(13, color: fg.withValues(alpha: .75))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );

    Widget sect(String title, {String? count, String? text, required Widget child, bool low = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NlCard(
            color: low ? c.surfaceLow : c.surfaceMid,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(title, style: body(18, weight: FontWeight.w600, color: c.onSurface)),
                if (count != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(999)),
                    child: Text(count, style: body(13, weight: FontWeight.w500, color: c.onSurfaceVariant)),
                  ),
                ],
              ]),
              if (text != null) ...[const SizedBox(height: 4), Text(text, style: body(14, color: c.onSurfaceVariant))],
              const SizedBox(height: 16),
              child,
            ]),
          ),
        );

    Widget opt(IconData? icon, String t, String s, {Widget? end, bool first = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: first ? null : Border(top: BorderSide(color: c.onSurface.withValues(alpha: .07))),
          ),
          child: Row(children: [
            if (icon != null) ...[Ms(icon, color: c.onSurfaceVariant), const SizedBox(width: 14)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: body(15, color: c.onSurface)),
                Text(s, style: body(13, color: c.onSurfaceVariant)),
              ]),
            ),
            ?end,
          ]),
        );

    final change = Btn(tr('Change', 'Módosítás'), kind: BtnKind.text, onPressed: () => go(context, EditBlockPage(app: app, editing: b, openAdvanced: true)));

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ?presetBanner,
      sect(tr('Keywords', 'Kulcsszavak'),
          count: '${b.wordCount}',
          text: onMobile ? tr('Anything that mentions these gets covered.', 'Ami ezeket említi, azt eltakarja.') : tr('Anything that mentions these gets blurred.', 'Ami ezeket említi, el lesz rejtve.'),
          child: WordsEditor(
            block: b,
            canRemove: !locked,
            headings: false,
            fill: c.surfaceMid,
            onChanged: (k, s, t) => _change(context, b, (x) => x
              ..keywords = k
              ..spoilerWords = s
              ..topicWords = t),
          )),
      sect(tr('Sites', 'Oldalak'),
          count: '${b.sites.length}',
          text: tr('These sites get blocked.', 'Ezek az oldalak le lesznek tiltva.'),
          child: SiteEditor(
            sites: b.sites,
            rows: true,
            canRemove: !locked,
            hint: tr('e.g. reddit.com/r/GTA6', 'pl. reddit.com/r/GTA6'),
            fill: c.surfaceMid,
            onChanged: (s) => _change(context, b, (x) => x.sites = s),
          )),
      // mac/linux can still get apps via sync
      if (closesApps || b.apps.isNotEmpty)
      sect(tr('Apps', 'Appok'),
          count: '${b.apps.length}',
          text: closesApps
              ? tr('These apps get closed as soon as they open.', 'Ezek az appok bezáródnak, amint megnyitod őket.')
              : tr('These get closed on your Windows PCs and Android phones, not on this computer.', 'Ezek a Windowsos gépeiden és androidos telefonjaidon záródnak be, ezen a gépen nem.'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final a in b.apps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(8)),
                    child: Ms(Symbols.apps_rounded, size: 18, color: c.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name, style: body(15, color: c.onSurface)),
                      Text(a.ids.join(', '), style: body(13, color: c.onSurfaceVariant)),
                    ]),
                  ),
                  if (!locked)
                    IconBtn(Symbols.close_rounded,
                        tooltip: tr('Remove', 'Eltávolítás'), onPressed: () => _change(context, b, (x) => x.apps = [...x.apps]..remove(a))),
                ]),
              ),
            const SizedBox(height: 4),
            if (closesApps)
            Btn(tr('Add an app', 'App hozzáadása'), icon: Symbols.add_rounded, kind: BtnKind.outlined, onPressed: () async {
              final picked = await pickApps(context, already: b.apps);
              if (picked != null && context.mounted) _change(context, b, (x) => x.apps = [...x.apps, ...picked]);
            }),
          ])),
    ]);

    final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (locked)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Ms(Symbols.info_rounded, size: 20, color: c.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr("While it's locked, you can add things but not remove them.", 'Zárolás alatt hozzáadhatsz, de nem törölhetsz.'),
                  style: body(14, color: c.onSurfaceVariant)),
            ),
          ]),
        ),
      sect(tr("When it's on", 'Mikor fut'),
          low: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Seg<bool>(
              options: [(true, tr('Always', 'Mindig'), Symbols.all_inclusive_rounded), (false, tr('On a schedule', 'Időbeosztással'), Symbols.schedule_rounded)],
              value: b.schedule.always,
              onChanged: (always) {
                if (locked) {
                  toast(context, tr("The schedule can't change while it's locked.", 'Zárolás alatt nem változhat az időbeosztás.'));
                } else if (always) {
                  _change(context, b, (x) => x.schedule = const Schedule.always());
                } else {
                  go(context, EditBlockPage(app: app, editing: b));
                }
              },
            ),
            if (!b.schedule.always)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(children: [
                  Expanded(child: Text(b.schedule.describe(), style: body(14, color: c.onSurfaceVariant))),
                  if (!locked) Btn(tr('Change', 'Módosítás'), kind: BtnKind.text, onPressed: () => go(context, EditBlockPage(app: app, editing: b))),
                ]),
              ),
          ])),
      sect(tr('Lock', 'Zárolás'),
          low: true,
          child: Column(children: [
            opt(
              switch (b.lock) {
                LockKind.none => Symbols.lock_open_rounded,
                LockKind.untilDate => Symbols.event_rounded,
                LockKind.wait => Symbols.hourglass_top_rounded,
                LockKind.type => Symbols.keyboard_rounded,
              },
              first: true,
              switch (b.lock) {
                LockKind.none => tr('No lock', 'Nincs zárolás'),
                LockKind.untilDate => tr('Until a date', 'Egy dátumig'),
                LockKind.wait => tr('Wait to unlock', 'Várakozás a feloldáshoz'),
                LockKind.type => tr('Type to unlock', 'Begépelés a feloldáshoz'),
              },
              switch (b.lock) {
                LockKind.untilDate when b.lockedUntil != null => locked
                    ? tr('${Describe.day(b.lockedUntil!, now)} ${b.lockedUntil!.year}, ${b.lockedUntil!.difference(now).inDays + 1} days left',
                        '${b.lockedUntil!.year}. ${Describe.day(b.lockedUntil!, now)}, még ${b.lockedUntil!.difference(now).inDays + 1} nap')
                    : tr('Ended ${Describe.day(b.lockedUntil!, now)}', 'Lejárt: ${Describe.day(b.lockedUntil!, now)}'),
                LockKind.none => tr('Turn it off any time', 'Bármikor kikapcsolhatod'),
                _ => tr("Always locked while it's on", 'Amíg be van kapcsolva, zárolva van'),
              },
              end: change,
            ),
            if (b.lock != LockKind.none) ...[
              opt(Symbols.hourglass_top_rounded, tr('To unlock early', 'Korábbi feloldás'), Describe.unlockSteps(b), end: change),
              opt(Symbols.replay_rounded, tr('After unlocking early', 'Korábbi feloldás után'), Describe.relock(b), end: change),
              opt(Symbols.emergency_rounded, tr('Emergency unlocks', 'Vészfeloldások'), Describe.emergency(b, now), end: change),
            ],
          ])),
      sect(tr('Matches', 'Találatok'),
          low: true,
          child: Column(children: [
            opt(first: true, null, b.matchMode == MatchMode.blur
                    ? (onMobile ? tr('Cover, tap Show to see it', 'Eltakarás, a Mutasd gombbal látszik') : tr('Blur, click to reveal', 'Homályosítás, kattintásra látszik'))
                    : tr('Hide completely', 'Teljes elrejtés'),
                b.matchMode == MatchMode.blur
                    ? tr('Or hide them completely', 'Vagy teljesen elrejtheted')
                    : (onMobile ? tr('Or cover them, with a Show button', 'Vagy eltakarhatod, Mutasd gombbal') : tr('Or blur them with click to reveal', 'Vagy homályosíthatod, kattintásra látszik')),
                end: Seg<MatchMode>(
                  options: [(MatchMode.blur, onMobile ? tr('Cover', 'Takarás') : tr('Blur', 'Homály'), null), (MatchMode.hide, tr('Hide', 'Rejtés'), null)],
                  value: b.matchMode,
                  onChanged: (v) => _change(context, b, (x) => x.matchMode = v),
                )),
          ])),
      sect(tr('Devices', 'Eszközök'),
          low: true,
          child: opt(first: true, deviceIcon, app.state.deviceName,
              onMobile
                  ? tr('Runs on this phone', 'Ezen a telefonon fut')
                  : app.state.browsersSeen.isEmpty ? tr('Runs on this PC', 'Ezen a gépen fut') : tr('Runs on this PC and in ${browsers.where(app.state.browsersSeen.containsKey).join(', ')}', 'Ezen a gépen és itt fut: ${browsers.where(app.state.browsersSeen.containsKey).join(', ')}'))),
    ]);

    return NlPage(children: [
      PageBar(
        title: phone ? null : tr('Blocks', 'Tiltások'),
        leading: IconBtn(Symbols.arrow_back_rounded, tooltip: tr('Back', 'Vissza'), onPressed: () => Navigator.pop(context)),
        actions: [
          IconBtn(Symbols.ios_share_rounded, tooltip: tr('Share as file', 'Megosztás fájlként'), onPressed: () => exportBlocks(context, app, only: [b])),
          PopupMenuButton<String>(
            tooltip: tr('More', 'Továbbiak'),
            icon: Ms(Symbols.more_vert_rounded, color: c.onSurfaceVariant),
            color: c.surfaceMid,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (v) async {
              if (v == 'edit') go(context, EditBlockPage(app: app, editing: b));
              if (v == 'delete') {
                final ok = await showNlDialog<bool>(context, (ctx) => _ConfirmDelete(name: b.name));
                if (ok == true && context.mounted) {
                  app.deleteBlock(b.id);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(tr('Edit block', 'Tiltás szerkesztése'), style: body(15, color: c.onSurface))),
              PopupMenuItem(
                value: 'delete',
                enabled: !locked,
                child: Text(locked ? tr("Delete (not while it's locked)", 'Törlés (zárolás alatt nem)') : tr('Delete block', 'Tiltás törlése'), style: body(15, color: locked ? c.onSurfaceVariant : c.error)),
              ),
            ],
          ),
        ],
      ),
      hero,
      const SizedBox(height: 12),
      if (phone) ...[right, left] else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: left),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: right),
        ]),
    ]);
  }
}

class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Delete $name?', 'Törlöd ezt: $name?'), style: body(24, weight: FontWeight.w500, color: c.onSurface)),
      const SizedBox(height: 12),
      Text(tr('Its keywords, sites and apps stop being blocked straight away.', 'A kulcsszavai, oldalai és appjai azonnal felszabadulnak.'), style: body(15, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn(tr('Cancel', 'Mégse'), kind: BtnKind.text, onPressed: () => Navigator.pop(context, false)),
        const SizedBox(width: 8),
        Btn(tr('Delete', 'Törlés'), kind: BtnKind.danger, onPressed: () => Navigator.pop(context, true)),
      ]),
    ]);
  }
}
