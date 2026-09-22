// dd2-forge -- reads the JSON the REFramework panel writes. No build step.
const DATA = 'data/';
const $ = (h) => { const t = document.createElement('template'); t.innerHTML = h.trim(); return t.content.firstChild; };
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const num = (n) => Number(n).toLocaleString();

const cache = {};
async function load(name) {
  if (cache[name] !== undefined) return cache[name];
  try {
    const r = await fetch(DATA + name, { cache: 'no-cache' });
    cache[name] = r.ok ? await r.json() : null;
  } catch { cache[name] = null; }
  return cache[name];
}

// ---------------------------------------------------------------- primitives
const tile = (k, l, s) => `<div class="card tile"><div class="k">${esc(k)}</div>
  <div class="l">${esc(l)}</div>${s ? `<div class="s">${esc(s)}</div>` : ''}</div>`;

// One hue, light->dark by share of max. The number is always printed, so the
// colour is reinforcement and never the only channel.
function bars(rows) {
  const max = Math.max(1, ...rows.map(r => r.v));
  return `<div class="bars">` + rows.map(r => {
    // A zero draws nothing. A 2% stub for a zero reads as "a little", which is
    // the opposite of true -- the number beside it is the honest channel.
    const pct = r.v === 0 ? 0 : Math.max(2, Math.round(r.v / max * 100));
    const step = r.v / max > .66 ? 'var(--e4)' : r.v / max > .33 ? 'var(--e3)' : 'var(--e2)';
    return `<div class="row"><div class="nm" title="${esc(r.n)}">${esc(r.n)}</div>
      <div class="track"><div class="fill" style="width:${pct}%;background:${step}"></div></div>
      <div class="v">${num(r.v)}</div></div>`;
  }).join('') + `</div>`;
}
const chip = (cls, word) => `<span class="chip ${cls}"><span class="dot"></span>${esc(word)}</span>`;

function table(cols, rows, cls = '') {
  if (!rows.length) return `<div class="empty">Nothing to show.</div>`;
  return `<div class="scroll ${cls}"><table><thead><tr>` +
    cols.map(c => `<th>${esc(c)}</th>`).join('') + `</tr></thead><tbody>` +
    rows.map(r => `<tr>` + r.map(c => `<td>${c}</td>`).join('') + `</tr>`).join('') +
    `</tbody></table></div>`;
}

// ---------------------------------------------------------------- data shape
const GEAR_CLASSES = ['Sword','Mace','Shield','Greatsword','Hammer','Dagger','Bow','Staff',
  'Archistaff','MagickBow','Duospear','Censer','Head','Body','Legs','Cloak','Ring'];
const WEAPONS = new Set(GEAR_CLASSES.slice(0, 12));
const EXCLUDED = {
  93:  ['Gold', 'has its own amount — lives in the refill panel'],
  78:  ['Wakestone Shard', 'auto-combines on grant and crashes'],
  710: ['Dragonsbaulk Draught', 'the call this game has actually died on'],
  397: ['Empowered Godsbane Blade', 'excluded by request'],
};

async function forge() {
  const [cat, ref, cats, suite] = await Promise.all([
    load('item_catalog.json'), load('equip_reference.json'),
    load('item_categories.json'), load('suite.json'),
  ]);
  const real = (cat || []).filter(x => x.name !== 'Invalid');
  const invalid = (cat || []).length - real.length;
  const byName = new Map(); const byId = new Map();
  real.forEach(x => { byId.set(x.id, x.name); if (!byName.has(x.name.toLowerCase())) byName.set(x.name.toLowerCase(), x.id); });

  const gear = []; // {cls,name,id}
  for (const cls of GEAR_CLASSES) for (const n of (ref?.[cls] || []))
    gear.push({ cls, name: n, id: byName.get(n.toLowerCase()) ?? null });

  const other = []; // {cat,id,name}
  for (const [c, ids] of Object.entries(cats || {})) for (const id of ids)
    other.push({ cat: c, id, name: byId.get(id) || `id ${id}` });

  const coveredIds = new Set([...gear.map(g => g.id).filter(Boolean), ...other.map(o => o.id)]);
  const orphans = real.filter(x => !coveredIds.has(x.id) && !EXCLUDED[x.id]);
  return { cat, real, invalid, gear, other, coveredIds, orphans, suite, byId };
}

