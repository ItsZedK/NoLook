// builds dist/chrome and dist/firefox
//   node build.mjs        build both
import { build } from 'esbuild';
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = import.meta.dirname;
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));

// svgs -> icons module
const icons = {};
for (const f of readdirSync(join(root, 'src/icons'))) {
  const d = readFileSync(join(root, 'src/icons', f), 'utf8').match(/ d="([^"]+)"/)[1];
  icons[f.replace('.svg', '')] = d;
}
writeFileSync(
  join(root, 'src/icons.gen.ts'),
  '// Made by build.mjs from src/icons (Material Symbols Rounded, Apache 2.0). Do not edit.\n' +
    `export const iconPaths: Record<string, string> = ${JSON.stringify(icons, null, 2)};\n` +
    // content script only needs this one
    `export const hiddenIcon = ${JSON.stringify(icons.visibility_off_fill)};\n`,
);

// key pins the extension id
const key = readFileSync(join(root, 'chrome-key.txt'), 'utf8').trim();

const base = {
  manifest_version: 3,
  name: 'NoLook',
  version: pkg.version,
  description: 'Blurs posts and videos that mention your keywords and blocks the sites you pick.',
  icons: { 16: 'icons/16.png', 32: 'icons/32.png', 48: 'icons/48.png', 128: 'icons/128.png' },
  action: { default_popup: 'popup.html', default_icon: { 16: 'icons/16.png', 32: 'icons/32.png' }, default_title: 'NoLook' },
  permissions: ['nativeMessaging', 'storage', 'declarativeNetRequest', 'tabs', 'alarms'],
  host_permissions: ['<all_urls>'],
  content_scripts: [{ matches: ['<all_urls>'], js: ['content.js'], css: ['content.css'], run_at: 'document_start' }],
  web_accessible_resources: [{ resources: ['blocked.html', 'fonts/*'], matches: ['<all_urls>'] }],
};

const targets = {
  chrome: { ...base, key, background: { service_worker: 'background.js' } },
  firefox: {
    ...base,
    background: { scripts: ['background.js'] },
    // amo data collection: none
    browser_specific_settings: { gecko: { id: 'nolook@itszedk.com', strict_min_version: '140.0', data_collection_permissions: { required: ['none'] } } },
  },
};

for (const [name, manifest] of Object.entries(targets)) {
  const out = join(root, 'dist', name);
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  await build({
    entryPoints: ['background', 'content', 'popup', 'blocked'].map((e) => join(root, 'src', `${e}.ts`)),
    outdir: out,
    bundle: true,
    format: 'iife',
    target: ['chrome120', 'firefox128'],
    minify: false,
    logLevel: 'warning',
  });
  cpSync(join(root, 'static'), out, { recursive: true });
  if (name === 'firefox') {
    const css = join(out, 'content.css');
    writeFileSync(css, readFileSync(css, 'utf8').replaceAll('chrome-extension://', 'moz-extension://'));
  }
  cpSync(join(root, '../app/assets/fonts/Outfit.ttf'), join(out, 'fonts/Outfit.ttf'));
  cpSync(join(root, '../app/assets/fonts/Syne.ttf'), join(out, 'fonts/Syne.ttf'));
  writeFileSync(join(out, 'manifest.json'), JSON.stringify(manifest, null, 2));
}

// store build: no key, stores assign their own id
const store = join(root, 'dist', 'chrome-store');
rmSync(store, { recursive: true, force: true });
cpSync(join(root, 'dist', 'chrome'), store, { recursive: true });
const { key: _, ...storeManifest } = targets.chrome;
writeFileSync(join(store, 'manifest.json'), JSON.stringify(storeManifest, null, 2));

console.log('Built dist/chrome, dist/chrome-store and dist/firefox');
