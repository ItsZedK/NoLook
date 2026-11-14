#!/usr/bin/env bash
# all release files -> build/release/<version>:
#   NoLook-setup.exe      the Windows installer
#   NoLook-windows.zip    the Windows app, with the browser helper and the extensions (updates use this)
#   NoLook-android.apk    the Android app
#   NoLook-chrome.zip     the extension for Chrome and Edge
#   NoLook-firefox.zip    the extension for Firefox
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(grep '^version:' "$root/app/pubspec.yaml" | sed 's/version: *//; s/+.*//; s/\r//')"
out="$root/build/release/$version"

bash "$root/tools/build_windows.sh"
bash "$root/tools/build_installer.sh"
bash "$root/tools/build_android.sh"

# leaves the mac/linux files from CI alone
mkdir -p "$out"
rm -f "$out"/NoLook-setup.exe "$out"/NoLook-windows.zip "$out"/NoLook-android.apk "$out"/NoLook-chrome.zip "$out"/NoLook-firefox.zip
cp "$root/app/build/app/outputs/flutter-apk/app-release.apk" "$out/NoLook-android.apk"
cp "$root/build/installer/NoLook-setup.exe" "$out/NoLook-setup.exe"

# no zip in git bash, use python
python - "$root" "$out" "$version" <<'EOF'
import os, sys, zipfile
root, out, version = sys.argv[1:]

def pack(folder, target, skip=()):
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
        for d, _, files in os.walk(folder):
            for f in files:
                if any(s in f for s in skip):
                    continue
                path = os.path.join(d, f)
                z.write(path, os.path.relpath(path, folder))

win = os.path.join(root, 'app', 'build', 'windows', 'x64', 'runner', 'Release')
pack(win, os.path.join(out, f'NoLook-windows.zip'), skip=('nolook_host.old',))
pack(os.path.join(root, 'extension', 'dist', 'chrome'), os.path.join(out, f'NoLook-chrome.zip'))
pack(os.path.join(root, 'extension', 'dist', 'firefox'), os.path.join(out, f'NoLook-firefox.zip'))
EOF

ls -la "$out"