// ---------------------------------------------------------------- the tabs
const TABS = [];
const add = (id, label, render) => TABS.push({ id, label, render });

add('overview', 'Overview', async () => {
  const f = await forge();
  const ours = (f.suite?.scripts || []).filter(s => s.ours && s.state === 'active');
  const covered = f.gear.filter(g => g.id).length + f.other.length;
  return `<h1>dd2-forge</h1>
  <p class="lede">A REFramework workbench for Dragon's Dogma 2, build ${esc(f.suite?.build || '3.2.0.0')} on
  ${esc(f.suite?.platform || 'Steam / PC')}. Everything on this site is read from the JSON the panel
  writes on the machine running the game, so it reflects a real save rather than a brochure.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(num(f.real.length), 'catalog rows', `+${num(f.invalid)} empty "Invalid" slots`)}
    ${tile(num(covered), 'reachable', `${f.orphans.length} orphans`)}
    ${tile(num(f.gear.length), 'gear items', '12 weapon classes, 5 slots')}
    ${tile(String(ours.length), 'scripts armed', 'dd2forge_* only')}
  </div>
  <h2>Coverage</h2>
  <p class="lede">Every real catalog row is reachable from a button, except four held back on purpose.</p>
  ${bars([
    { n: 'Gear (by name)', v: f.gear.filter(g => g.id).length },
    { n: 'Other (by ID)', v: f.other.length },
    { n: 'Empty slots', v: f.invalid },
    { n: 'Held back', v: Object.keys(EXCLUDED).length },
    { n: 'Orphans', v: f.orphans.length },
  ])}
  <h2>Held back on purpose</h2>
  ${table(['ID', 'Item', 'Why'], Object.entries(EXCLUDED).map(([id, [n, why]]) =>
    [`<span class="mono">${id}</span>`, esc(n), `<span style="color:var(--ink2)">${esc(why)}</span>`]))}
  <div class="note">Two sources, two authorities: for gear the public databases are the authority and the
  catalog is audited against them. For everything else the game's own ID dump is the authority and the
  databases are the thing being audited — they list 267 non-equipment items against our 345.</div>`;
});

add('items', 'Items', async () => {
  const f = await forge();
  const rows = [
    ...f.gear.map(g => ({ group: WEAPONS.has(g.cls) ? 'Weapon' : 'Armour', cls: g.cls, id: g.id, name: g.name, via: 'name' })),
    ...f.other.map(o => ({ group: 'Other', cls: o.cat, id: o.id, name: o.name, via: 'id' })),
  ];
  const classes = [...new Set(rows.map(r => r.cls))].sort();
  const counts = classes.map(c => ({ n: c, v: rows.filter(r => r.cls === c).length })).sort((a, b) => b.v - a.v);
  return `<h1>Items</h1>
  <p class="lede">${num(rows.length)} items across ${classes.length} classes. Gear resolves by name so it stays
  auditable against public databases; everything else resolves by ID, because a herb has no wiki table to
  check a name against and an ID never gets renamed or re-localised.</p>
  <h2>By class</h2>${bars(counts)}
  <h2>Catalog</h2>
  <div class="controls">
    <input type="search" id="q" placeholder="Search name or ID…">
    <select id="grp"><option value="">All groups</option>${['Weapon','Armour','Other'].map(g => `<option>${g}</option>`).join('')}</select>
    <select id="cls"><option value="">All classes</option>${classes.map(c => `<option>${esc(c)}</option>`).join('')}</select>
    <span class="count" id="cnt"></span>
  </div>
  <div id="tbl"></div>
  <script type="application/json" id="rows">${JSON.stringify(rows)}</script>`;
});

