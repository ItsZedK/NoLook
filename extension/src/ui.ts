// shared by the popup + blocked page
import { iconPaths } from './icons.gen';
import type { RuleBlock } from './types';

export function icon(name: string, size = 24, fill = false): string {
  const d = iconPaths[fill && iconPaths[`${name}_fill`] ? `${name}_fill` : name] ?? '';
  return `<svg class="ms" width="${size}" height="${size}" viewBox="0 -960 960 960" aria-hidden="true"><path fill="currentColor" d="${d}"/></svg>`;
}

const known = new Set([
  'forum', 'bedtime', 'work', 'smart_display', 'sports_esports', 'movie', 'newspaper',
  'shopping_bag', 'sports_soccer', 'music_note', 'block', 'visibility_off',
]);

export function blockIcon(b: Pick<RuleBlock, 'iconName' | 'iconText' | 'name'>, size = 20): string {
  if (b.iconName && known.has(b.iconName)) return icon(b.iconName, size);
  return esc(b.iconText || (b.name[0] ?? '?').toUpperCase());
}

export function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

/** lock line, bold part comes from the app */
export function lockLineHtml(line: string, bold?: string): string {
  const i = bold ? line.indexOf(bold) : -1;
  if (i < 0) return esc(line);
  return `${esc(line.slice(0, i))}<b>${esc(bold!)}</b>${esc(line.slice(i + bold!.length))}`;
}

export const brandmark = `<span class="brandmark">
  <svg class="logo-icon" viewBox="0 0 100 100" aria-hidden="true"><rect width="100" height="100" rx="28" fill="var(--primary-container)"/><g transform="translate(17 17) scale(0.66)"><rect x="8" y="22" width="20" height="56" rx="10" fill="var(--primary)"/><rect x="72" y="22" width="20" height="56" rx="10" fill="var(--primary)"/><circle cx="50" cy="50" r="15" fill="var(--on-primary-container)"/></g></svg>
  <svg class="wordmark" viewBox="-7 3 406 106" role="img" aria-label="NoLook"><path fill="none" stroke="currentColor" stroke-width="14" stroke-linecap="round" stroke-linejoin="round" d="M0 100V40 M0 70A30 30 0 0 1 60 70V100 M81 70A31 31 0 1 0 143 70A31 31 0 1 0 81 70 M164 10V100 M185 70A31 31 0 1 0 247 70A31 31 0 1 0 185 70 M263 70A31 31 0 1 0 325 70A31 31 0 1 0 263 70 M346 10V100 M390 40L349 76 M363 64L392 100"/></svg>
</span>`;

export function send(message: unknown): Promise<unknown> {
  return chrome.runtime.sendMessage(message).catch(() => undefined);
}
