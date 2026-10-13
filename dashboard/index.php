<?php

declare(strict_types=1);

// Borrow the current Omarchy theme so the dashboard matches the desktop.
$theme = [
    'mode' => 'dark', 'accent' => '#7aa2f7', 'background' => '#1a1b26', 'dark_background' => '#13141c',
    'lighter_background' => '#24283b', 'selection' => '#292e42', 'muted' => '#414868',
    'foreground' => '#a9b1d6', 'dark_foreground' => '#565f89', 'bright_foreground' => '#c0caf5',
    'red' => '#f7768e', 'yellow' => '#e0af68', 'green' => '#9ece6a', 'cyan' => '#449dab', 'magenta' => '#ad8ee6',
];
$colors = getenv('HOME') . '/.local/state/omarchy/current/theme/colors.toml';
foreach (is_readable($colors) ? file($colors, FILE_IGNORE_NEW_LINES) : [] as $line) {
    if (preg_match('/^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{3,8}|light|dark)"/', $line, $m) && isset($theme[$m[1]])) {
        $theme[$m[1]] = $m[2];
    }
}
$css = '';
foreach ($theme as $key => $value) {
    $css .= '--' . str_replace('_', '-', $key) . ':' . $value . ';';
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Herd</title>
<style>
:root { <?= $css ?> color-scheme: <?= $theme['mode'] === 'light' ? 'light' : 'dark' ?>; }
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--background); color: var(--foreground);
  font: 13px/1.5 "JetBrainsMono Nerd Font", "JetBrains Mono", ui-monospace, monospace;
}
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
.wrap { max-width: 1180px; margin: 0 auto; padding: 24px 20px 64px; }

header { display: flex; flex-wrap: wrap; align-items: center; gap: 12px 20px; margin-bottom: 20px; }
header h1 { margin: 0; font-size: 18px; color: var(--bright-foreground); letter-spacing: .02em; }
header h1 span { color: var(--accent); }
.health { display: flex; flex-wrap: wrap; gap: 8px; margin-left: auto; }
.chip {
  display: inline-flex; align-items: center; gap: 6px; padding: 3px 10px;
  border: 1px solid var(--muted); border-radius: 999px; font-size: 12px; white-space: nowrap;
}
.dot { width: 8px; height: 8px; border-radius: 50%; background: var(--dark-foreground); flex: none; }
.dot.on { background: var(--green); box-shadow: 0 0 6px var(--green); }
.dot.off { background: var(--red); }

nav { display: flex; gap: 4px; border-bottom: 1px solid var(--muted); margin-bottom: 20px; overflow-x: auto; }
nav button {
  background: none; border: 0; border-bottom: 2px solid transparent; color: var(--dark-foreground);
  font: inherit; padding: 8px 14px; cursor: pointer; white-space: nowrap;
}
nav button:hover { color: var(--foreground); }
nav button.active { color: var(--bright-foreground); border-bottom-color: var(--accent); }
nav .count { color: var(--dark-foreground); margin-left: 4px; }

.panel { display: none; }
.panel.active { display: block; }
h2 { font-size: 13px; text-transform: uppercase; letter-spacing: .08em; color: var(--dark-foreground); margin: 28px 0 10px; font-weight: 600; }
h2:first-child { margin-top: 0; }

.table-wrap { overflow-x: auto; border: 1px solid var(--muted); border-radius: 8px; }
table { width: 100%; border-collapse: collapse; }
th, td { text-align: left; padding: 9px 12px; border-bottom: 1px solid var(--selection); vertical-align: middle; }
th { font-weight: 600; color: var(--dark-foreground); font-size: 12px; background: var(--dark-background); }
tr:last-child td { border-bottom: 0; }
tr:hover td { background: color-mix(in srgb, var(--selection) 50%, transparent); }
td.path { color: var(--dark-foreground); max-width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; cursor: copy; }
td.actions { text-align: right; white-space: nowrap; }

