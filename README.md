# dd2-forge

A REFramework workbench for **Dragon's Dogma 2** (build 3.2.0.0, Steam/PC), and the
site that shows what it has done.

The site is static — no build step, no framework, no dependencies. It reads the JSON
files the in-game panel writes to `reframework/data/dd2forge/`, which are committed
into `data/`. That means the pages reflect a real save rather than hand-written copy.

## Tabs

| Tab | What it shows |
|---|---|
| Overview | Catalog size, coverage, what is held back and why |
| Items | Catalog rows, filterable by group and class |
| Characters | Arisen vs pawn writes, and the DCP probe |
| Equipment | What the upgrade probe last read back |
| Saves | Slot state (scanner not yet wired) |
| Mods | Every script, how each one works, and what is still wrong with it |
| Quests | 84 researched quests, searchable, read-only by design |
| Log | What changed and what it cost to learn |

## Refreshing the data

`data/suite.json` drives the Mods tab and is generated from the **live** autorun
folder. Do not hand-edit it. On 25 Sep 2026 it was found three days stale, still
listing script names that had been renamed away, which is what the script prevents:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\dd2-forge\tools\refresh-site-data.ps1
git add -A && git commit -m "refresh forge data" && git push
```

It rebuilds `suite.json` and re-copies every JSON under 500 KB. The 6.7 MB
`deepdump.json` is deliberately excluded — it is a body-editor probe with no place
in a repo or on a CDN.

Vercel redeploys on push.

## The scripts

They live in `reframework/autorun/` on the game install, not in this repo. Names are
prefixed by when you reach for them: `1on` always-on, `2do` actions, `3ng` new-game
setup, `4read` read-only reference, `5item`/`6see` tools, `9probe` investigation.

| Script | Does |
|---|---|
| `dd2forge_1on_refill` | Gold, rift crystals, curatives, herbs, Harspud on a timer |
| `dd2forge_1on_curves` | Body sliders and the chain-physics scale fix |
| `dd2forge_1on_warfarer` | Warfarer six-slot preset swapping |
| `dd2forge_1on_pawnquiet` | Stray pawns stop walking over to sell themselves |
| `dd2forge_1on_pawnhush` | Party pawns stop narrating; high fives off |
| `dd2forge_1on_plague` / `_stacks` / `_uiunlocks` / `_pawnspec` | Dragonsplague, stack limits, UI unlocks, pawn specialisation |
| `dd2forge_2do_grant` | Items by class, type and category; the war chest; the paced queue |
| `dd2forge_2do_carry` | Carry weight and stamina, absolute, works at Lv1 |
| `dd2forge_2do_affinity` / `_inventory` / `_kit` / `_decayfix` | Affinity, inventory tools, kits, food decay |
| `dd2forge_3ng1_progress` … `3ng5_upgrade` | New-game setup: progress, wealth, DCP, affinity, gear upgrades |
| `dd2forge_4read_questguide` | 84 quests, walkthroughs, map pins, audit — reads only |
| `dd2forge_4read_vocations` | Vocation reference |
| `dd2forge_5item_browser` | Every item, searchable, favourites and a batching cart |
| `dd2forge_6see_nameplates` | Names over nearby NPCs |
| `dd2forge_9probe_chain` / `_questtext` | Investigation scripts, kept because they document a method |

## The harness

`tools/refstub.lua` runs a mod chunk against stub engine APIs and drives every
registered callback. `luac -p` proves a file parses; this proves it **runs**, which
is the only thing REFramework cares about.

```powershell
$env:REF_DATA="D:\dd2-forge\data"; lua tools\refstub.lua <script.lua>
tools\itembrowser_tests.sh     # 22 checks
tools\nameplate_tests.sh       # 16 checks
```

Its imgui allowlist is the 143 names read from REFramework's own binding source at
our exact build commit, so calling a function that does not exist is an error rather
than a silently disabled feature. It has since caught a nil-geometry crash and a
scan that never ran — both of which reported PASS before the harness could see them.

## Credit

Techniques taken from other people's work, with thanks:

- **Content Editor** — kagenocookie, [Nexus 1031](https://www.nexusmods.com/dragonsdogma2/mods/1031) —
  the working `getItem` overload, NPC enum resolution, and the `draw.world_text` pattern
- **Name On Head** — xyzkljl1, [Nexus 138](https://www.nexusmods.com/dragonsdogma2/mods/138) —
  `CharacterListHolder`, `getNPCData`, the `Head_0` joint
- **TrueWarfarerSkillSwapper** — MadoCat, [Nexus 1532](https://www.nexusmods.com/dragonsdogma2/mods/1532) —
  six skill slots, and the correction of a four-slot claim we had asserted from memory
- **Stop Selling Yourself** — r457 & gh057, [Nexus 197](https://www.nexusmods.com/dragonsdogma2/mods/197)
- **Shut Up Pawns!** — emoose, [Nexus 248](https://www.nexusmods.com/dragonsdogma2/mods/248),
  with nil-guard fixes by [Zharay](https://github.com/Zharay/DD2-LUAModFixes)
- **BigBoobs** — ComplexRobot
- **REFramework** — praydog

## Two authorities

For **gear**, the public databases are the authority and the catalog is audited
against them. For **everything else**, the game's own ID dump is the authority and
the databases are the thing being audited.

That rule was earned: a two-database audit of 491 gear names came back with zero
gaps and still missed the Sovran's Crown / Plate / Greaves set, because the
databases predate Title Update 3.2. The raw IDs caught it.

## Loose files

Capcom disabled loose-file loading in DD2 — the first game they did it in — so
`natives/STM/` is inert on its own and REFramework's **LooseFileLoader** is
mandatory, not optional. TU3.2 also reassigned internal file IDs; whether your files
survived that is answered by `reframework_loose_files.txt` and
`reframework_faulty_files.txt` in the game root, not by guessing.
