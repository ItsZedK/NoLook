// blocked page
import { setHtml } from './dom';
import type { Saved } from './types';
import { stringsFor } from './strings';
import { blockIcon, brandmark, esc, icon, send } from './ui';

const params = new URLSearchParams(location.search);
const blockId = params.get('b') ?? '';
const url = decodeURIComponent(location.hash.slice(1));

/** short url */
function shortSite(u: string, fallback: string): string {
  try {
    const p = new URL(u);
    const path = p.pathname.split('/').filter(Boolean).slice(0, 2).join('/');
    return p.hostname.replace(/^www\./, '') + (path ? `/${path}` : '');
  } catch {
    return u || fallback;
  }
}

/** today's count, local only */
async function countToday(site: string): Promise<number> {
  const day = new Date().toDateString();
  const key = 'blockedCounts';
  const saved = ((await chrome.storage.local.get(key))[key] ?? {}) as { day?: string; counts?: Record<string, number> };
  const counts = saved.day === day ? (saved.counts ?? {}) : {};
  counts[site] = (counts[site] ?? 0) + 1;
  await chrome.storage.local.set({ [key]: { day, counts } });
  return counts[site];
}

async function render() {
  const saved = (await chrome.storage.local.get('rules')) as Saved;
  const block = saved.rules?.blocks.find((b) => b.id === blockId);
  const t = stringsFor(saved.rules);
  document.documentElement.lang = saved.rules?.settings?.lang ?? 'en';
  document.title = t.pageTitle;
  const site = shortSite(url, t.thisSite);
  const times = await countToday(site);
  void send({ type: 'blockedPage', blockId, target: site });

  // "X is locked until <date>" if there's a date, else just the block name
  const why = esc(
    block
      ? block.locked && block.lockBold
        ? t.lockedBy(block.name, block.lockLine)
        : t.blockedByBlock(block.name)
      : t.blockedByNoLook,
  );

  setHtml(document.getElementById('app')!, `
    <header>${brandmark}</header>
    <div class="center"><div class="box">
      <div class="tile c-${block?.color ?? 'teal'}">${block ? blockIcon(block, 44) : icon('block', 44)}</div>
      <h1 class="display"><span class="site">${esc(site)}</span> ${esc(t.isBlocked)}</h1>
      <div class="why">${icon('lock', 20, true)}${why}</div>
      <div class="btns">
        <button class="btn filled big has-ic" id="back">${icon('arrow_back', 20)}${esc(t.goBack)}</button>
        ${block ? `<button class="btn outlined big" id="unlock">${esc(block.locked ? t.unlockEarly : t.turnOffBlock(block.name))}</button>` : ''}
      </div>
    </div></div>
    <div class="foot">${esc(t.blockedTimes(times))}</div>`);

  document.getElementById('back')!.addEventListener('click', () => {
    if (history.length > 1) history.back();
    else location.href = 'about:blank';
  });
  document.getElementById('unlock')?.addEventListener('click', () => {
    void send({ type: block!.locked ? 'unlock' : 'toggle', blockId });
  });
}

void render();

// unblocked, go to the original page
chrome.storage.onChanged.addListener((changes) => {
  const rules = changes.rules?.newValue as Saved['rules'];
  const b = rules?.blocks.find((x) => x.id === blockId);
  if (url && rules && (!b || !b.active)) location.replace(url);
});