.badge { display: inline-block; padding: 1px 8px; border-radius: 4px; font-size: 11px; background: var(--selection); color: var(--foreground); }
.badge.laravel { color: var(--red); }
.badge.php { color: var(--magenta); }
.badge.node { color: var(--green); }
.badge.proxy { color: var(--cyan); }
.badge.static { color: var(--yellow); }
.badge.accent { color: var(--accent); }
.badge.warn { color: var(--yellow); }

button.btn, select, input {
  font: inherit; color: var(--foreground); background: var(--dark-background);
  border: 1px solid var(--muted); border-radius: 6px; padding: 4px 10px;
}
button.btn { cursor: pointer; }
button.btn:hover:not(:disabled) { border-color: var(--accent); color: var(--bright-foreground); }
button.btn.primary { background: var(--accent); border-color: var(--accent); color: var(--background); }
button.btn.primary:hover:not(:disabled) { filter: brightness(1.1); color: var(--background); }
button.btn.danger:hover:not(:disabled) { border-color: var(--red); color: var(--red); }
button.btn:disabled { opacity: .5; cursor: progress; }
input { min-width: 0; }
input:focus, select:focus, button:focus-visible { outline: 1px solid var(--accent); outline-offset: 1px; }

.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
.card { border: 1px solid var(--muted); border-radius: 8px; padding: 14px; background: var(--dark-background); display: flex; flex-direction: column; gap: 10px; }
.card.dim { opacity: .65; background: transparent; border-style: dashed; }
.card-head { display: flex; align-items: center; gap: 8px; }
.card-head strong { color: var(--bright-foreground); font-size: 15px; }
.card-head .badge { margin-left: auto; }
.card .meta { color: var(--dark-foreground); font-size: 12px; }
.card .row { display: flex; flex-wrap: wrap; gap: 6px; }
dl { display: grid; grid-template-columns: auto 1fr; gap: 2px 12px; margin: 0; font-size: 12px; }
dt { color: var(--dark-foreground); }
dd { margin: 0; color: var(--bright-foreground); cursor: copy; }
pre.env {
  margin: 0; padding: 8px 10px; background: var(--background); border: 1px solid var(--selection);
  border-radius: 6px; font-size: 12px; overflow-x: auto; cursor: copy; color: var(--foreground);
}

form.add { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-bottom: 12px; }
form.add input[name=path] { flex: 1 1 280px; }
form.add input[name=name] { flex: 0 1 160px; }
form.add input[name=target] { flex: 0 1 140px; }
.hint { color: var(--dark-foreground); font-size: 12px; margin: 6px 0 0; }
.parked { display: flex; flex-wrap: wrap; gap: 8px; }
.empty { padding: 20px; text-align: center; color: var(--dark-foreground); }

