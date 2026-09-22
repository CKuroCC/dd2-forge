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
| Items | All 844 catalog rows, filterable by group and class |
| Characters | Arisen vs pawn writes, and the open DCP gap |
| Equipment | What the upgrade probe last read back |
| Saves | Slot state (scanner not yet wired) |
| Mods | The suite, third-party scripts, and techniques taken with credit |
| Quests | Reserved for the quest mod — deliberately empty, not a shell |
| Log | What changed and what it cost to learn |

## Refreshing the data

```powershell
$src = "D:\SteamLibrary\steamapps\common\Dragons Dogma 2\reframework\data\dd2forge"
Get-ChildItem $src -File -Filter *.json |
  Where-Object { $_.Length -lt 500000 } |
  ForEach-Object { Copy-Item $_.FullName "data\$($_.Name)" -Force }
git add data && git commit -m "refresh forge data" && git push
```

Vercel redeploys on push.

## The scripts

Lives in `reframework/autorun/` on the game install, not in this repo.

| Script | Does |
|---|---|
| `dd2forge_apply` | Items by class and type, war chest, gear upgrades |
| `dd2forge_refill` | Gold, rift crystals, curatives, herbs, Harspud |
| `dd2forge_pawnquiet` | Stray pawns stop walking over to sell themselves |
| `dd2forge_pawnhush` | Party pawns stop narrating; high fives off |
| `dd2forge_carry` | Carry weight and stamina, absolute, works at Lv1 |
| `dd2forge_curves` | Body slider work |
| `dd2forge_phase21/24/26/28` | Gear +4, skills/augments/ranks, gold/map, affinity |
| `dd2forge_phase29` | DCP / JobPoint probe (read-only) |

## Credit

Techniques taken from other people's work, with thanks:

- **Stop Selling Yourself** — r457 & gh057, [Nexus 197](https://www.nexusmods.com/dragonsdogma2/mods/197)
- **Shut Up Pawns!** — emoose, [Nexus 248](https://www.nexusmods.com/dragonsdogma2/mods/248),
  with nil-guard fixes by [Zharay](https://github.com/Zharay/DD2-LUAModFixes)
- **BigBoobs** — ComplexRobot
- **REFramework** — praydog

## Two authorities

For **gear**, the public databases are the authority and the catalog is audited
against them. For **everything else**, the game's own ID dump is the authority and
the databases are the thing being audited — they list 267 non-equipment items
against the catalog's 345.

That rule was earned: a two-database audit of 491 gear names came back with zero
gaps and still missed the Sovran's Crown / Plate / Greaves set, because the
databases predate Title Update 3.2. The raw IDs caught it.
