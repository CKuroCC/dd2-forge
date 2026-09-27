$p = 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md'
$t = @'

### §15 — Affinity: the 199 clamp solved, and the wiki list retired (2026-09-26)

[source: full type listings from reference/dd2-types.tsv + merge of dd2forge_3ng4 into 2do_affinity, sensitivity: internal]

**DOCUMENTED FACT — THE 199 CLAMP IS `app.NPCHolder.SentimentValueMax` (System.Int32).**
For four days the header of dd2forge_2do_affinity.lua carried this open question: twenty-one
named NPCs (Aimee, Arno, Dorica, Eva, Evelyn, Felicia, Francisca, Harvey, Jeremy, Jinn, Lepak,
Litra, Madeline, Magorr, Margaret, Rakim, Richare, Rick, Serra, Thed, Trekk) stop at exactly 199
when asked for 299, 21 for 21, on two different saves. The file guessed the cause was
"InitSentimentPLRank / SentimentPlusRatio / Unique on app.CharacterData". **It is none of those.**
It is a per-NPC ceiling field sitting on `app.NPCHolder` -- the object the script was already
holding in its hand on every single write. A full listing of `^app\.NPCHolder\t` shows it plainly.
**Same lesson as §14: list the whole type. Four days of mystery, one field, zero new research.**

**DOCUMENTED FACT — app.NPCHolder, the sentiment surface.**
  fields: CharaID, SentimentValueMax, SentimentToPlayer / SentimentTempToPlayer (app.SentimentInfo),
          _SentimentDic / _SentimentTempDic : Dictionary`2<app.CharacterID, app.SentimentInfo>,
          _isSentimentKill
  methods: getSentimentOrigValue(CharacterID), getSentimentOrigRank(CharacterID),
           getSentimentRank(CharacterID), getSentimentInfo(CharacterID),
           setSentimentValue(CharacterID, Int32, Boolean), addSentimentValue(...),
           addSentimentForPL(SentimentActionIDEnum), PresentFromPL_addSentiment(ItemIDEnum),
           clearSentimentDictionary(), clrSentimentTempValue(), decSentimentIfKill()
  app.SentimentRank enum: None, Hate, Kill, KillMax, Like, Love, LoveMax, Normal.
  Measured values already in the script: Like = 100, Love = 200, LoveMax = 299.

**DOCUMENTED FACT — the roster and gender are game data, not wiki data.**
  app.NPCManager        CharacterDataList : List`1<app.CharacterDataList>
  app.CharacterDataList characterDataList : app.CharacterData[]
  app.CharacterData     Gender : app.CharacterData.GenderDefine {Man, Woman, Other}
                        _SubNPC (Bool), _isNPCPawn (Bool), get_Name() -> String,
                        Unique : UniqueNPCDefine {S, A, B}, get_appGender() -> app.Gender
The script's 526 female names came from scraping Fextralife and its own header admitted roughly
290 of 1,703 holder slots had no wiki entry. The walk above replaces it. GenderDefine ordinals are
resolved from the enum AT RUNTIME (`fd:is_static()` + `fd:get_data(nil)`) rather than hardcoded --
a guessed ordinal is how you silently select the men instead.

**DOCUMENTED FACT — main pawn favorability is complete and separate.**
  app.MainPawnDataContext  _FavorabilityRating (Single), _AccumulatedFavorability (Single)
                           setFavorabilityRating(Single), addFavorability(Single),
                           decreaseFavorability(Single), resetAccumulatedFavorability() -> Void,
                           get_FavorabilityRating(), get_AccumulatedFavorability(),
                           **get_IsLove() -> Boolean**
`get_IsLove()` means the 620 threshold never has to be hardcoded again -- ask the engine.

**DOCUMENTED FACT — the engine has its own "who likes me most" queries**, which is the same
selection the Legacy hostage scene uses: app.NPCManager.getBestSentimentNPCs(),
getBestSentimentNPCsSpa(app.Gender), getBestSentimentNPCsResult(), getBestSentimentMinID().
Untried, but they are the authoritative answer to "who is currently top" and would beat computing
it ourselves.

**MERGED.** `dd2forge_3ng4_affinity.lua` is retired into `dd2forge_2do_affinity.lua`. Its single
button was "MAX AFFINITY WITH EVERYONE", which is precisely what the warning at the top of the
affinity panel says not to do: the DD2 beloved is MAX-OF-SET at the Legacy confrontation, so
maxing everyone makes the hostage an arbitrary tie-break. It comes across as "set every NPC to a
value you choose", defaulting to 50 -- below Like (100), so present but not affectionate -- with
an optional "leave <name> alone". Also added: a read-only PER-NPC CEILING report that prints
SentimentValueMax per holder plus a distribution, so the 21 names are now a number you can look at.
Live set is down to 21 scripts from 24 this morning. Syntax-checked with `luac -p`.
'@
Add-Content -Path $p -Value $t -Encoding UTF8
Write-Output ("field notes: appended {0} chars" -f $t.Length)
Write-Output ''
& 'D:\dd2-forge\tools\deploy.ps1' -Message 'affinity: merge 3ng4 in, retire the wiki female list for the live roster, solve the 199 clamp' 2>&1 | Select-String -Pattern '^=== |app.js OK|present and parsing|  clean|pushed|main ->|ours-active' | ForEach-Object { $_.Line }
Write-Output ("deploy exit: {0}" -f $LASTEXITCODE)
Remove-Item 'D:\dd2-forge\tools\_note6.ps1' -Force
