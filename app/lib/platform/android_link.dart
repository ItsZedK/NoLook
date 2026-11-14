import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';

/// channel to the kotlin side (BlockerService/NoLookEngine)
class AndroidLink {
  AndroidLink._();

  static const _channel = MethodChannel('nolook/android');
  static String _sent = '';

  /// update download progress 0-1
  static final updateProgress = ValueNotifier<double?>(null);

  /// a11y service on? null until checked, rechecked on resume
  static final blocker = ValueNotifier<bool?>(null);
  static AppLifecycleListener? _lifecycle;

  static Future<void> refreshBlocker() async => blocker.value = await blockerOn();

  static void attach(NoLook app) {
    _channel.setMethodCallHandler((call) async {
      final m = (call.arguments as Map).cast<String, Object?>();
      if (call.method == 'updateProgress') {
        updateProgress.value = (m['value'] as num?)?.toDouble();
        return;
      }
      if (call.method == 'blocker') {
        blocker.value = m['on'] == true;
        return;
      }
      final b = app.state.block(m['blockId'] as String? ?? '');
      if (b == null) return;
      switch (call.method) {
        case 'blockedApp':
          app.stopped(b, (m['name'] as String?)?.trim().isNotEmpty == true ? m['name'] as String : m['id'] as String? ?? '', site: false);
        case 'blockedSite':
          app.stopped(b, m['site'] as String? ?? '', site: true);
        case 'covered':
          app.covered(b, m['app'] as String? ?? '', [for (final k in (m['matched'] as List? ?? const [])) k as String], (m['count'] as num?)?.toInt() ?? 1);
      }
    });
    // tick pushes schedule/lock changes too
    app.addListener(() => _push(app));
    _push(app);
    app.notify = notify;
    _lifecycle ??= AppLifecycleListener(onResume: refreshBlocker);
    refreshBlocker();
  }

  static void _push(NoLook app) {
    final rules = BrowserRules.build(app.state, app.now, deviceId: app.state.deviceId);
    final key = jsonEncode({...rules, 'at': null});
    if (key == _sent) return;
    _sent = key;
    _channel.invokeMethod('rules', jsonEncode(rules));
  }

  static Future<bool> blockerOn() async {
    try {
      final s = await _channel.invokeMethod<Map>('status');
      return s?['blocker'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> notify(String title, String text) async {
    try {
      await _channel.invokeMethod('notify', {'title': title, 'text': text});
    } catch (_) {}
  }

  /// asks once unless [force]
  static Future<void> askNotifications({bool force = false}) async {
    try {
      await _channel.invokeMethod('askNotifications', {'force': force});
    } catch (_) {}
  }

  static Future<void> openBlockerSettings() => _channel.invokeMethod('openBlockerSettings');

  /// app info (for "Allow restricted settings" on sideloads)
  static Future<void> openAppInfo() => _channel.invokeMethod('openAppInfo');

  /// null once the installer prompt is up, else the error
  static Future<String?> installUpdate(String url) => _channel.invokeMethod<String>('installUpdate', {'url': url});

  /// path or null
  static Future<String?> saveToDownloads(String name, String text) =>
      _channel.invokeMethod<String>('saveToDownloads', {'name': name, 'text': text});

  static Future<void> openUrl(String url) => _channel.invokeMethod('openUrl', {'url': url});

  /// (package, name)
  static Future<List<(String, String)>> apps() async {
    final list = await _channel.invokeMethod<List>('apps') ?? const [];
    return [for (final a in list) ((a as Map)['id'] as String, a['name'] as String)];
  }
}
