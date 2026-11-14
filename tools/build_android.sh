#!/usr/bin/env bash
# android release apk
# Output: app/build/app/outputs/flutter-apk/app-release.apk
# release key if present, else debug
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$root/app" && flutter.bat build apk --release)
echo "Built $root/app/build/app/outputs/flutter-apk/app-release.apk"
