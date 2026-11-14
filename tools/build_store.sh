#!/usr/bin/env bash
# store uploads -> build/store/<version>:
#   NoLook-chrome-store.zip      for the Chrome Web Store and Edge Add-ons (no fixed key, the stores give an ID)
#   NoLook-firefox-store.zip     for Firefox Add-ons
#   NoLook-extension-source.zip  the source, which Firefox Add-ons asks for since the code is bundled
# bump the version in extension/package.json first
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
(cd "$root/extension" && node build.mjs)
version="$(grep -m1 '"version"' "$root/extension/package.json" | sed 's/.*: *"//; s/".*//')"
out="$root/build/store/$version"
rm -rf "$out"
mkdir -p "$out"

python - "$root" "$out" <<'EOF'
import os, sys, zipfile
root, out = sys.argv[1:]
ext = os.path.join(root, 'extension')

def pack(target, entries):
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
        for src, inside in entries:
            if os.path.isfile(src):
                z.write(src, inside)
                continue
            for d, dirs, files in os.walk(src):
                dirs[:] = [x for x in dirs if x not in ('node_modules', 'dist')]
                for f in files:
                    p = os.path.join(d, f)
                    z.write(p, os.path.join(inside, os.path.relpath(p, src)).replace('\\', '/').lstrip('./'))

pack(os.path.join(out, 'NoLook-chrome-store.zip'), [(os.path.join(ext, 'dist', 'chrome-store'), '')])
pack(os.path.join(out, 'NoLook-firefox-store.zip'), [(os.path.join(ext, 'dist', 'firefox'), '')])

# same layout as the repo so build.mjs finds the fonts
readme = os.path.join(out, 'BUILD.txt')
with open(readme, 'w', newline='\n') as f:
    f.write('How to build NoLook\'s extension from this source\n\n'
            'Needs Node.js 22 or newer.\n\n'
            '  cd extension\n  npm ci\n  node build.mjs\n\n'
            'The Firefox version is then in extension/dist/firefox.\n')
pack(os.path.join(out, 'NoLook-extension-source.zip'), [
    (readme, 'BUILD.txt'),
    (os.path.join(ext, 'src'), 'extension/src'),
    (os.path.join(ext, 'static'), 'extension/static'),
    (os.path.join(ext, 'build.mjs'), 'extension/build.mjs'),
    (os.path.join(ext, 'package.json'), 'extension/package.json'),
    (os.path.join(ext, 'package-lock.json'), 'extension/package-lock.json'),
    (os.path.join(ext, 'tsconfig.json'), 'extension/tsconfig.json'),
    (os.path.join(ext, 'chrome-key.txt'), 'extension/chrome-key.txt'),
    (os.path.join(root, 'app', 'assets', 'fonts', 'Outfit.ttf'), 'app/assets/fonts/Outfit.ttf'),
    (os.path.join(root, 'app', 'assets', 'fonts', 'Syne.ttf'), 'app/assets/fonts/Syne.ttf'),
])
os.remove(readme)
EOF
ls -la "$out"
