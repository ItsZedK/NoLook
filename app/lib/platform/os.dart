import 'dart:io';

/// os for ui decisions, system calls still use [Platform]
enum Os { windows, android, macos, linux }

Os get os =>
    Platform.isAndroid
        ? Os.android
        : Platform.isWindows
            ? Os.windows
            : Platform.isMacOS
                ? Os.macos
                : Os.linux;

bool get onAndroid => os == Os.android;
bool get onWindows => os == Os.windows;

/// phone/tablet
bool get onMobile => os == Os.android;

/// app closing, windows only for now (mac/linux rely on the extension)
bool get closesApps => os == Os.windows || os == Os.android;
