$p = 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md'
$t = @'

### §17 — The curves fix was never wrong. It was never re-asserted. (2026-09-26)

[source: read of dd2forge_1on_curves.lua + one targeted research run, 2026-09-26, sensitivity: internal]

**DOCUMENTED FACT — the bug is four lines, and it is a one-shot flag.**
```
re.on_frame(function()
    if not update_transforms then return end   -- <-- returns on every frame
    update_transforms = false                  -- <-- one-shot, set by the UI only
```
`update_transforms` goes true when a slider moves, the loop runs ONCE, and every frame after that
returns on line one. So `set_EnabledDynamicScaling` / `set_EnabledStrictScale` only ever fired when
Julian touched the panel. The 2026-09-24 diagnosis and fix were both correct and were confirmed in
game; nothing was reverting them. Nothing was re-applying them.
Two sdk.hooks DID cover two rebuild events (`app.CharacterManager.onReadyCharacter` and
`app.CloneBuilder.onCompletedBuild`), so character load and mockup build re-applied properly --
which is exactly why this looked intermittent rather than broken.

**DOCUMENTED FACT — why the flags come back false: they are AUTHORED DATA, not runtime state.**
The `.chain` file format carries a `chainAttrFlags` uint bitfield in its 104/112-byte header,
alongside `parameterFlag`, `calculateMode` and `defaultSettingIdx`
[NSACloud/RE-Chain-Editor, modules/file_re_chain.py:76-128; re_chain_propertyGroups.py:639-649].
So nothing actively clears them -- the component is re-initialised from its asset and our runtime
edit was never in the asset. [INFERENCE] EnabledDynamicScaling / EnabledStrictScale are two of that
bitfield's unnamed UNKN2..UNKN6 bits.

**DOCUMENTED FACT — THERE IS NO REBUILD HOOK. EVERYONE POLLS.**
REFramework's Lua API has no character or chain lifecycle callback: the complete list is
on_script_reset, on_config_save, on_draw_ui, on_frame, on_pre_application_entry /
on_application_entry, on_pre_gui_draw_element / on_gui_draw_element
[cursey.github.io/reframework-book, src/api/re.md]. REFramework's own C++ ChainViewer walks the
entire transform tree every frame rather than hooking [src/mods/tools/ChainViewer.cpp:187-290].
EMV-Engine re-validates cached components every frame [init.lua:10650-10740]. Polling is the
correct design here, not a fallback.

**DOCUMENTED FACT — the cheap liveness test, and it costs no managed call.**
A `via.Component` holds its owning GameObject pointer at offset 0x10. Zero, or not a managed
object, means the component is dead [EMV-Engine init.lua:863-884, and the same read used as a
per-frame gate at 10777]. Use that instead of `get_GameObject()`, which EMV's author calls
"the #1 internal-exception causing method in the game" [init.lua:892].
Also: `add_ref()` keeps YOUR handle alive after the game drops the object, so a cached chain handle
never goes nil on its own -- it must be validated.

**DOCUMENTED FACT — do NOT restart() on every check.** `restart()` is a physics RESET, not a
refresh: EMV's wrapper for it is literally named `reset_physics` [init.lua:10218-10230]. It clears
node velocity and re-seeds from the current pose, so calling it on a 15-frame cadence would read as
a permanent twitch. EMV also defers it into the UpdateMotion phase rather than firing it from
arbitrary context.

**CADENCE: 15 frames**, which is the shipped DD2 precedent -- Zharay's HideHelmetsOutofCombat
re-asserts on exactly that counter [github.com/Zharay/DD2-LUAModFixes], and REFramework's
best-practices page says to stagger work across ticks. Cache method definitions once outside the
loop: `object:call` does a hashmap lookup on every invocation.

**BUILT.** A watchdog in `dd2forge_1on_curves.lua`, outside the one-shot guard. Every 15 frames it
sweeps the character list, and splits the two failure modes:
  * FLAGS LOST, same component address -> set both flags back, NO restart. The joints still carry
    their scale; the solver just needs permission to follow them again.
  * COMPONENT REBUILT (new address) -> the joint SCALES are gone too, so it sets `update_transforms`
    and hands off to the existing full path, which re-applies everything and restarts exactly once.
Counters are shown in the panel, so "is it working" is a number rather than a feeling. `CURVES_WATCH`
is a GLOBAL for the same documented reason `CHAIN_SCALE_FIX_ENABLED` is -- the panel is written 500
lines above it and a Lua local is invisible to anything earlier in the file. Syntax-checked with
`luac -p`.

**THE PERMANENT FIX, not done, worth knowing.** Because `chainAttrFlags` is header data in the
`.chain` file, authoring a patched `.chain` for the bust/butt chains with those bits set would make
the flags survive every rebuild at zero runtime cost, and the watchdog could be deleted.
NSACloud's RE-Chain-Editor supports DD2's `.chain` v54. The one experiment that would settle it:
flip the flag live, dump the chain's attr-flag uint before and after, and diff to learn which of
UNKN2..UNKN6 is which.

**ALL EIGHT REFINES FROM 2026-09-26 ARE NOW DONE.** Live script count 20, down from 24.
'@
Add-Content -Path $p -Value $t -Encoding UTF8
Write-Output ("field notes: appended {0} chars" -f $t.Length)
Write-Output ''
& 'D:\dd2-forge\tools\deploy.ps1' -Message 'curves: watchdog re-asserts the chain scale flags -- the 09-24 fix only ever ran when a slider moved' 2>&1 | Select-String -Pattern '^=== |app.js OK|present and parsing|  clean|pushed|main ->|ours-active' | ForEach-Object { $_.Line }
Write-Output ("deploy exit: {0}" -f $LASTEXITCODE)
Remove-Item 'D:\dd2-forge\tools\_note8.ps1' -Force