add('characters', 'Characters', async () => {
  const [p24, p28, p21, dcp] = await Promise.all([
    load('phase24.json'), load('phase28.json'), load('phase21.json'), load('dcp_probe.json')]);
  const w = p24?.written || [];
  const arisen = w.filter(x => /ARISEN/i.test(JSON.stringify(x))).length;
  const pawn = w.filter(x => /AVRIL|PAWN/i.test(JSON.stringify(x))).length;
  return `<h1>Characters</h1>
  <p class="lede">The Arisen and the main pawn are written separately. Ranks, core skills, weapon skills at
  level 2 and augments go to both — ten vocations for the Arisen, six for the pawn, which is correct since
  pawns cannot take the advanced vocations.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(String(arisen || '—'), 'Arisen writes', 'ranks · skills · augments')}
    ${tile(String(pawn || '—'), 'Pawn writes', '6 eligible vocations')}
    ${tile(String((p21?.written || []).length || '—'), 'gear upgraded', 'enhanceEquip records')}
    ${tile(dcp ? 'probed' : 'unknown', 'DCP', dcp ? 'setter identified' : 'run Phase 29')}
  </div>
  <h2>DCP — the open gap</h2>
  <p class="lede">Ranks are set with <code>setJobExpWithJobRank</code> and skills are enabled directly, which
  sidesteps the currency entirely: everything ends up bought and the DCP balance is never touched. The engine
  calls it <strong>JobPoint</strong>, not DCP. typecache carries the name but holds fields only — no method
  signatures — so it cannot name the setter. Phase 29 reads the live type definition to find it.</p>
  ${dcp ? table(['Object', 'Type', 'Fields', 'Methods'], Object.entries(dcp).map(([k, v]) =>
    [esc(k), `<span class="mono">${esc(v.type)}</span>`,
     `<span class="mono">${(v.fields || []).join('<br>') || '—'}</span>`,
     `<span class="mono">${(v.methods || []).join('<br>') || '—'}</span>`]))
   : `<div class="empty">No <code>dcp_probe.json</code> yet — press the Phase 29 button in game, then re-push.</div>`}
  <h2>Affinity</h2>
  ${p28 ? `<p class="lede">${num((p28.written || []).length)} records written by Phase 28.</p>` :
    `<div class="empty">No phase28.json.</div>`}`;
});

// DD2 equip slot indices, read off the probe rather than assumed: the dump's
// `slot` field is the loadout position, not the item category.
const SLOT = { 0: 'Primary', 1: 'Secondary', 2: 'Head', 3: 'Body', 4: 'Legs', 5: 'Cloak', 6: 'Ring', 7: 'Ring' };

add('equipment', 'Equipment', async () => {
  const probe = await load('enhance_probe.json');
  // The dump carries empty trailing slots -- rows with no name and no itemId.
  // They are unfilled loadout positions, not gear, and showing them as "—"
  // makes an 11-piece loadout look like 4 things failed to read.
  const raw = probe?.equipped;
  const list = Array.isArray(raw) ? raw.filter(r => r && r.name && r.itemId) : null;
  const emptySlots = Array.isArray(raw) ? raw.length - (list?.length || 0) : 0;
  if (!Array.isArray(list) || !list.length) {
    return `<h1>Equipment</h1><div class="empty">No <code>equipped</code> array in
      <code>enhance_probe.json</code> yet — press the gear-upgrade probe in game, then refresh the data.</div>`;
  }
  const maxed = list.filter(r => r.enhNum >= 4).length;
  const avg = (list.reduce((a, r) => a + (r.enhNum || 0), 0) / list.length).toFixed(1);
  const lvl = (n) => n >= 4 ? chip('ok', `+${n}`) : n >= 2 ? chip('warn', `+${n}`) : chip('bad', `+${n}`);
  const rows = list.slice().sort((a, b) => (a.slot ?? 99) - (b.slot ?? 99)).map(r => [
    esc(r.name || '—'),
    `<span class="mono">${esc(r.itemId)}</span>`,
    esc(SLOT[r.slot] ?? `slot ${r.slot}`),
    lvl(r.enhNum ?? 0),
    `<span class="mono">${[r.enhType0, r.enhType1, r.enhType2].join(' / ')}</span>`,
  ]);
  return `<h1>Equipment</h1>
  <p class="lede">What the upgrade probe last read back from the live game — not a claim, a measurement.
  <code>enhNum</code> is the upgrade level and <code>enhType0/1/2</code> are the three Dragonforge
  enhancement tracks.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(String(list.length), 'pieces equipped', emptySlots ? `${emptySlots} slots empty` : 'all slots filled')}
    ${tile(`${maxed}/${list.length}`, 'at +4', 'fully upgraded')}
    ${tile(`+${avg}`, 'average level', 'across equipped pieces')}
    ${tile(String(new Set(list.map(r => r.slot)).size), 'slot types', 'in use')}
  </div>
  <h2>Upgrade level by piece</h2>
  ${bars(list.slice().sort((a, b) => (b.enhNum || 0) - (a.enhNum || 0)).map(r => ({ n: r.name, v: r.enhNum || 0 })))}
  <h2>Loadout</h2>
  ${table(['Item', 'ID', 'Slot', 'Upgrade', 'Enhance tracks'], rows)}
  <div class="note">Cloaks are not upgradable in DD2, so a cloak showing +0 here is correct rather than a
  missed write. The probe reports the character context id it read from, which is how we caught a stale
  CharaID earlier in the project.</div>`;
});

