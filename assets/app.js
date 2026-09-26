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
  // The probe records fields as "Name = value" strings, so DCP is parsed out of
  // the line rather than stored separately -- one source, no drift.
  const dcpOf = (key) => {
    const line = (dcp?.[key]?.fields || []).find(s => s.startsWith('ConsumableExp'));
    const n = line && Number(line.split('=')[1]);
    return Number.isFinite(n) ? n : null;
  };
  const dcpNow = { arisen: dcpOf('ARISEN.JobContext'), pawn: dcpOf('PAWN.JobContext') };
  return `<h1>Characters</h1>
  <p class="lede">The Arisen and the main pawn are written separately. Ranks, core skills, weapon skills at
  level 2 and augments go to both — ten vocations for the Arisen, six for the pawn, which is correct since
  pawns cannot take the advanced vocations.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(String(arisen || '—'), 'Arisen writes', 'ranks · skills · augments')}
    ${tile(String(pawn || '—'), 'Pawn writes', '6 eligible vocations')}
    ${tile(String((p21?.written || []).length || '—'), 'gear upgraded', 'enhanceEquip records')}
    ${tile(dcpNow.arisen ?? (dcp ? 'found' : '—'), 'Arisen DCP', dcpNow.pawn != null ? `pawn ${dcpNow.pawn}` : 'ConsumableExp')}
  </div>
  <h2>DCP — solved</h2>
  <p class="lede">Ranks are set with <code>setJobExpWithJobRank</code> and skills are enabled directly, which
  sidesteps the currency entirely: everything ends up bought and the DCP balance is never touched. Phase 29
  read the live type definition and named the handle. It is not "JobPoint" — that was a guess off an
  unrelated typecache field. It is <code>app.JobContext.ConsumableExp</code>, with a public property setter
  <code>set_ConsumableExpProp(System.Int32)</code>. "Consumable exp" is exactly right: the spendable pool,
  as against <code>CulmativeExp</code> (an array, per vocation, spelled the way the engine spells it).</p>
  ${dcp ? Object.entries(dcp).map(([k, v]) => `
    <h2 style="font-size:15px">${esc(k)} <span class="mono" style="font-weight:400">${esc(v.type)}</span></h2>
    <div class="grid g2">
      <div class="card"><div class="l" style="color:var(--ink3);font-size:11.5px;text-transform:uppercase;letter-spacing:.06em">Fields</div>
        <div class="mono" style="margin-top:8px;line-height:1.7">${(v.fields || []).map(esc).join('<br>') || '—'}</div></div>
      <div class="card"><div class="l" style="color:var(--ink3);font-size:11.5px;text-transform:uppercase;letter-spacing:.06em">Methods (${(v.methods || []).length})</div>
        <div class="mono" style="margin-top:8px;line-height:1.7;max-height:320px;overflow:auto">${(v.methods || []).map(esc).join('<br>') || '—'}</div></div>
    </div>`).join('')
   : `<div class="empty">No <code>dcp_probe.json</code> yet — press the Phase 29 button in game, then re-push.</div>`}
  <div class="note">Three guesses produced <code>ExpDispenser</code> (not a managed singleton), "JobPoint"
  (a field on an unrelated type) and <code>ch:call("get_JobContext")</code> (contexts hang off Human, not
  the character). One read produced the answer. Managed singletons are absent from
  <code>typecache.json</code>, which is exactly why the live type definition is the only authority here.</div>
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

// Per-script documentation. Three fields on purpose: what it does, the ONE
// load-bearing decision that makes it correct (usually bought with a bug), and
// what is still wrong with it. A docs block with no "still wrong" column is a
// brochure.
const MODDOCS = [
  { f: 'dd2forge_2do_grant.lua', t: 'Grant items, paced',
    d: 'Every item by class, type or category, plus the curated war chest, through one paced queue.',
    w: 'It calls the <code>getItem(Int32, Int32, CharacterID, Boolean, Boolean, Boolean, GetItemEventType)</code> overload that Content Editor’s <code>item_tools.lua</code> calls, with its arguments in its order. The earlier code used the <code>GetItemOption</code> struct overload and set three of that struct’s members; every field left alone held whatever was in that memory, which fed the decay list’s sort. Nine runs died after 6, 6, 3, 4, 1, 7, 9, 4 and 1 grants with no pattern in the items. Copying a working mod ended it.',
    i: '"Granted" still only means the call did not throw. There is no read-back proving the item exists.' },

  { f: 'dd2forge_1on_refill.lua', t: 'Periodic top-up',
    d: 'Gold, rift crystal hunks, curatives, herbs and Harspud on a timer. Always starts OFF.',
    w: 'The gold ceiling is read from the engine’s own <code>app.ItemManager.MaxMoneyCount</code> rather than a number someone picked, clamped to Int32 with a fallback. At the cap the game clamps silently, so the panel says so instead of leaving you wondering.',
    i: 'Curatives, herbs and Harspud are still capped at 99 — that is the real stack limit, so raising it would only produce a number the game trims.' },

  { f: 'dd2forge_5item_browser.lua', t: 'Item browser',
    d: 'Every item in the game, searchable, with favourites and a cart that batches one paced run.',
    w: 'The filter materialises once behind a dirty flag and the search box debounces at 0.25s — both lifted from how CyberEngineTweaks does it, because per-frame filtering of a thousand rows in Lua costs more than the game does. Rows are virtualised by hand: REFramework does not bind <code>ImGuiListClipper</code>, so the visible slice is computed from <code>get_scroll_y</code> and the rest of the height is claimed with <code>item_size</code>.',
    i: 'No sortable columns, and the category list is flat rather than a tree. Unresolvable rows are kept and bucketed rather than dropped, which is right, but they crowd the list when the filter is off.' },

  { f: 'dd2forge_6see_nameplates.lua', t: 'Nameplates',
    d: 'Names over nearby NPCs, so you know who you are walking up to before you talk to them.',
    w: 'v2 takes its engine layer from xyzkljl1’s Name On Head after that mod turned out to already exist. <code>app.CharacterListHolder:getAllCharacters()</code> returns the spawned characters — already the right list, where v1 walked hundreds of mostly-unloaded NPC holders. The name comes from <code>NPCManager:getNPCData(cid):get_Name()</code>, the game’s own localised string, and the plate sits on the <code>Head_0</code> joint instead of a flat 1.75m guess.',
    i: 'No occlusion test — names show through walls, deliberately, with the radius as the dial. No hotkey toggle yet; Name On Head has one. The custom-font loader is untested on this install.' },

  { f: 'dd2forge_4read_questguide.lua', t: 'Quest guide',
    d: '84 quests with walkthrough steps, missable warnings, map pins and an audit tab. Reads only.',
    w: 'It never writes quest state, and that is a design decision rather than an unfinished feature — see the Quests tab for the six stores and the uncomputable HashValue. <code>task:getActiveDestinations()</code> is engine-condition-filtered, so it returns what you are meant to do now rather than everything. <code>app.AIAreaManager:getKeyLocationNode(id)</code> answers for unspawned locations, verified 145/145.',
    i: '’Ware the Corrupted Beasts has no pin source and is not among the 81 player-facing quests the research could corroborate.' },

  { f: 'dd2forge_1on_curves.lua', t: 'Body and chain',
    d: 'Body slider work, including the chain-physics fix.',
    w: '<code>via.motion.Chain.EnabledDynamicScaling</code> and <code>EnabledStrictScale</code> must both be true or the solver never re-derives node lengths and collider radii from a changed bone scale, which is why scaled physics hung as though gravity had been switched off. Six other theories — restart-every-frame, gravity zeroed, frozen, blended, frame-skipped — were each killed by a probe before this one held.',
    i: 'The fix is applied on chain restart; a chain that never restarts keeps stale node lengths until something makes it.' },

  { f: 'dd2forge_1on_warfarer.lua', t: 'Warfarer preset swap',
    d: 'Swap a full skill loadout on the Warfarer without the menu dance.',
    w: 'Six skill slots, not four. The first version asserted four from memory of <code>SkillSlot.No0..No3</code>; MadoCat’s TrueWarfarerSkillSwapper uses <code>NUM_SLOTS = 6</code> and <code>setSkill(job, id, i-1)</code>, and the game agrees. The correction is left visible in the file header rather than quietly patched out.',
    i: 'Presets are per-session; they are not written anywhere you can carry between saves.' },

  { f: 'tools/refstub.lua', t: 'The load-test harness',
    d: 'Not a mod. Runs a script against stub engine APIs and drives every callback, so a chunk that parses but does not run is caught before it ships.',
    w: 'Its imgui allowlist is the 143 names read from REFramework’s own binding source at our exact build commit, so calling something that does not exist is an error rather than a silently disabled feature. It fakes geometry, a character world, multiple frames and cross-script globals, because every one of those gaps once let a broken build report PASS.',
    i: 'It cannot simulate the game. It proves control flow runs, never that a grant landed or a plate is in the right place.' },
];

add('mods', 'Mods', async () => {
  const f = await forge();
  const all = f.suite?.scripts || [];
  const lua = all.filter(s => /\.lua$/i.test(s.name) || s.state !== 'backup');
  const state = (s) => s.state === 'active' ? chip('ok', 'active')
    : s.state === 'disabled' ? chip('warn', 'disabled')
    : s.state === 'superseded' ? chip('bad', 'superseded')
    : s.state === 'done' ? chip('', 'done') : chip('', 'backup');
  const ours   = lua.filter(s => s.ours && s.state === 'active');
  const theirs = lua.filter(s => !s.ours && s.state === 'active');
  const shelved = lua.filter(s => s.state === 'backup' || s.state === 'disabled');
  const row = (s) => [esc(s.name), state(s), `<span class="mono">${num(s.bytes)}</span>`,
    `<span class="mono">${esc((s.modified || '').replace('T', ' '))}</span>`];

  const docs = MODDOCS.map(m => `
    <div class="card" style="margin:14px 0;padding:16px">
      <h3 style="margin:0 0 4px"><code>${esc(m.f)}</code> — ${esc(m.t)}</h3>
      <p style="margin:0 0 10px;color:var(--ink2)">${m.d}</p>
      <p style="margin:0 0 8px"><strong>Why it is built this way.</strong> ${m.w}</p>
      <p style="margin:0;color:var(--ink2)"><strong>Still wrong with it.</strong> ${m.i}</p>
    </div>`).join('');

  return `<h1>Mods</h1>
  <p class="lede">The suite plus everything else in <code>reframework/autorun</code>, read from the live
  folder by <code>tools/refresh-site-data.ps1</code>. Third-party scripts we replaced are retired to
  <code>.superseded</code> rather than deleted, so a rollback is a rename.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(String(ours.length), 'ours, armed', 'dd2forge_*')}
    ${tile(String(theirs.length), 'third-party', 'active')}
    ${tile(String(shelved.length), 'shelved', 'retired, backed up or disabled')}
    ${tile(String(MODDOCS.length), 'documented', 'below, with their faults')}
  </div>

  <h2>How each one works, and what is still wrong with it</h2>
  <p class="lede">Every entry names the one decision that makes the script correct. Most of them were
  bought with a bug.</p>
  ${docs}

  <h2>Ours, armed</h2>${table(['Script', 'State', 'Bytes', 'Modified'], ours.map(row))}
  <h2>Third-party, active</h2>${table(['Script', 'State', 'Bytes', 'Modified'], theirs.map(row))}

  <h2>Techniques taken, with credit</h2>
  ${table(['Ours', 'From', 'What we changed'], [
    ['<code>dd2forge_2do_grant</code>',
     'Content Editor — kagenocookie (<a href="https://www.nexusmods.com/dragonsdogma2/mods/1031">Nexus 1031</a>)',
     'The getItem overload and its argument order, copied unimproved from <code>item_tools.lua</code> after nine crashes.'],
    ['<code>dd2forge_6see_nameplates</code>',
     'Name On Head — xyzkljl1 (<a href="https://www.nexusmods.com/dragonsdogma2/mods/138">Nexus 138</a>)',
     'CharacterListHolder enumeration, getNPCData naming, the Head_0 joint and world_text. We added radius culling, a nearest-first plate cap, persisted settings and a diagnostics readout.'],
    ['<code>dd2forge_1on_warfarer</code>',
     'TrueWarfarerSkillSwapper — MadoCat (<a href="https://www.nexusmods.com/dragonsdogma2/mods/1532">Nexus 1532</a>)',
     'Six skill slots and the setSkill signature, which corrected a four-slot claim we had asserted from memory.'],
    ['<code>dd2forge_5item_browser</code>',
     'CyberEngineTweaks, AppearanceMenuMod, Modex (other games)',
     'Tree-when-empty / flat-when-searching, the 0.25s search debounce, a materialised filter, and a confirmation above 400 paced grants.'],
    ['<code>dd2forge_1on_pawnquiet</code>',
     'Stop Selling Yourself — r457 &amp; gh057 (<a href="https://www.nexusmods.com/dragonsdogma2/mods/197">Nexus 197</a>)',
     'Runtime toggle, a blocked counter, and a guarded type lookup so a renamed AI task logs instead of throwing into a shared Lua state.'],
    ['<code>dd2forge_1on_pawnhush</code>',
     'Shut Up Pawns! — emoose (<a href="https://www.nexusmods.com/dragonsdogma2/mods/248">Nexus 248</a>)',
     'Learn mode: every line a pawn says is recorded with a hit count and blocked with one click. Starts inert. Note the original is abandoned and broken on TU3.2.'],
    ['<code>dd2forge_1on_curves</code>',
     'BigBoobs — ComplexRobot',
     'Butt joint scaling grafted in; ContainsKey guards on six lookups that threw KeyNotFoundException; the chain scale-flag fix is ours.'],
  ])}

  <div class="note"><strong>The one still quarantined.</strong> Content Editor's quest editor caused
  infinite black screens in cutscenes on this machine. Its author disabled the offending hooks in v1.5.2.
  The rest of Content Editor is not merely tolerated but relied on — it is where the working getItem call,
  the NPC enum resolution and the <code>draw.world_text</code> pattern were all read from.</div>

  <div class="note"><strong>Loose files only load because REFramework makes them.</strong> Capcom disabled
  loose-file loading in DD2 — the first game they did it in — so <code>natives/STM/</code> is inert on its
  own and REFramework's LooseFileLoader is mandatory, not optional. It is on here, and
  <code>reframework_loose_files.txt</code> confirms the files load with zero faults after TU3.2.</div>`;
});

add('quests', 'Quests', async () => {
  const qs = (await load('quests.json')) || [];
  if (!qs.length) return `<h1>Quests</h1><div class="empty">quests.json did not load.</div>`;
  const miss = qs.filter(q => q.missable && q.missable.is_missable);
  const conf = c => qs.filter(q => q.confidence === c).length;
  return `<h1>Quests</h1>
  <p class="lede">A companion, not a cheat. Every entry says how to start the quest, what closes the
  window, how to reach the best outcome and what the bad one costs. <strong>Nothing here writes quest
  state</strong> — the note at the foot of this page says why that is deliberate rather than unfinished.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(String(qs.length), 'quests researched', 'main and side')}
    ${tile(String(miss.length), 'missable', 'windows that close for good')}
    ${tile(String(conf('high')), 'high confidence', 'two independent sources agreed')}
    ${tile('TU3.2', 'version stamp', 'Dark Arisen lands 9 Oct 2026')}
  </div>
  <h2>Browse</h2>
  <div class="controls">
    <input id="qq" type="search" placeholder="Search quests, NPCs, items, warnings…" style="flex:1 1 240px">
    <select id="qtype"><option value="">All types</option><option value="main">Main</option><option value="side">Side</option></select>
    <select id="qmiss"><option value="">All quests</option><option value="1">Missable only</option></select>
    <span class="count" id="qcnt"></span>
  </div>
  <div id="qlist"></div>
  <script type="application/json" id="qrows">${JSON.stringify(qs).replace(/</g, '\\u003c')}</script>
  <div class="note"><strong>Why there is no stage setter here, and won't be.</strong> Quest state lives in
  six independent stores — the quest context's processor results, the journal, talk-event records, the
  deliver manager, the clear-record dict and the disable dict. Setting one without the rest leaves a save
  that is engine-complete but journal-<span class="mono">Progressing</span> for ever. Both save blobs also
  carry a <span class="mono">HashValue</span> nothing public knows how to recompute, and writing a
  processor phase to <span class="mono">Setup</span> hard-crashes the game. Reading is free; writing is a
  save-corruption machine, so this tab reads.</div>`;
});

// ---------------------------------------------------------------- builds
// Read-only guide. Replaces watching the Vocation Guild's preview videos (which
// lag badly): every loadout is a six-slot set for TrueWarfarerSkillSwapper
// (Nexus #1532), slot 1 always Rearmament, ids from the mod's own
// WeaponValidSkillMap so nothing here is un-settable.
const CONF_CHIP = { sourced: 'ok', inference: 'warn', conflict: 'bad', untested: 'warn' };
const WARF_CHIP = { yes: ['ok', 'works on Warfarer'], no: ['bad', 'not on Warfarer'],
  conflict: ['warn', 'sources disagree'], untested: ['warn', 'untested'] };

add('builds', 'Builds', async () => {
  const b = await load('builds.json');
  if (!b || !b.vocations) return `<h1>Builds</h1><div class="empty">builds.json did not load.</div>`;
  const w = b.warfarer || {};
  const nBuilds = b.vocations.reduce((n, v) => n + (v.builds || []).length, 0);
  const nCore = b.vocations.reduce((n, v) => n + (v.core_skills || []).length, 0);
  const rules = (w.rules || []).map(r => [esc(r.topic),
    `${esc(r.text)}${(r.sources || []).length ? ` <span class="mono">[${r.sources.length} src]</span>` : ''}`,
    chip(CONF_CHIP[r.confidence] || 'warn', r.confidence || '?')]);
  const tests = (w.open_questions || []).map(q => [esc(q.question), `<span style="color:var(--ink2)">${esc(q.how_to_test)}</span>`]);
  return `<h1>Builds</h1>
  <p class="lede">Three six-slot loadouts per vocation, <strong>defensive, offensive and utility</strong>, written
  for one Warfarer carrying every weapon and swapping sets with True Warfarer &amp; Skill Swapper. Every slot uses
  the mod's own list of settable skills, so each set can be copied straight into its config. Core skills for each
  vocation are underneath, with inputs and when to use them, so the Guild's preview videos never need opening.</p>
  <div class="grid g4" style="margin-top:20px">
    ${tile(String(b.vocations.length), 'weapon vocations', 'Warfarer runs all nine')}
    ${tile(String(nBuilds), 'loadouts', 'slot 1 is always Rearmament')}
    ${tile(String(nCore), 'core skills', 'how and when, per vocation')}
    ${tile(esc(b.game_version || 'TU3.2'), 'researched against', esc(b.generated || ''))}
  </div>
  <div class="note"><strong>Read the verdicts, not just the lists.</strong> No source has published a six-slot Warfarer
  build for TU3.2, so every loadout is assembled from sourced skill facts and marked <em>inference</em>. Two things
  are genuinely unsettled and flagged wherever they matter: whether a Warfarer gets the held weapon's
  <em>core</em> skills, and whether Maister skills forced in by the mod actually fire. The tests to settle both are
  at the bottom of this page.</div>

  <h2>Vocation</h2>
  <div class="controls" id="bvoc">${b.vocations.map((v, i) =>
    `<button class="ghost bvbtn" data-i="${i}">${esc(v.name)}</button>`).join('')}</div>
  <div id="bview"></div>

  <h2>Warfarer rules</h2>
  <p class="lede">${esc(w.summary || '')}</p>
  ${table(['Topic', 'What holds', 'Evidence'], rules)}
  <h2>Augments that suit every set</h2>
  <p class="lede">Augments are picked at a Vocation Guild, not per weapon, so one Warfarer runs one set of six across
  every swap. These hold up whichever weapon is out.</p>
  ${table(['Augment', 'Why'], (w.universal_augments || []).map(a => [esc(a.name), `<span style="color:var(--ink2)">${esc(a.why)}</span>`]))}
  <h2>Settle these in game</h2>
  ${table(['Open question', 'How to test'], tests)}
  <h2>The preview-video lag</h2>
  <div class="note">${esc(w.menu_lag || '')}</div>
  <script type="application/json" id="brows">${JSON.stringify(b.vocations).replace(/</g, '\\u003c')}</script>`;
});

function wireBuilds() {
  const holder = document.getElementById('brows');
  if (!holder) return;
  let voc = [];
  try { voc = JSON.parse(holder.textContent); } catch { return; }
  const out = document.getElementById('bview');
  const btns = [...document.querySelectorAll('.bvbtn')];
  const ROLE = { defensive: 'ok', offensive: 'bad', utility: 'warn' };

  const card = (v, bd) => {
    const ids = (bd.slots || []).map(s => s.id);
    const slots = (bd.slots || []).map((s, i) =>
      `<li><span class="mono">${i + 1} · ${s.id}</span> <strong>${esc(s.name)}</strong>
       <span style="color:var(--ink2)"> — ${esc(s.why)}</span></li>`).join('');
    const alt = bd.alternate ? `<p><span class="mono">swap-in · ${bd.alternate.id}</span>
      <strong>${esc(bd.alternate.name)}</strong> <span style="color:var(--ink2)">— ${esc(bd.alternate.why)}</span></p>` : '';
    const aug = (bd.augments || []).map(a => `<span class="chip" title="${esc(a.why)}">${esc(a.name)}</span>`).join(' ');
    const flags = (bd.flags || []).map(f => `<li>${esc(f)}</li>`).join('');
    return `<div class="card bcard">
      <div class="bhead">${chip(ROLE[bd.role] || 'warn', bd.role)} <span class="qn">${esc(bd.name)}</span>
        ${chip(CONF_CHIP[bd.confidence] || 'warn', bd.confidence || '?')}</div>
      <ol class="bslots">${slots}</ol>${alt}
      <div class="bcfg"><span class="mono" title="TrueWarfarerSkillSwapper.json, SkillSets entry ${v.job} of 10 (${esc(v.name)})">set ${v.job} · [${ids.join(', ')}]</span>
        <button class="ghost bcopy" data-cfg="[${ids.join(', ')}]">copy</button></div>
      <h4>Augments</h4><p>${aug || '<span class="empty">none listed</span>'}</p>
      <h4>How to play it</h4><p>${esc(bd.rotation)}</p>
      <h4>Weak to</h4><p style="color:var(--ink2)">${esc(bd.weaknesses)}</p>
      ${flags ? `<h4>Check first</h4><ul class="bflags">${flags}</ul>` : ''}
    </div>`;
  };

  const draw = (i) => {
    const v = voc[i];
    if (!v) return;
    btns.forEach(b => b.setAttribute('aria-pressed', String(Number(b.dataset.i) === i)));
    const core = (v.core_skills || []).map(c => {
      const [cls, word] = WARF_CHIP[c.on_warfarer] || ['warn', c.on_warfarer || '?'];
      return [`<strong>${esc(c.name)}</strong><div class="mono">${esc(c.internal || '')}</div>`,
        esc(c.input), `<span style="color:var(--ink2)">${esc(c.when)}</span>`, chip(cls, word)];
    });
    const ns = (v.not_settable_via_mod || []).map(n => `<li><strong>${esc(n.name)}</strong> — ${esc(n.why_notable)}</li>`).join('');
    const src = (v.sources || []).map(u => `<li><a href="${esc(u)}" target="_blank" rel="noopener">${esc(u)}</a></li>`).join('');
    out.innerHTML = `<h2>${esc(v.name)} <span class="mono">· ${esc(v.weapons)}</span></h2>
      <p class="lede">${esc(v.summary)}</p>
      <div class="grid g3b">${(v.builds || []).map(bd => card(v, bd)).join('')}</div>
      <h3>Core skills</h3>
      <p class="lede">These fire when you are actually ${esc(v.name)}. Whether a Warfarer holding the weapon gets them is
      marked per skill.</p>
      ${table(['Core skill', 'Input', 'When to use it', 'On Warfarer'], core)}
      ${ns ? `<h3>Not settable through the mod</h3><ul>${ns}</ul>` : ''}
      ${src ? `<details class="qrow"><summary><span class="qn">Sources</span></summary><div class="qbody"><ul class="qsrc">${src}</ul></div></details>` : ''}`;
    out.querySelectorAll('.bcopy').forEach(bt => bt.addEventListener('click', async () => {
      try { await navigator.clipboard.writeText(bt.dataset.cfg); bt.textContent = 'copied'; }
      catch { bt.textContent = 'select + copy'; }
      setTimeout(() => { bt.textContent = 'copy'; }, 1400);
    }));
    try { localStorage.setItem('dd2forge.buildvoc', String(i)); } catch {}
  };
  btns.forEach(b => b.addEventListener('click', () => draw(Number(b.dataset.i))));
  let start = 0;
  try { start = Number(localStorage.getItem('dd2forge.buildvoc')) || 0; } catch {}
  draw(Math.min(Math.max(start, 0), voc.length - 1));
}

add('log', 'Log', async () => {
  const entries = [
    ['2026-09-26', 'Builds tab', '27 six-slot Warfarer loadouts (defensive / offensive / utility for all nine weapon vocations) plus every core skill with inputs, built so the Guild’s laggy preview videos never need opening. Slot ids come from TrueWarfarerSkillSwapper’s own settable list.'],
    ['2026-09-26', 'Core skills: not a bug', 'All 35 core skills read enabled and HumanSkillAvailability calls them available. They need the real vocation plus its weapon (shield skills need the off hand); on Warfarer they were never going to fire. The “master switch” theory was disproved by probe.'],
    ['2026-09-26', 'Autorun cleanup', '7 finished or unused scripts retired to _retired, obsolete buttons removed from grant, affinity and inventory, carry’s freeze-test button renamed to the reset it now is.'],
    ['2026-09-25', 'Nameplates v2', 'Rewritten on CharacterListHolder, getNPCData and the Head_0 joint after reading Name On Head — a mod that already did this and should have been read first.'],
    ['2026-09-25', 'Site refresh', 'suite.json was three days stale and still listing script names renamed away; rebuilt from the live folder by a script so it cannot drift again.'],
    ['2026-09-25', 'Loose files cleared', 'TU3.2 file-ID panic retracted: LooseFileLoader is on, 920 natives files log as loaded, faulty_files is empty.'],
    ['2026-09-25', 'Fluffy', 'Self-updated 3.027 → 3.084 on first launch. DD2 has been in its built-in list since launch day; the default.cfg it was judged by only lists legacy titles.'],
    ['2026-09-25', 'Pawn types found', 'il2cpp_dump.json and sdk_ida/ were already on disk. app.HumanPreventFallController carries IsPawn and two tunable floats — the cliff/Brine lead nobody else has.'],
    ['2026-09-24', 'Item browser', 'Every item searchable, favourites, and a cart that batches one paced run. Rows virtualised by hand; REFramework binds no list clipper.'],
    ['2026-09-24', 'Ceilings raised', 'Gold now reads app.ItemManager.MaxMoneyCount. Correction filed the same day: queue_add chunks counts into 99s, so a big count costs time, not stability.'],
    ['2026-09-24', 'Chain gravity', 'EnabledDynamicScaling and EnabledStrictScale. Six other theories died first.'],
    ['2026-09-23', 'Quest guide v2', 'Accordion layout, walkthroughs from a second source, map pins, audit tab. 145/145 key locations resolved.'],
    ['2026-09-23', 'Harness built', 'refstub.lua runs the chunk instead of parsing it. Has since caught a nil-geometry crash and a scan that never ran — both of which reported PASS beforehand.'],
    ['2026-09-22', 'Suite site', 'dd2-forge published; reads the panel’s own JSON.'],
    ['2026-09-22', 'Coverage closed', '838 reachable, 4 held back, 2 duplicate IDs, 0 orphans.'],
    ['2026-09-22', 'Sovran’s set found', 'TU3.2 armour the wiki audit missed; the ID dump caught it.'],
    ['2026-09-21', 'Hydra freeze', 'Root cause: Content Editor’s quest editor. 20 of 21 files restored.'],
    ['2026-09-20', 'Volume probe', 'Crash at Dragonsbaulk Draught ×99 (c0000005). Item permanently excluded.'],
  ];
  return `<h1>Log</h1>
  <p class="lede">What changed, and what it cost to learn. Corrections are listed as entries of their
  own rather than edited over the top of the mistake.</p>
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

