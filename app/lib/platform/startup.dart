import 'dart:io';

const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

/// autostart via the Run key
Future<void> setStartWithWindows(bool on) async {
  if (!Platform.isWindows) return;
  if (on) {
    await Process.run('reg', ['add', _runKey, '/v', 'NoLook', '/t', 'REG_SZ', '/d', '"${Platform.resolvedExecutable}" --hidden', '/f']);
  } else {
    await Process.run('reg', ['delete', _runKey, '/v', 'NoLook', '/f']);
  }
}
