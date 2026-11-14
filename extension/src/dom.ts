/**
 * our own markup (escaped via esc()), DOMParser instead of innerHTML
 */
export function setHtml(target: Element, html: string) {
  const doc = new DOMParser().parseFromString(`<!doctype html><body>${html}</body>`, 'text/html');
  target.replaceChildren(...doc.body.childNodes);
}