function wireQuests() {
  const holder = document.getElementById('qrows');
  if (!holder) return;
  let rows = [];
  try { rows = JSON.parse(holder.textContent); } catch { return; }

  const q = document.getElementById('qq'), ty = document.getElementById('qtype'),
        mi = document.getElementById('qmiss'), listEl = document.getElementById('qlist'),
        cnt = document.getElementById('qcnt');

  const slug = s => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const has = v => {
    if (v == null) return false;
    if (Array.isArray(v)) return v.length > 0;
    const s = String(v).trim();
    return !!s && !/^(unknown|n\/a|none|null|unverified)$/i.test(s);
  };
  const li = a => a.map(x => `<li>${esc(x)}</li>`).join('');

  rows.forEach(r => {
    r._hay = [r.name, r.region, r.how_to_start, r.timing, r.prerequisites,
      (r.aka || []).join(' '), (r.bring || []).join(' '), (r.gotchas || []).join(' '),
      (r.along_the_way || []).join(' '), r.best_outcome && r.best_outcome.summary,
      r.best_outcome && (r.best_outcome.steps || []).join(' '),
      r.bad_outcome && r.bad_outcome.summary, r.missable && r.missable.warning]
      .filter(Boolean).join(' ').toLowerCase();
  });

  const body = r => {
    const bo = r.best_outcome || {}, bd = r.bad_outcome || {};
    let h = '';
    if (r.missable && r.missable.is_missable) {
      h += `<div class="qwarn"><strong>Missable.</strong> ${esc(r.missable.warning || '')}` +
challengeWindow(r) + `</div>`;
    }
    const kv = [];
    if (has(r.how_to_start)) kv.push(['Start', r.how_to_start]);
    if (has(r.timing)) kv.push(['Timing', r.timing]);
    if (has(r.prerequisites)) kv.push(['Needs first', r.prerequisites]);
    if (kv.length) h += `<dl class="qkv">` + kv.map(([k, v]) =>
      `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('') + `</dl>`;
    if (has(r.bring)) h += `<h4>Bring</h4><p>` +
      r.bring.map(x => `<span class="chip">${esc(x)}</span>`).join(' ') + `</p>`;
    h += `<div class="grid g2">`;
    let good = '';
    if (has(bo.summary)) good += `<p>${esc(bo.summary)}</p>`;
    if (has(bo.steps)) good += `<ol>${li(bo.steps)}</ol>`;
    if (has(bo.rewards)) good += `<h4>Rewards</h4><ul>${li(bo.rewards)}</ul>`;
    h += `<div class="card qgood"><h4>Best outcome</h4>${good || '<div class="empty">Not documented.</div>'}</div>`;
    let bad = '';
    if (has(bd.summary)) bad += `<p>${esc(bd.summary)}</p>`;
    if (has(bd.how_it_happens)) bad += `<p><strong>How:</strong> ${esc(bd.how_it_happens)}</p>`;
    if (has(bd.consequences)) bad += `<p><strong>Cost:</strong> ${esc(bd.consequences)}</p>`;
    h += `<div class="card qbad"><h4>Bad outcome</h4>${bad ||
      '<div class="empty">No failure state documented. That is a gap in the sources, not a guarantee.</div>'}</div>`;
    h += `</div>`;
    if (has(r.along_the_way)) h += `<h4>Along the way</h4><ul>${li(r.along_the_way)}</ul>`;
    if (has(r.gotchas)) h += `<h4>Gotchas</h4><ul>${li(r.gotchas)}</ul>`;
    if (has(r.sources)) h += `<h4>Sources</h4><ul class="qsrc">` + r.sources.map(u =>
      `<li><a href="${esc(u)}" target="_blank" rel="noopener">${esc(u)}</a></li>`).join('') + `</ul>`;
    return h;
  };
  function challengeWindow(r) {
    return has(r.missable && r.missable.window)
      ? `<div class="qwin">Window: ${esc(r.missable.window)}</div>` : '';
  }

  const draw = () => {
    const t = (q.value || '').trim().toLowerCase();
    const out = rows.filter(r =>
      (!ty.value || (ty.value === 'main' ? r.type === 'main' : r.type !== 'main')) &&
      (!mi.value || (r.missable && r.missable.is_missable)) &&
      (!t || r._hay.includes(t)));
    cnt.textContent = `${out.length} of ${rows.length}`;
    if (!out.length) { listEl.innerHTML = `<div class="empty">Nothing matches.</div>`; return; }
    listEl.innerHTML = out.map(r => {
      const m = r.missable && r.missable.is_missable;
      return `<details class="qrow${m ? ' ism' : ''}" id="q-${slug(r.name)}"><summary>
        <span class="qn">${esc(r.name)}</span>
        <span class="qmeta">${esc(r.type)}${has(r.region) ? ' · ' + esc(r.region) : ''}</span>
        ${m ? `<span class="chip bad"><span class="dot"></span>missable</span>` : ''}
        <span class="chip ${r.confidence === 'high' ? 'ok' : r.confidence === 'low' ? 'bad' : 'warn'}"><span class="dot"></span>${esc(r.confidence || '?')}</span>
      </summary><div class="qbody">${body(r)}</div></details>`;
    }).join('');
  };
  [q, ty, mi].forEach(el => el.addEventListener('input', draw));
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
  if (t.id === 'quests') wireQuests();
  if (t.id === 'builds') wireBuilds();
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