#toast {
  position: fixed; right: 16px; bottom: 16px; max-width: min(460px, calc(100vw - 32px));
  padding: 10px 14px; border-radius: 8px; border: 1px solid var(--muted);
  background: var(--lighter-background); color: var(--bright-foreground);
  box-shadow: 0 8px 24px rgb(0 0 0 / .35); opacity: 0; transform: translateY(8px);
  transition: opacity .2s, transform .2s; pointer-events: none;
}
#toast.show { opacity: 1; transform: none; }
#toast.error { border-color: var(--red); }
#error { display: none; padding: 12px 14px; border: 1px solid var(--red); border-radius: 8px; margin-bottom: 16px; color: var(--red); }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1><span>󰒋</span> Herd</h1>
    <div class="health" id="health"></div>
    <button class="btn" id="refresh" title="Refresh">Refresh</button>
  </header>
  <div id="error"></div>

  <nav id="tabs">
    <button data-tab="sites">Sites<span class="count" id="count-sites"></span></button>
    <button data-tab="php">PHP<span class="count" id="count-php"></span></button>
    <button data-tab="node">Node<span class="count" id="count-node"></span></button>
    <button data-tab="databases">Databases<span class="count" id="count-databases"></span></button>
  </nav>

  <section class="panel" id="panel-sites">
    <form class="add" id="add-site">
      <select name="kind" aria-label="What to add">
        <option value="park">Park a folder</option>
        <option value="link">Link one folder</option>
        <option value="proxy">Proxy a dev server</option>
      </select>
      <input name="name" placeholder="name (.test)" aria-label="Site name" hidden>
      <input name="path" placeholder="/home/you/Work" aria-label="Folder path">
      <input name="target" placeholder="port, e.g. 5173" aria-label="Port" hidden>
      <button class="btn primary" type="submit">Add</button>
    </form>
    <p class="hint" id="add-hint"></p>
    <h2>Sites</h2>
    <div class="table-wrap"><table>
      <thead><tr><th>Site</th><th>Type</th><th>PHP</th><th>Node</th><th>Folder</th><th></th></tr></thead>
      <tbody id="sites"></tbody>
    </table></div>
    <h2>Parked folders</h2>
    <div class="parked" id="parked"></div>
  </section>

  <section class="panel" id="panel-php">
    <h2>PHP versions</h2>
    <div class="cards" id="php"></div>
    <p class="hint">Each version runs its own PHP-FPM. The terminal's <code>php</code> follows the site you're in; <code>php8.3</code> etc. run a version directly. Prebuilt binaries can't load Xdebug.</p>
  </section>

  <section class="panel" id="panel-node">
    <h2>Installed</h2>
    <div class="cards" id="node-installed"></div>
    <h2>Available</h2>
    <div class="cards" id="node-available"></div>
    <p class="hint">Managed by mise. Per-site versions are saved in the project's <code>mise.local.toml</code>.</p>
  </section>

  <section class="panel" id="panel-databases">
    <div class="cards" id="databases"></div>
    <p class="hint">Databases run under your user and store data in <code>~/.local/share/omarchy-herd/data</code>. Browse them with Beekeeper Studio, TablePlus or DBeaver using these details.</p>
  </section>
</div>
<div id="toast" role="status" aria-live="polite"></div>

<script>
const state = { status: null, phpAvailable: null, nodeAvailable: null, busy: false };
const $ = (sel) => document.querySelector(sel);
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

function toast(message, isError = false) {
  const el = $('#toast');
  el.textContent = message;
  el.className = 'show' + (isError ? ' error' : '');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (el.className = ''), isError ? 7000 : 3500);
}

async function get(action) {
  const response = await fetch('api.php?action=' + encodeURIComponent(action));
  const data = await response.json();
  if (data && data.ok === false) throw new Error(data.error);
  return data;
}

async function run(payload, button) {
  if (button) button.disabled = true;
  state.busy = true;
  try {
    const response = await fetch('api.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Herd': '1' },
      body: JSON.stringify(payload),
    });
    const data = await response.json();
    if (!data.ok) throw new Error(data.error || 'Something went wrong');
    toast(data.message);
    if (payload.action.startsWith('php-')) state.phpAvailable = null;
    if (payload.action.startsWith('node-')) state.nodeAvailable = null;
    await refresh();
  } catch (error) {
    toast(error.message, true);
  } finally {
    state.busy = false;
    if (button) button.disabled = false;
  }
}

async function copy(text) {
  try {
    await navigator.clipboard.writeText(text);
    toast('Copied: ' + (text.length > 60 ? text.slice(0, 57) + '…' : text));
  } catch {
    toast('Copy failed, select the text instead', true);
  }
}

function renderHealth(s) {
  const chip = (on, label) => `<span class="chip"><span class="dot ${on ? 'on' : 'off'}"></span>${label}</span>`;
  $('#health').innerHTML = chip(s.web.caddy, 'Web server') + chip(s.web.dns && s.web.resolves, '.' + esc(s.tld) + ' DNS') + chip(s.web.https_trusted, 'HTTPS');
}

