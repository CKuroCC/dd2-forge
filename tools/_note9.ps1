$p = 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md'
$t = @'

### §18 — INCIDENT: I detached Julian's player model from his camera (2026-09-26 23:48)

[source: live log + screenshot + one research run, sensitivity: internal]

**WHAT HAPPENED.** Thirty minutes after shipping the §17 chain watchdog, the player model stopped
following the camera. Controls, weapon draw, dialogue, minimap and skill prompts all kept working;
the body stayed standing in a crowd in Vernworth. Resolved by quit-and-reload. **Nothing was written
to the save** -- confirmed empirically by Julian, who quit and reloaded before being told to, and
came back clean.

**THE CAUSE WAS MINE, AND IT WAS TWO SEPARATE BUGS.**

**Bug 1 -- the rebuild detection was keyed by the wrong thing.** I wrote:
    watched[addr] -- keyed by chain ADDRESS, across every character in the scene
    if watched[addr] == nil and next(watched) ~= nil then rebuilt = rebuilt + 1 end
Julian was standing in a crowd. Every NPC that streamed in presented an address the table had never
seen and was counted as a rebuild OF HIS CHARACTER. That set `update_transforms = true`, which
re-ran `apply_joint_transforms` and therefore `restart_chain` across EVERY character in
`getAllCharacters()`, four times a second, for forty seconds. The log caught it:
"chain rebuilt on 1 character(s)" x5 between 23:48:52 and 23:49:24.
**A new address is not a rebuild. A rebuild is the SAME CHARACTER at a DIFFERENT address.**
Fixed: keyed by CharaID, and a character seen for the first time can never trigger a re-apply.

**Bug 2 -- THE PHASE WAS WRONG, and I had already been told so.** The loop ran in `re.on_frame`.
[FACT] EMV-Engine applies its frozen-joint transforms in
`re.on_application_entry("PrepareRendering")` -- AFTER the motion and behavior systems have written
the skeleton, BEFORE the frame draws -- and it ships FOUR alternative implementations of that loop
(UpdateMotion / UpdateBehavior / LateUpdateBehavior / PrepareRendering) precisely because the phase
is game-dependent [alphazolam/EMV-Engine init.lua:10650-10745]. Writing joint transforms from
on_frame means fighting the animation system for the same values, and whichever runs last wins that
frame. **The research run I commissioned for §17 contained this. I read it and shipped on_frame
anyway.** That is the more serious of the two failures: the information was in hand.

**MECHANISM [INFERENCE].** RE Engine has an explicit `LockScene` phase where the renderer takes a
consistent snapshot of scene transforms [FACT: it is an exposed application entry,
cursey.github.io/reframework-book; EMV refreshes joint world matrices there specifically,
init.lua:10423-10435]. Repeated external writes at the wrong side of that boundary, at scene scale,
left the render-side transform copy stale while the simulation side kept advancing. That is exactly
the observed split. Not provable from public sources; stated as inference.

**DOCUMENTED FACT -- this symptom is UNDOCUMENTED.** No report on Nexus, Reddit, Steam or
REFramework's tracker describes a DD2 player model detaching from the camera this way. Nearest
neighbour is Player and Pawn Scaler (mods/298) listing "Gradual size change may get into a bugged
state sometimes, resetting the pawn/player using the corresponding button usually resolves this".
Nobody else runs a loop that touches every character in a scene, so nobody else has produced it.

**DOCUMENTED FACT -- `via.motion.Chain:restart()` is a heavyweight re-initialisation, not a
refresh, and EMV deliberately makes it DEFERRABLE**: `reset_physics(do_deferred)` routes it through
a `deferred_calls` queue rather than executing inline [init.lua:10217-10228]. Its sibling
`set_CustomSetting` is a documented crasher without pcall [init.lua:4288]. Calling restart several
times a second across every character in a populated street is far outside any tested usage.

---

## ⛔ STANDING LUA SAFETY RULES -- adopt on every periodic loop from now on

These are not style. Every one of them corresponds to something that broke tonight or that a
shipped mod does deliberately.

**SCOPE**
1. NEVER iterate `getAllCharacters()` for a cosmetic effect. Resolve the player and party once,
   cache the handles, and work on those.
2. Validate a cached handle before every use and DROP it when stale. EMV's frozen-joint loop does
   exactly this: `if is_valid_obj(xform) then ... else frozen_joints[xform] = nil end`.
3. Cap the work per tick. A hard "at most N characters, N small" bound turns a misfire into a
   visual glitch instead of a scene-wide event.

**RATE**
4. [FACT] REFramework's own docs: "Try to minimize calling game methods when inside on_frame and
   on_draw_ui," and spread work across ticks. 15 frames is the shipped DD2 precedent (Zharay).
5. EDGE-TRIGGER, never level-trigger. Fire once per transition, not every tick a condition holds.
6. Debounce: the same character cannot be re-applied twice inside one interval.

**IDEMPOTENCE**
7. Read before writing. If the value already matches within epsilon, skip the call. This alone
   would have cut tonight's forty-second storm to a handful of writes.
8. Never call a restart/reset method unconditionally inside a periodic loop. Gate it on a real
   state change, call it ONCE, deferred, inside pcall.

**PHASE**
9. Re-assert joint transforms in `PrepareRendering` (or after `LateUpdateBehavior`), NEVER in
   `re.on_frame`, and never before the motion system runs.

**WATCHDOG DESIGN**
10. A watchdog needs a KILL SWITCH: a consecutive-failure counter that disables the feature and
    logs, rather than retrying forever. **Forty seconds of retries was the actual bug. The joint
    writes were only the payload.**
11. A watchdog must never re-broaden its own scope. If "re-apply to the player" fails, the answer
    is never "re-apply to everyone".
12. Keep an explicit revert path: store the original value at apply time so a bad state can be
    undone without a reload.
13. Ship anything that touches many objects DEFAULT OFF, behind a visible toggle, with the incident
    written on the panel.

**PROCESS RULE FOR ME, not the code:** when a research run hands me a safety finding, apply it in
the same session or write down why not. Bug 2 existed because I read the answer and shipped past it.
'@
Add-Content -Path $p -Value $t -Encoding UTF8
Write-Output ("field notes: appended {0} chars" -f $t.Length)
Write-Output ''
& 'D:\dd2-forge\tools\deploy.ps1' -Message 'curves: watchdog default OFF and detection keyed by character -- it detached the player model' 2>&1 | Select-String -Pattern '^=== |app.js OK|present and parsing|  clean|pushed|main ->|ours-active' | ForEach-Object { $_.Line }
Write-Output ("deploy exit: {0}" -f $LASTEXITCODE)
Remove-Item 'D:\dd2-forge\tools\_note9.ps1' -Force
