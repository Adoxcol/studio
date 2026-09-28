// Release notes and per-version downloads, read from the public GitHub
// Releases API. Each release body is the CHANGELOG.md section for that version
// (see tool/release_notes.dart), followed by GitHub's list of merged PRs.

const REPO = 'Adoxcol/studio';
const API = `https://api.github.com/repos/${REPO}/releases?per_page=30`;
const RELEASES_PAGE = `https://github.com/${REPO}/releases`;
const CACHE_KEY = 'studio-releases-v1';
const CACHE_MS = 10 * 60 * 1000;
const SHOWN_AT_FIRST = 6;

const PLATFORMS = [
  { label: 'Windows', match: (name) => name === 'studio-windows-setup.exe' || /-win-Setup\.exe$/i.test(name) },
  { label: 'macOS', match: (name) => name === 'studio-macos.zip' },
  { label: 'Linux', match: (name) => name === 'studio-linux-x64.tar.gz' },
];

const escapeHtml = (text) =>
  text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

/** Markdown inline subset: `code`, **bold**, [text](https://…). Escapes first. */
export function renderInline(text) {
  let html = escapeHtml(text);
  html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
  html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  html = html.replace(
    /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g,
    (_, label, url) => `<a href="${url}" target="_blank" rel="noopener">${label}</a>`,
  );
  return html;
}

/**
 * Sections of a release body: [{ title, items: [string] }].
 * Wrapped list items are joined; the auto-generated PR list is used only when
 * the release has no changelog notes (releases before v0.7.1).
 */