function renderSites(s) {
  const installed = s.php.versions.map((v) => v.version);
  const nodes = s.node.versions.map((v) => v.version);
  $('#count-sites').textContent = s.sites.length;
  $('#sites').innerHTML = s.sites.length ? s.sites.map((site) => {
    const isProxy = site.source === 'proxy';
    const php = isProxy ? `<span class="badge proxy">→ ${esc(site.proxy)}</span>` : `
      <select data-isolate="${esc(site.name)}" aria-label="PHP for ${esc(site.domain)}">
        <option value="" ${site.isolated ? '' : 'selected'}>default (${esc(s.php.default)})</option>
        ${installed.map((v) => `<option value="${esc(v)}" ${site.isolated && site.php === v ? 'selected' : ''}>${esc(v)}</option>`).join('')}
      </select>${site.php_installed ? '' : ' <span class="badge warn" title="Install this PHP version">missing</span>'}`;
    const node = isProxy || !site.path ? '<span class="meta">-</span>' : `
      <select data-node="${esc(site.name)}" aria-label="Node for ${esc(site.domain)}">
        <option value="">${esc(site.node || 'default')}</option>
        <option value="__default">use default</option>
        ${nodes.map((v) => `<option value="${esc(v)}">${esc(v)}</option>`).join('')}
      </select>`;
    const remove = site.source === 'link' && site.name !== 'herd'
      ? `<button class="btn danger" data-run='${esc(JSON.stringify({ action: 'unlink', name: site.name }))}'>Unlink</button>`
      : isProxy ? `<button class="btn danger" data-run='${esc(JSON.stringify({ action: 'unproxy', name: site.name }))}'>Remove</button>` : '';
    return `<tr>
      <td><a href="${esc(site.url)}" target="_blank" rel="noopener">${esc(site.domain)}</a></td>
      <td><span class="badge ${esc(site.type)}">${esc(site.type)}</span>${site.source === 'link' ? ' <span class="badge">linked</span>' : ''}</td>
      <td>${php}</td>
      <td>${node}</td>
      <td class="path" title="Click to copy" data-copy="${esc(site.path || '')}">${esc(site.path ? site.path.replace(/^\/home\/[^/]+/, '~') : '')}</td>
      <td class="actions">${remove}</td>
    </tr>`;
  }).join('') : '<tr><td colspan="6" class="empty">No sites yet. Park a folder that holds your projects.</td></tr>';

  $('#parked').innerHTML = s.parked.length ? s.parked.map((dir) => `
    <span class="chip">${esc(dir.replace(/^\/home\/[^/]+/, '~'))}
      <button class="btn danger" style="padding:0 6px" title="Unpark" data-run='${esc(JSON.stringify({ action: 'unpark', path: dir }))}'>×</button>
    </span>`).join('') : '<span class="meta">None. Park a folder above and every project inside gets its own .test domain.</span>';
}

function renderPhp(s) {
  const installed = Object.fromEntries(s.php.versions.map((v) => [v.version, v]));
  const series = (state.phpAvailable || []).length ? state.phpAvailable : ['8.0', '8.1', '8.2', '8.3', '8.4', '8.5'].map((version) => ({ version, latest: null }));
  $('#count-php').textContent = s.php.versions.length;
  $('#php').innerHTML = series.slice().reverse().map((available) => {
    const v = installed[available.version];
    if (!v) {
      return `<div class="card dim">
        <div class="card-head"><strong>PHP ${esc(available.version)}</strong></div>
        <div class="meta">${available.latest ? 'Latest ' + esc(available.latest) : 'Not installed'}</div>
        <div class="row"><button class="btn" data-run='${esc(JSON.stringify({ action: 'php-install', version: available.version }))}'>Install</button></div>
      </div>`;
    }
    const sites = s.sites.filter((site) => site.php === v.version).length;
    const update = available.latest && available.latest !== v.patch ? `<span class="badge warn">${esc(available.latest)} available</span>` : '';
    return `<div class="card">
      <div class="card-head"><span class="dot ${v.running ? 'on' : 'off'}"></span><strong>PHP ${esc(v.version)}</strong>
        ${v.default ? '<span class="badge accent">default</span>' : ''}</div>
      <div class="meta">${esc(v.patch)} · ${sites} site${sites === 1 ? '' : 's'} ${update}</div>
      <div class="meta" data-copy="${esc(v.ini)}" style="cursor:copy" title="Click to copy">php.ini: ${esc(v.ini.replace(/^\/home\/[^/]+/, '~'))}</div>
      <div class="row">
        ${v.default ? '' : `<button class="btn" data-run='${esc(JSON.stringify({ action: 'php-default', version: v.version }))}'>Make default</button>`}
        <button class="btn" data-run='${esc(JSON.stringify({ action: v.running ? 'restart' : 'start', service: 'php-' + v.version }))}'>${v.running ? 'Restart' : 'Start'}</button>
        ${update ? `<button class="btn" data-run='${esc(JSON.stringify({ action: 'php-install', version: v.version }))}'>Update</button>` : ''}
        ${v.default ? '' : `<button class="btn danger" data-run='${esc(JSON.stringify({ action: 'php-uninstall', version: v.version }))}'>Remove</button>`}
      </div>
    </div>`;
  }).join('');
}

