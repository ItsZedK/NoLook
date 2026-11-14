#!/usr/bin/env bash
# windows installer, run build_windows.sh first
# out: build/installer/NoLook-setup.exe
# needs inno setup 6
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(grep -m1 '^version:' "$root/app/pubspec.yaml" | sed 's/version: *//; s/+.*//')"
iscc="$(command -v iscc || command -v ISCC || true)"
for guess in "$LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe" "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" "/c/Program Files/Inno Setup 6/ISCC.exe"; do
  [ -z "$iscc" ] && [ -f "$guess" ] && iscc="$guess"
done
[ -z "$iscc" ] && { echo "Inno Setup 6 isn't installed"; exit 1; }
cd "$root/tools/installer"
"$iscc" //Q "//DAppVersion=$version" nolook.iss
echo "Built $root/build/installer/NoLook-setup.exe ($version)"