export function parseReleaseBody(body) {
  const text = (body || '').replace(/\r\n/g, '\n');
  const cut = text.search(/^## What's Changed|^\*\*Full Changelog\*\*/m);
  const notes = cut >= 0 ? text.slice(0, cut) : text;
  const sections = [];
  let current = null;
  for (const raw of notes.split('\n')) {
    const line = raw.trimEnd();
    const heading = line.match(/^#{2,4}\s+(.*)$/);
    if (heading) {
      current = { title: heading[1].trim(), items: [] };
      sections.push(current);
      continue;
    }
    const item = line.match(/^\s*[-*]\s+(.*)$/);
    if (item) {
      if (!current) {
        current = { title: 'Changes', items: [] };
        sections.push(current);
      }
      current.items.push(item[1]);
    } else if (/^\s{2,}\S/.test(line) && current?.items.length) {
      current.items[current.items.length - 1] += ` ${line.trim()}`;
    }
  }
  const withItems = sections.filter((s) => s.items.length);
  if (withItems.length) return withItems;

  // Older releases: GitHub's "* title by @author in https://…" list, grouped
  // by the PR's Conventional Commit type.
  const prs = [...text.matchAll(/^\*\s+(.+?)\s+by\s+@\S+\s+in\s+\S+$/gm)].map((m) => m[1]);
  const groups = new Map();
  for (const title of prs) {
    const pr = describePullRequest(title);
    if (!pr) continue;
    if (!groups.has(pr.group)) groups.set(pr.group, []);
    groups.get(pr.group).push(pr.text);
  }
  return GROUP_ORDER.filter((g) => groups.has(g)).map((g) => ({ title: g, items: groups.get(g) }));
}

const GROUP_ORDER = ['Added', 'Fixed', 'Faster', 'Other changes'];

/**
 * "fix(library): keep the source (#184)" -> { group: 'Fixed', text: 'Keep the source' }.
 * Release-preparation PRs are dropped; they are the release itself.
 */
export function describePullRequest(title) {
  let text = title.replace(/\s*\(#\d+\)$/, '').trim();
  let type = '';
  const conventional = text.match(/^(\w+)(\([^)]*\))?!?:\s*(.+)$/);
  if (conventional) {
    type = conventional[1].toLowerCase();
    text = conventional[3];
  } else if (/^⚡/.test(text)) {
    type = 'perf';
    text = text.replace(/^⚡\s*(Bolt:\s*)?/, '');
  }
  if (type === 'chore' && /\brelease\b|prepare v?\d/i.test(text)) return null;
  const group = { feat: 'Added', fix: 'Fixed', perf: 'Faster' }[type] || 'Other changes';
  return { group, text: text.charAt(0).toUpperCase() + text.slice(1) };
}

function downloads(release) {
  const links = [];
  for (const platform of PLATFORMS) {
    const asset = (release.assets || []).find((a) => platform.match(a.name));
    if (asset) links.push({ label: platform.label, url: asset.browser_download_url });
  }
  return links;
}

const kindClass = (title) => {
  const key = title.toLowerCase();
  return ['added', 'fixed', 'faster', 'changed', 'security', 'removed', 'deprecated'].includes(key)
    ? `kind-${key}`
    : 'kind-other';
};

const formatDate = (iso) =>
  new Date(iso).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });

function renderRelease(release, { latest }) {
  const sections = parseReleaseBody(release.body);
  const links = downloads(release);
  const version = escapeHtml(release.tag_name || release.name || '');
  const count = sections.reduce((n, s) => n + s.items.length, 0);
  const body = sections.length
    ? sections
        .map(
          (s) => `
        <div class="release-group">
          <h4 class="release-kind ${kindClass(s.title)}">${escapeHtml(s.title)}</h4>
          <ul>${s.items.map((i) => `<li>${renderInline(i)}</li>`).join('')}</ul>
        </div>`,
        )
        .join('')
    : '<p class="release-empty">No notes for this version.</p>';
  const downloadRow = `
    <div class="release-downloads">
      ${links
        .map(
          (l) => `<a class="release-download" href="${escapeHtml(l.url)}">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            ${escapeHtml(l.label)}</a>`,
        )
        .join('')}
      <a class="release-page-link" href="${escapeHtml(release.html_url)}" target="_blank" rel="noopener">Release page ↗</a>
    </div>`;
  const summary = `
    <span class="release-version">${version}</span>
    ${latest ? '<span class="release-badge">Latest</span>' : ''}
    <time class="release-date" datetime="${escapeHtml(release.published_at || '')}">${formatDate(release.published_at)}</time>
    <span class="release-count">${count} ${count === 1 ? 'change' : 'changes'}</span>`;
  return `
    <details class="release${latest ? ' is-latest' : ''}" ${latest ? 'open' : ''}>
      <summary class="release-summary">${summary}</summary>
      <div class="release-body">${body}${downloadRow}</div>
    </details>`;
}

async function loadReleases() {
  try {
    const cached = JSON.parse(sessionStorage.getItem(CACHE_KEY) || 'null');
    if (cached && Date.now() - cached.at < CACHE_MS) return cached.releases;
  } catch {
    // Storage unavailable (private mode); fetch instead.
  }
  const response = await fetch(API, { headers: { Accept: 'application/vnd.github+json' } });
  if (!response.ok) throw new Error(`GitHub returned ${response.status}`);
  const releases = (await response.json()).filter((r) => !r.draft && !r.prerelease);
  try {
    sessionStorage.setItem(CACHE_KEY, JSON.stringify({ at: Date.now(), releases }));
  } catch {
    // Ignore quota or privacy errors.
  }
  return releases;
}

export async function initChangelog(root = document.getElementById('changelog-list')) {
  if (!root) return;
  let releases;
  try {
    releases = await loadReleases();
  } catch {
    root.innerHTML = `<p class="changelog-status">Release notes could not be loaded right now.
      <a href="${RELEASES_PAGE}" target="_blank" rel="noopener">See every release on GitHub ↗</a></p>`;
    return;
  }
  if (!releases.length) {
    root.innerHTML = '<p class="changelog-status">No releases yet.</p>';
    return;
  }
  const html = releases.map((r, i) => renderRelease(r, { latest: i === 0 }));
  root.innerHTML = `
    <div class="release-list">${html.slice(0, SHOWN_AT_FIRST).join('')}</div>
    ${
      html.length > SHOWN_AT_FIRST
        ? `<div class="release-list release-older" hidden>${html.slice(SHOWN_AT_FIRST).join('')}</div>
           <button type="button" class="btn-secondary changelog-more">Show ${html.length - SHOWN_AT_FIRST} older versions</button>`
        : ''
    }
    <p class="changelog-footnote">Every build, including older ones, is also on
      <a href="${RELEASES_PAGE}" target="_blank" rel="noopener">GitHub Releases ↗</a>.</p>`;
  const more = root.querySelector('.changelog-more');
  more?.addEventListener('click', () => {
    root.querySelector('.release-older').hidden = false;
    more.remove();
  });
}
