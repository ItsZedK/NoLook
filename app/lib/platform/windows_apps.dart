// win32 process listing/killing
import 'dart:ffi';

import 'package:ffi/ffi.dart';

final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _user32 = DynamicLibrary.open('user32.dll');

final _enumProcesses = _kernel32.lookupFunction<Int32 Function(Pointer<Uint32>, Uint32, Pointer<Uint32>),
    int Function(Pointer<Uint32>, int, Pointer<Uint32>)>('K32EnumProcesses');
final _openProcess =
    _kernel32.lookupFunction<IntPtr Function(Uint32, Int32, Uint32), int Function(int, int, int)>('OpenProcess');
final _closeHandle = _kernel32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
final _terminateProcess =
    _kernel32.lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>('TerminateProcess');
final _queryImageName = _kernel32.lookupFunction<Int32 Function(IntPtr, Uint32, Pointer<Utf16>, Pointer<Uint32>),
    int Function(int, int, Pointer<Utf16>, Pointer<Uint32>)>('QueryFullProcessImageNameW');
final _getCurrentProcessId = _kernel32.lookupFunction<Uint32 Function(), int Function()>('GetCurrentProcessId');

typedef _EnumProc = Int32 Function(IntPtr hwnd, IntPtr lParam);
final _enumWindows = _user32.lookupFunction<Int32 Function(Pointer<NativeFunction<_EnumProc>>, IntPtr),
    int Function(Pointer<NativeFunction<_EnumProc>>, int)>('EnumWindows');
final _isWindowVisible = _user32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsWindowVisible');
final _getWindowTextLength = _user32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('GetWindowTextLengthW');
final _getWindowThreadProcessId =
    _user32.lookupFunction<Uint32 Function(IntPtr, Pointer<Uint32>), int Function(int, Pointer<Uint32>)>(
        'GetWindowThreadProcessId');
final _getWindow = _user32.lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>('GetWindow');

const _processTerminate = 0x0001;
const _processQueryLimited = 0x1000;
const _gwOwner = 4;

/// never kill these
const protectedExes = {
  'explorer.exe', 'svchost.exe', 'csrss.exe', 'winlogon.exe', 'wininit.exe', 'dwm.exe', 'lsass.exe',
  'services.exe', 'smss.exe', 'system', 'registry', 'fontdrvhost.exe', 'sihost.exe', 'ctfmon.exe',
  'searchhost.exe', 'startmenuexperiencehost.exe', 'shellexperiencehost.exe', 'textinputhost.exe',
  'applicationframehost.exe', 'runtimebroker.exe', 'taskhostw.exe', 'conhost.exe', 'nolook.exe', 'nolook_host.exe',
};

class RunningApp {
  const RunningApp(this.exe, this.path);

  /// lowercase exe name
  final String exe;
  final String path;

  /// display name from the path
  String get name {
    final file = path.split('\\').last;
    final base = file.toLowerCase().endsWith('.exe') ? file.substring(0, file.length - 4) : file;
    return base.isEmpty ? exe : base[0].toUpperCase() + base.substring(1);
  }
}

String? _imagePath(int pid, {bool terminate = false}) {
  final h = _openProcess(_processQueryLimited | (terminate ? _processTerminate : 0), 0, pid);
  if (h == 0) return null;
  final buf = calloc<Uint16>(1024).cast<Utf16>();
  final size = calloc<Uint32>()..value = 1024;
  try {
    return _queryImageName(h, 0, buf, size) != 0 ? buf.toDartString(length: size.value) : null;
  } finally {
    calloc.free(buf);
    calloc.free(size);
    _closeHandle(h);
  }
}

List<int> _pids() {
  const max = 8192;
  final ids = calloc<Uint32>(max);
  final needed = calloc<Uint32>();
  try {
    if (_enumProcesses(ids, max * 4, needed) == 0) return const [];
    return [for (var i = 0; i < needed.value ~/ 4; i++) ids[i]];
  } finally {
    calloc.free(ids);
    calloc.free(needed);
  }
}

/// kill by exe name, returns what got closed
List<String> closeApps(Set<String> exes) {
  if (exes.isEmpty) return const [];
  final self = _getCurrentProcessId();
  final closed = <String>[];
  for (final pid in _pids()) {
    if (pid == 0 || pid == 4 || pid == self) continue;
    final path = _imagePath(pid);
    if (path == null) continue;
    final exe = path.split('\\').last.toLowerCase();
    if (!exes.contains(exe) || protectedExes.contains(exe)) continue;
    final h = _openProcess(_processTerminate, 0, pid);
    if (h == 0) continue;
    if (_terminateProcess(h, 1) != 0) closed.add(exe);
    _closeHandle(h);
  }
  return closed;
}

/// apps with a visible window
List<RunningApp> appsWithWindows() {
  final pids = <int>{};
  final callback = NativeCallable<_EnumProc>.isolateLocal((int hwnd, int _) {
    if (_isWindowVisible(hwnd) != 0 && _getWindowTextLength(hwnd) > 0 && _getWindow(hwnd, _gwOwner) == 0) {
      final pid = calloc<Uint32>();
      _getWindowThreadProcessId(hwnd, pid);
      pids.add(pid.value);
      calloc.free(pid);
    }
    return 1;
  }, exceptionalReturn: 0);
  _enumWindows(callback.nativeFunction, 0);
  callback.close();

  final self = _getCurrentProcessId();
  final byExe = <String, RunningApp>{};
  for (final pid in pids) {
    if (pid == self) continue;
    final path = _imagePath(pid);
    if (path == null) continue;
    final exe = path.split('\\').last.toLowerCase();
    if (protectedExes.contains(exe)) continue;
    byExe[exe] = RunningApp(exe, path);
  }
  return byExe.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
