#!/usr/bin/env bash
# windows build: app + helper + extensions
# Output: app/build/windows/x64/runner/Release (run nolook.exe from there).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

# kill running copies first, the browser can restart it mid build
taskkill //im nolook.exe //f >/dev/null 2>&1 && echo "Closed the running NoLook" || true

(cd "$root/extension" && node build.mjs)
(cd "$root/host" && dart.bat pub get >/dev/null && dart.bat compile exe bin/nolook_host.dart -o build/nolook_host.exe)
(cd "$root/app" && flutter.bat build windows --release)

out="$root/app/build/windows/x64/runner/Release"
# helper may be running, rename instead of overwrite
rm -f "$out"/nolook_host.old*.exe 2>/dev/null || true
[ -f "$out/nolook_host.exe" ] && mv "$out/nolook_host.exe" "$out/nolook_host.old$(date +%s).exe"
cp "$root/host/build/nolook_host.exe" "$out/"
rm -rf "$out/extension"
mkdir -p "$out/extension"
cp -r "$root/extension/dist/chrome" "$root/extension/dist/firefox" "$out/extension/"
echo "Built $out"
