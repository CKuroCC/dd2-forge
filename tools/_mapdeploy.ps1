$ErrorActionPreference = 'Continue'

# field notes first
$p = 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md'
$t = @'

### §12a — RESOLVED: the map reveal works, and the missing layer was the landmark flags (2026-09-26 17:59)

[source: armed run confirmed on screen by Julian, 2026-09-26, sensitivity: internal]

**§12 is closed. The map is fully revealed** -- terrain, roads, settlements and landmark icons all
drawn, only the permanently fogged patch remaining. Screenshot confirmed.

**DOCUMENTED FACT -- THE MAP NEEDS ALL THREE LAYERS, AND LAYER 3 WAS NEVER ONCE SWITCHED ON.**
  1. `GuiManager:setOpenArea` / `setOpenLocalArea` -- REACHABLE, not explored. Read 1429/1429
     already open while the map rendered dark. Alone it does nothing visible. Different store
     (`GameSaveData.OpenAreaBits`).
  2. `MapMaskInfo:setForceMaskOff(System.UInt32[])` -- the fog. `MapMaskField` plus 121 live
     region masks scattered across 1098 slots of `MapMaskLocalArea` (indexed by
     `app.AILocalAreaDefinition`, NOT packed 0..120). FogRemover.lua fills the same fog layer a
     different way. This is what removes the clouds.
  3. `GuiManager:get_MapReleaseFlag():setFlag(0..65, true)` -- 66 entries of `app.MapReleaseEnum`.
     **THIS WAS THE MISSING PIECE.** Layers 1 and 2 had both been run before, repeatedly, and the
     report was always "clouds gone but the map is not revealed". Layer 3 draws the landmarks and
     its switch (`DO_FLAGS`) had sat at `false` since the torch was written on 2026-09-22.

**THE LESSON, and it is the same one as the DCP script.** The answer had been sitting finished on
disk in `_retired` for four days. The torch was complete, correct and never fired; its one
opt-in switch was the whole answer. Before writing anything new, read what the project already
built and check which of its switches were never turned on.

**MERGED 2026-09-26 into one tab.** `dd2forge_7map.lua` (MAP1-2026-09-26) now owns all three
layers behind one arm gate, dry run by default. `dd2forge_3ng2_wealth.lua` is gold only (W2) --
the map half never belonged there and made the gold script look broken for an unrelated reason.
`dd2forge_maptorch.lua` and the standalone `dd2forge_7map_torch.lua` are retired. The fabricated
"pctSetAfter" reading is GONE rather than fixed: `setForceMaskOff` does not write `MaskBit`, so
there is no honest readback, and the panel now says so on screen instead of printing a number.

**TOOLING WIN -- Lua syntax checking is available and was not being used.**
`luac -p <file>` in the cloud container validates a script without launching the game. Stage the
file with device_stage_files, then `luac -p`. Both merged files passed before they ever loaded.
Every "reload scripts and see if it errors" round trip this project has spent was avoidable.
'@
Add-Content -Path $p -Value $t -Encoding UTF8
Write-Output ("field notes: appended {0} chars" -f $t.Length)

Write-Output ''
Write-Output '=== deploy ==='
& 'D:\dd2-forge\tools\deploy.ps1' -Message 'map: merge torch + open-areas + landmark flags into one [MAP] tab; wealth is gold only' 2>&1 | Out-String | Write-Output
Write-Output ("deploy exit: {0}" -f $LASTEXITCODE)
Remove-Item 'D:\dd2-forge\tools\_mapdeploy.ps1' -Force
