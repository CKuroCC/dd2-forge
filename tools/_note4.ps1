$p = 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md'
$t = @'

### §13 — Four research runs, and the folded dump beating all four (2026-09-26)

[source: 4 parallel research sub-agents + grep of reference/dd2-types.tsv, 2026-09-26, sensitivity: internal]

**THE META-FINDING, and it is the most valuable line in this file.**
All four research agents independently reported the SAME blocker: *"no published DD2 il2cpp
METHOD dump exists anywhere I could reach."* We have had one on disk since 2026-09-25 --
`reference/dd2-types.tsv`, 52 MB, 341,300 methods, built by `tools/fold-il2cpp-dump.py`.
One grep answered every question four agents spent ~715,000 tokens failing to answer from the
public web, and CORRECTED three of their conclusions. **Grep the dump BEFORE commissioning
external research on an engine symbol.** Web research is for behaviour, conflicts and prior art;
the dump is for names.

**DOCUMENTED FACT — DRAGONSPLAGUE. The engine calls it "Possession".**
  app.PawnDataContext  setPossessionLv(System.Int32)
  app.PawnDataContext  setPossessionProgressPoint(System.Int32)   <- research said NO SETTER EXISTS. It does.
  app.PawnDataContext  get_PossessionProgressPoint() / addPossessionProgressPoint(Int32)
  app.PawnDataContext  _PossessionLv, _PossessionProgressPoint, _LastPossessionCheckTime (fields)
  app.PawnDataContext  ChangedPossessionLvHandler : Action`3<Int32,Int32,DummyArg1>  (note: THREE args, not one)
  app.PawnManager      setPossessionLV(app.CharacterID)        <- manager-level, capital LV
  app.PawnManager      setPossessionLVMainPawn(app.PawnDataContext)
  app.PawnManager      get_PawnCharacterList() -> List`1<app.Character>
  app.PawnManager      <IsBetrayalPawn>k__BackingField (Bool)
  app.PossessionManager changeEyeGlow(System.Int32) / changeEyeGlow(app.PawnDataContext)
                        <- research said "lingering eyes are cosmetic, don't chase them". There is a clean method.
  app.Human            get_PossessionManager() -> app.PossessionManager
  app.FacilityManager  judgPossession() -> Boolean

**DOCUMENTED FACT — AFFINITY IS TWO SYSTEMS, and the pawn half lives somewhere nobody guessed.**
  app.MainPawnDataContext  _FavorabilityRating (Single), _AccumulatedFavorability (Single)
  app.MainPawnDataContext  setFavorabilityRating(System.Single), resetAccumulatedFavorability() -> Void
  app.MainPawnDataContext  get_FavorabilityRating(), get_AccumulatedFavorability()
  app.PawnManager          addMainPawnFavorability(FavorabilityActionType) / decreaseMainPawnFavorability(...)
  app.Character            get_SentimentController() -> app.SentimentController   <- the NPC half, found nowhere public
  app.PawnDefine           MinFavorabilityRating (Single)
Research (correctly) established the MODEL: NPC "Sentiment" is Int16, roughly 0-300, in-love
around 185-200, with per-NPC SentimentPlusRatio/MinusRatio; main-pawn "Favorability" is a float
0-1000 with vanilla `_LoveThreshold` = 620. The DD2 "beloved" is MAX-OF-SET at the Legacy
endgame, not a threshold -- which is exactly why maxing everyone is destructive and a
"set everyone to 50" button is the right tool. NPC roster AND gender are enumerable at runtime
via app.NPCManager.CharacterDataList -> app.CharacterData.Gender, so the 526-name list can go.

**DOCUMENTED FACT — STAMINA. One correction that matters.**
  app.BattleManager    get_IsBattleMode() -> Boolean        (global)
  app.Human            get_IsBattleMode() -> Boolean        (per-character, finer)
  app.Character        get_IsDrawedWeapon(), get_StaminaManager(), recoverAll()
  app.StaminaManager   get_RemainingAmount(), get_ReducedMaxValue(), get_ReducedMaxValueRatio(), recoverAll()
**`app.StaminaManager.get_MaxValue` DOES NOT EXIST in our dump.** The community gist that
research recommended adopting calls it as a fallback. On TU3.2 the live cap is
`get_ReducedMaxValue`. Anyone porting that gist must drop the fallback or it throws.
Drain is data, not a setter: app.HumanStaminaParameter.ConsumeData is a 2-D table of
ActionType x encumbrance rank (VeryLight/Light/Middle/Heavy/VeryHeavy/Over), and
`FactorConsumeOnNotBattleDash` is a single float scaling non-battle sprint cost.
Stamina is System.Single throughout -- no integer overflow, but stay well under 2^24.

**DOCUMENTED FACT — CHAIN PHYSICS. The dump cannot help here, and that is itself the finding.**
`set_CustomSetting`, `copySetting`, `blendSetting` and `ChainCustomSetting` return ZERO hits:
they are `via.motion.*`, and our folded dump covers `app.*` only. For engine-namespace symbols
the dump is silent and REFramework's own headers are the source. Research did land the real
answer there: the supported path is create `via.motion.ChainCustomSetting` -> `.ctor` ->
`chain:copySetting(id, cs)` -> **`cs:add_ref()`** -> `group:write_byte(0x20, 1)` ->
`pcall(group:set_CustomSetting(cs))`. Writing the asset's own shared settings object instead is
almost certainly why our curves fix reverts. Also: **Mesh Mod Enabler (Nexus 436, v1.05,
2024-11-13) is documented broken post-September-2026 and apparently abandoned** -- first thing
to pull when chasing a physics conflict.

**BUILT THIS SESSION.** `dd2forge_1on_plague.lua` gains a CURE pass beside its two prevention
hooks: per pawn, setPossessionLv(0) then setPossessionProgressPoint(0), read back through the
accessors, then PossessionManager.changeEyeGlow(0). Refuses outright while
`<IsBetrayalPawn>k__BackingField` is true. Touches nothing in app.FacilityManager or
app.PawnPartyFacilityInfo -- those record that a massacre already happened and five
app.decision.condition.* nodes read them; clearing them would tell the game a wipe never
occurred while the NPCs stay dead. Syntax-checked with `luac -p` before it ever loaded.
'@
Add-Content -Path $p -Value $t -Encoding UTF8
Write-Output ("field notes: appended {0} chars" -f $t.Length)
Write-Output ''
& 'D:\dd2-forge\tools\deploy.ps1' -Message 'plague: add a verified cure-all-pawns pass beside the prevention hooks' 2>&1 | Out-String | Write-Output
Write-Output ("deploy exit: {0}" -f $LASTEXITCODE)
Remove-Item 'D:\dd2-forge\tools\_note4.ps1','D:\dd2-forge\tools\_sig.ps1','D:\dd2-forge\tools\_sig2.ps1' -Force -ErrorAction SilentlyContinue