const kb = (b) => b >= 1048576 ? (b / 1048576).toFixed(1) + ' MB' : Math.round(b / 1024) + ' KB';
const ago = (iso) => {
  if (!iso) return '—';
  const h = (Date.now() - new Date(iso).getTime()) / 3.6e6;
  if (h < 1) return Math.max(1, Math.round(h * 60)) + 'm ago';
  if (h < 48) return h.toFixed(h < 10 ? 1 : 0) + 'h ago';
  return Math.round(h / 24) + 'd ago';
};

add('saves', 'Saves', async () => {
  const s = await load('saves.json');
  if (!s || s.error) return `<h1>Saves</h1>
    <div class="empty">No <code>saves.json</code> yet — run <code>tools\\scan-saves.ps1</code>.
    ${s?.error ? esc(s.error) : ''}</div>`;

  const sum = s.summary || {};
  const slots = (s.slots || []);
  const exposed = slots.filter(x => x.isSlot && !x.backedUp);
  const guard = exposed.length === 0
    ? chip('ok', 'every slot is backed up')
    : chip('bad', `${exposed.length} slot${exposed.length > 1 ? 's' : ''} not in the latest backup`);

  const slotRows = slots.slice().sort((a, b) => (a.modified < b.modified ? 1 : -1)).map(x => [
    esc(x.label),
    `<span class="mono">${esc(x.file)}</span>`,
    `<span class="mono">${kb(x.bytes)}</span>`,
    `<span class="mono">${esc(String(x.modified).replace('T', ' '))}</span>`,
    `<span class="mono">${ago(x.modified)}</span>`,
    x.backedUp ? chip('ok', 'in backup') : chip('bad', 'exposed'),
  ]);

  const backupRows = (s.backups || []).map(b => [
    `<span class="mono">${esc(b.name)}</span>`,
    `<span class="mono">${esc(String(b.taken).replace('T', ' '))}</span>`,
    `<span class="mono">${b.files}</span>`,
    `<span class="mono">${kb(b.bytes)}</span>`,
    `<span class="mono">${ago(b.taken)}</span>`,
  ]);

  return `<h1>Saves</h1>
  <p class="lede">Read straight off the Steam cloud folder for app ${esc(s.steamAppId)}. The scanner never
  writes into the save folder; the only thing it creates is a timestamped copy in the vault.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(String(sum.slotCount ?? '—'), 'save slots', `${sum.fileCount ?? '—'} files total`)}
    ${tile(String(sum.backupCount ?? 0), 'backups held', sum.lastBackup ? `newest ${ago(sum.lastBackup)}` : 'none yet')}
    ${tile(kb(sum.totalBytes || 0), 'save data', 'across all files')}
    ${tile(String(sum.unprotectedSlots ?? 0), 'slots exposed', 'not in the latest backup')}
  </div>
  <p style="margin:16px 0 0">${guard}</p>
  <h2>Slots</h2>
  ${table(['Slot', 'File', 'Size', 'Modified', 'Age', 'Backup'], slotRows)}
  <h2>Backup vault</h2>
  <p class="lede"><code>${esc(s.vaultDir)}</code> — newest first, oldest pruned past 40.</p>
  ${backupRows.length ? table(['Backup', 'Taken', 'Files', 'Size', 'Age'], backupRows)
    : `<div class="empty">No backups yet. Run the scanner with <code>-Backup</code>.</div>`}
  <h2>Why this tab exists</h2>
  <div class="note">On 2026-09-20 a new game overwrote <code>data004Slot.bin</code> at 12:38, and only a
  copy taken eleven minutes earlier preserved that morning's work. That was luck wearing the costume of
  discipline. Every slot here carries whether it is actually inside the newest backup, so the answer is a
  status rather than a memory — and <code>data001Slot.bin</code> being 5.4&nbsp;MB against everything
  else's 320&nbsp;KB is the old completed playthrough, worth never losing.</div>
  <h2>Running it</h2>
  <p class="lede">Scan only, writes nothing but the report:</p>
  <p><code>powershell -ExecutionPolicy Bypass -File tools\\scan-saves.ps1</code></p>
  <p class="lede">Take a backup first, then scan — do this before any destructive phase:</p>
  <p><code>powershell -ExecutionPolicy Bypass -File tools\\scan-saves.ps1 -Backup</code></p>`;
});