function renderNode(s) {
  $('#count-node').textContent = s.node.versions.length;
  $('#node-installed').innerHTML = s.node.versions.length ? s.node.versions.map((v) => `
    <div class="card">
      <div class="card-head"><strong>Node ${esc(v.version)}</strong>${v.default ? '<span class="badge accent">default</span>' : ''}</div>
      <div class="meta">${s.sites.filter((site) => site.node === v.version).length} site(s) use it</div>
      <div class="row">
        ${v.default ? '' : `<button class="btn" data-run='${esc(JSON.stringify({ action: 'node-default', version: v.version }))}'>Make default</button>
        <button class="btn danger" data-run='${esc(JSON.stringify({ action: 'node-uninstall', version: v.version }))}'>Remove</button>`}
      </div>
    </div>`).join('') : '<div class="meta">No Node versions installed.</div>';

  const available = state.nodeAvailable;
  $('#node-available').innerHTML = !available ? '<div class="meta">Loading…</div>' : available.map((v) => `
    <div class="card ${v.installed ? '' : 'dim'}">
      <div class="card-head"><strong>Node ${esc(v.major)}</strong>${v.lts ? '<span class="badge node">LTS</span>' : ''}</div>
      <div class="meta">Latest ${esc(v.latest)}${v.installed ? ' · installed ' + esc(v.installed) : ''}</div>
      <div class="row">${v.installed === v.latest ? '' : `<button class="btn" data-run='${esc(JSON.stringify({ action: 'node-install', version: v.latest }))}'>${v.installed ? 'Update' : 'Install'} ${esc(v.latest)}</button>`}</div>
    </div>`).join('');
}

function renderDatabases(s) {
  $('#count-databases').textContent = s.services.filter((svc) => svc.running).length + '/' + s.services.length;
  const env = {
    mariadb: 'DB_CONNECTION=mariadb\nDB_HOST=127.0.0.1\nDB_PORT=3306\nDB_DATABASE=laravel\nDB_USERNAME=root\nDB_PASSWORD=',
    postgres: 'DB_CONNECTION=pgsql\nDB_HOST=127.0.0.1\nDB_PORT=5432\nDB_DATABASE=laravel\nDB_USERNAME=postgres\nDB_PASSWORD=',
    valkey: 'REDIS_CLIENT=phpredis\nREDIS_HOST=127.0.0.1\nREDIS_PORT=6379\nREDIS_PASSWORD=null',
  };
  $('#databases').innerHTML = s.services.map((svc) => `
    <div class="card ${svc.installed ? '' : 'dim'}">
      <div class="card-head"><span class="dot ${svc.running ? 'on' : 'off'}"></span><strong>${esc(svc.name)}</strong>
        <span class="badge">${esc(svc.version || 'not installed')}</span></div>
      <dl>
        <dt>Host</dt><dd data-copy="${esc(svc.host)}">${esc(svc.host)}</dd>
        <dt>Port</dt><dd data-copy="${esc(svc.port)}">${esc(svc.port)}</dd>
        ${svc.user ? `<dt>User</dt><dd data-copy="${esc(svc.user)}">${esc(svc.user)}</dd>` : ''}
        <dt>Password</dt><dd>(empty)</dd>
      </dl>
      <pre class="env" data-copy="${esc(env[svc.id])}" title="Click to copy for .env">${esc(env[svc.id])}</pre>
      <div class="row">
        ${svc.running
          ? `<button class="btn" data-run='${esc(JSON.stringify({ action: 'restart', service: svc.id }))}'>Restart</button>
             <button class="btn danger" data-run='${esc(JSON.stringify({ action: 'stop', service: svc.id }))}'>Stop</button>`
          : `<button class="btn primary" data-run='${esc(JSON.stringify({ action: 'start', service: svc.id }))}' ${svc.installed ? '' : 'disabled'}>Start</button>`}
      </div>
    </div>`).join('');
}

