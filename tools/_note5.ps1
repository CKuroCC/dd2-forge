$p = 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md'
$t = @'

### §14 — Stamina: the engine's own switch, and a readout that never worked (2026-09-26)

[source: grep of reference/dd2-types.tsv + rebuild of dd2forge_2do_carry.lua, 2026-09-26, sensitivity: internal]

**CORRECTION TO §13, made the same day.** §13 stated that `app.StaminaManager.get_MaxValue`
does not exist on TU3.2 and that the community gist recommending it would throw. **That was
wrong, and it was my own grep pattern at fault, not the game.** A full listing of
`^app\.StaminaManager\t` shows `get_MaxValue` plainly. The lesson is narrow and worth keeping:
a negative result from a keyword grep is NOT evidence of absence -- list the whole type before
claiming a member is missing. §13's other corrections stand; this one does not.

**DOCUMENTED FACT — the full app.StaminaManager surface.** It is far richer than any public
write-up suggests, and it is all public methods, no field pokes needed:
  get_MaxValue() / setMaxValue(Single)
  get_ReducedMaxValue() / setReducedMaxValue(Single) / addReducedMaxValue(Single)
  get_ReducedMaxValueRatio() / get_OriginalRemainingRatio() / get_ReducedRemainingRatio()
  get_RemainingAmount() / setRemainingAmount(Single) / add(Single)
  setMinValue(Single) / get_MinReducedMaxValue()
  recoverAll() / recoverRemainingAmount() / recoverRemainingAmountAndMaxValueCompletely() / consumeAll()
  get_IsRunningOutOf() / get_IsOriginalFullAmount() / get_IsReducedFullAmount()
  get_IsReducedMaxValueZero() / get_IsOriginalNearlyRunningOutOf() / get_IsReducedNearlyRunningOutOf()
  get_IsEnableConsume() , get_IsMinusAmountEnable()
  fields: <IsEnableConsume>k__BackingField, <IsMinusAmountEnable>k__BackingField,
          <MaxValue>k__BackingField, <RemainingAmount>k__BackingField, MinValue,
          RateNearlyRunOutValue, IsSetup, OnAddHandler, ConvertAddValueHandler

**DOCUMENTED FACT — `<IsEnableConsume>` is the out-of-combat answer and nobody uses it.**
Every published DD2 out-of-combat stamina mod (Nexus 93, the Arakunido TU3.2 gist, UDD2P 1147)
polls the combat flag and then calls `recoverAll()` to refill what was just drained. The drain
still HAPPENS; it is merely undone, so the bar flickers and any mid-frame reader sees the dip.
Flipping `IsEnableConsume` to false stops consumption occurring at all. There is no
`set_IsEnableConsume`, so the backing field is the only way in -- acceptable here because it is a
plain bool with no change handler, and it is read straight back through `get_IsEnableConsume()`.

**DOCUMENTED FACT — a silent failure that had been running for five days.**
`dd2forge_2do_carry.lua` reported "derived StaminaManager.MaxValue" via
  player:get_GameObject() -> getComponent(System.Type, typeof app.StaminaManager)
inside a bare pcall. **StaminaManager is not a via.Component**, so that call threw on every run
since 2026-09-21, the pcall swallowed it, and the panel printed `nil` every time without anyone
reading `nil` as a failure. That is precisely why "verify the higher stamina amount" stayed an
open question for five days -- the instrument we were verifying against had never once worked.
The real accessor is `app.CharacterManager.get_ManualPlayer() -> app.Character.get_StaminaManager()`.
**RULE: a pcall around a read must distinguish "returned nil" from "threw". Printing nil as if it
were a value is how a broken instrument survives for days.** Same family as §12's fake percentage.

**DOCUMENTED FACT — drain is data, not a setter.** app.HumanStaminaParameter.ConsumeData is a 2-D
table of ActionType x encumbrance rank (VeryLight/Light/Middle/Heavy/VeryHeavy/Over), so raising
carry capacity already cuts stamina drain by keeping you in a cheaper column.
`FactorConsumeOnNotBattleDash` and `FactorConsumeOnNotBattleDashOnNormalMode` are single floats
scaling non-battle sprint cost, each with a get_*Prop accessor. `app.HumanStaminaController` owns
the real work: consumeStamina(), calcConsumeStaminaValue(ConsumeData), calcConsumeRatioBySlope(),
buildInfinityDashArea(), plus applyStaminaPenaltyByEquipmentLevel / BySpellStock. The engine
already ships free-sprint zones via app.HumanInfinityDashAreaData.AIArea -- an untried alternative
route to the same goal.

**BUILT.** `dd2forge_2do_carry.lua` now reports max / cap-in-force / current / running-out live,
and carries a "no stamina cost out of combat" toggle gated on `app.BattleManager.get_IsBattleMode()`
with an optional weapon-sheathed second gate, checked every 15 frames (Zharay's cadence). An
unreadable combat state counts as IN combat so it fails safe, and consumption is restored on
toggle-off and on script reset. Syntax-checked with `luac -p` before loading.
'@
Add-Content -Path $p -Value $t -Encoding UTF8
Write-Output ("field notes: appended {0} chars" -f $t.Length)
Write-Output ''
& 'D:\dd2-forge\tools\deploy.ps1' -Message 'stamina: engine IsEnableConsume gate for out-of-combat, and fix a readout that never worked' 2>&1 | Select-String -Pattern '===|OK|clean|present|pushed|commit|main ->|exit' | ForEach-Object { $_.Line }
Write-Output ("deploy exit: {0}" -f $LASTEXITCODE)
Remove-Item 'D:\dd2-forge\tools\_note5.ps1' -Force