add('mods', 'Mods', async () => {
  const f = await forge();
  const all = f.suite?.scripts || [];
  const lua = all.filter(s => /\.lua$/i.test(s.name) || s.state !== 'backup');
  const state = (s) => s.state === 'active' ? chip('ok', 'active')
    : s.state === 'disabled' ? chip('warn', 'disabled')
    : s.state === 'superseded' ? chip('bad', 'superseded')
    : s.state === 'done' ? chip('', 'done') : chip('', 'backup');
  const ours = lua.filter(s => s.ours);
  const theirs = lua.filter(s => !s.ours && s.state !== 'backup');
  const row = (s) => [esc(s.name), state(s), `<span class="mono">${num(s.bytes)}</span>`,
    `<span class="mono">${esc((s.modified || '').replace('T', ' '))}</span>`];
  return `<h1>Mods</h1>
  <p class="lede">The suite plus everything else in <code>reframework/autorun</code>. Third-party scripts we
  replaced are retired to <code>.superseded</code> rather than deleted, so a rollback is a rename.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(String(ours.filter(s => s.state === 'active').length), 'ours, armed', 'dd2forge_*')}
    ${tile(String(theirs.filter(s => s.state === 'active').length), 'third-party', 'active')}
    ${tile(String(lua.filter(s => s.state === 'disabled').length), 'disabled', 'kept for reference')}
    ${tile(String(lua.filter(s => s.state === 'superseded').length), 'superseded', 'replaced by ours')}
  </div>
  <h2>Ours</h2>${table(['Script', 'State', 'Bytes', 'Modified'], ours.map(row))}
  <h2>Third-party</h2>${table(['Script', 'State', 'Bytes', 'Modified'], theirs.map(row))}
  <h2>Techniques taken, with credit</h2>
  ${table(['Ours', 'From', 'What we changed'], [
    ['<code>dd2forge_pawnquiet</code>',
     'Stop Selling Yourself — r457 &amp; gh057 (Nexus 197)',
     'Runtime toggle, a blocked counter, and a guarded type lookup so a renamed AI task logs instead of throwing into a shared Lua state.'],
    ['<code>dd2forge_pawnhush</code>',
     'Shut Up Pawns! — emoose (Nexus 248), nil-guards by Zharay',
     'Learn mode: every line a pawn says is recorded with a hit count and blocked with one click, so the list is built from your playthrough instead of a preset. Starts inert.'],
    ['<code>dd2forge_curves</code>',
     'BigBoobs — ComplexRobot',
     'Butt joint scaling grafted in; ContainsKey guards on six lookups that threw KeyNotFoundException.'],
  ])}
  <div class="note">Content Editor's quest editor caused infinite black screens in cutscenes on this machine.
  It is the one file kept quarantined. Its author disabled the offending hooks in v1.5.2.</div>`;
});

add('quests', 'Quests', async () => `<h1>Quests</h1>
  <p class="lede">Reserved for the quest mod. Nothing here is built yet, and this page says so rather than
  showing an empty shell that implies otherwise.</p>
  <h2>What goes here</h2>
  ${table(['Piece', 'State', 'Note'], [
    ['Quest table', chip('warn', 'not started'), 'Every quest with ID, stage, flags and prerequisites, dumped from the game rather than transcribed from a wiki.'],
    ['Flag inspector', chip('warn', 'not started'), 'Read a live save’s quest flags so a stuck quest names its own blocking condition.'],
    ['Stage setter', chip('warn', 'not started'), 'Advance or rewind a quest. The highest-risk piece in the whole forge — gated behind a backup.'],
    ['Safety rail', chip('bad', 'blocking'), 'Content Editor’s quest editor black-screened cutscenes on this machine. Anything we build here has to avoid those talk-event hooks or it inherits the same bug.'],
  ])}
  <div class="note">The lesson from that freeze is the design constraint: search the mod's own description,
  posts and bugs tabs before forming a hypothesis. Someone has usually already hit it.</div>`);