function render() {
  const s = state.status;
  if (!s) return;
  renderHealth(s);
  renderSites(s);
  renderPhp(s);
  renderNode(s);
  renderDatabases(s);
}

async function refresh() {
  try {
    state.status = await get('status');
    $('#error').style.display = 'none';
    render();
  } catch (error) {
    $('#error').textContent = 'Could not load status: ' + error.message;
    $('#error').style.display = 'block';
  }
  if (!state.phpAvailable) get('php-available').then((list) => { state.phpAvailable = list; render(); }).catch(() => {});
  if (!state.nodeAvailable) get('node-available').then((list) => { state.nodeAvailable = list; render(); }).catch(() => {});
}

function showTab(name) {
  document.querySelectorAll('nav button').forEach((b) => b.classList.toggle('active', b.dataset.tab === name));
  document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('active', p.id === 'panel-' + name));
  history.replaceState(null, '', '#' + name);
}

document.addEventListener('click', (event) => {
  const tab = event.target.closest('nav button');
  if (tab) return showTab(tab.dataset.tab);
  const action = event.target.closest('[data-run]');
  if (action) return run(JSON.parse(action.dataset.run), action);
  const copyable = event.target.closest('[data-copy]');
  if (copyable && copyable.dataset.copy) copy(copyable.dataset.copy);
});

document.addEventListener('change', (event) => {
  const el = event.target;
  if (el.dataset.isolate) {
    run(el.value ? { action: 'isolate', site: el.dataset.isolate, version: el.value } : { action: 'unisolate', site: el.dataset.isolate }, el);
  } else if (el.dataset.node && el.value) {
    run(el.value === '__default' ? { action: 'node-reset', site: el.dataset.node } : { action: 'node-use', site: el.dataset.node, version: el.value }, el);
  }
});

const form = $('#add-site');
const hints = {
  park: 'Every folder inside becomes <folder>.test, like Herd\'s parked paths.',
  link: 'Serve a single folder, anywhere on disk, as <name>.test.',
  proxy: 'Send <name>.test to a dev server such as Vite (5173) or Next.js (3000).',
};
function syncForm() {
  const kind = form.kind.value;
  form.name.hidden = kind === 'park';
  form.path.hidden = kind === 'proxy';
  form.target.hidden = kind !== 'proxy';
  $('#add-hint').textContent = hints[kind];
}
form.kind.addEventListener('change', syncForm);
form.addEventListener('submit', (event) => {
  event.preventDefault();
  const kind = form.kind.value;
  const payload = { action: kind };
  if (kind !== 'park') payload.name = form.name.value.trim().toLowerCase();
  if (kind !== 'proxy') payload.path = form.path.value.trim();
  if (kind === 'proxy') payload.target = form.target.value.trim();
  run(payload, form.querySelector('button[type=submit]')).then(() => form.reset()).then(syncForm);
});

$('#refresh').addEventListener('click', () => refresh());
showTab(['sites', 'php', 'node', 'databases'].includes(location.hash.slice(1)) ? location.hash.slice(1) : 'sites');
syncForm();
refresh();
setInterval(() => { if (!document.hidden && !state.busy) refresh(); }, 10000);
</script>
</body>
</html>