add('log', 'Log', async () => {
  const entries = [
    ['2026-09-22', 'Suite site', 'dd2-forge published; reads the panel’s own JSON.'],
    ['2026-09-22', 'Pawn hush', 'Chatter and high-five hooks rebuilt as ours, with learn mode.'],
    ['2026-09-22', 'Pawn quiet', 'Stray-pawn sales approach blocked; toggle and counter added.'],
    ['2026-09-22', 'Coverage closed', '838 reachable, 4 held back, 2 duplicate IDs, 0 orphans.'],
    ['2026-09-22', 'Sovran’s set found', 'TU3.2 armour the wiki audit missed; the ID dump caught it.'],
    ['2026-09-22', 'Rift crystals', 'Solved as items 94/95 — no counter poke needed.'],
    ['2026-09-22', 'Cloaks diagnosed', 'Cloaks sat at catalog positions 944–992, last before the crash item.'],
    ['2026-09-21', 'Hydra freeze', 'Root cause: Content Editor’s quest editor. 20 of 21 files restored.'],
    ['2026-09-21', 'Carry at Lv1', 'W5’s multiplier was base×25 where base was 0. Replaced with absolute SET.'],
    ['2026-09-20', 'Volume probe', 'Crash at Dragonsbaulk Draught ×99 (c0000005). Item permanently excluded.'],
  ];
  return `<h1>Log</h1>
  <p class="lede">What changed, and what it cost to learn.</p>
  ${table(['Date', 'Item', 'Note'], entries.map(e =>
    [`<span class="mono">${esc(e[0])}</span>`, esc(e[1]), `<span style="color:var(--ink2)">${esc(e[2])}</span>`]))}`;
});

// ---------------------------------------------------------------- shell
const view = document.getElementById('view');
const tabsEl = document.getElementById('tabs');

function wireItems() {
  const holder = document.getElementById('rows');
  if (!holder) return;
  const rows = JSON.parse(holder.textContent);
  const q = document.getElementById('q'), grp = document.getElementById('grp'),
        cls = document.getElementById('cls'), tbl = document.getElementById('tbl'),
        cnt = document.getElementById('cnt');
  const draw = () => {
    const t = (q.value || '').trim().toLowerCase();
    const out = rows.filter(r =>
      (!grp.value || r.group === grp.value) && (!cls.value || r.cls === cls.value) &&
      (!t || r.name.toLowerCase().includes(t) || String(r.id).includes(t)));
    cnt.textContent = `${num(out.length)} of ${num(rows.length)}`;
    tbl.innerHTML = table(['Item', 'ID', 'Class', 'Group', 'Resolved by'],
      out.slice(0, 900).map(r => [esc(r.name), `<span class="mono">${r.id ?? '—'}</span>`,
        esc(r.cls), esc(r.group), `<span class="mono">${r.via}</span>`]));
  };
  [q, grp, cls].forEach(el => el.addEventListener('input', draw));
  draw();
}

async function show(id) {
  const t = TABS.find(x => x.id === id) || TABS[0];
  [...tabsEl.children].forEach(b => b.setAttribute('aria-selected', String(b.dataset.id === t.id)));
  view.innerHTML = `<div class="loading">Loading…</div>`;
  try { view.innerHTML = await t.render(); } catch (e) {
    view.innerHTML = `<h1>${esc(t.label)}</h1><div class="empty">Could not render: ${esc(e.message)}</div>`;
  }
  if (t.id === 'items') wireItems();
  if (location.hash.slice(1) !== t.id) history.replaceState(null, '', '#' + t.id);
  window.scrollTo({ top: 0 });
}

TABS.forEach(t => {
  const b = $(`<button class="tab" data-id="${t.id}">${t.label}</button>`);
  b.addEventListener('click', () => show(t.id));
  tabsEl.appendChild(b);
});

const themeBtn = document.getElementById('themeToggle');
themeBtn.addEventListener('click', () => {
  const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  try { localStorage.setItem('dd2forge.theme', next); } catch {}
});
try { const s = localStorage.getItem('dd2forge.theme'); if (s) document.documentElement.dataset.theme = s; } catch {}

window.addEventListener('hashchange', () => show(location.hash.slice(1)));
load('suite.json').then(s => {
  if (s?.generated) document.getElementById('footmeta').textContent =
    `build ${s.build} · data captured ${String(s.generated).replace('T', ' ').slice(0, 16)}`;
});
show(location.hash.slice(1) || 'overview');
