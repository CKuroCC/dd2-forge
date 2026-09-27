$p = 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md'
$t = @'

### §16 — Progression split by category, DCP folded in, and rank vs qualification (2026-09-26)

[source: rebuild of dd2forge_3ng1_progress.lua against reference/dd2-types.tsv, sensitivity: internal]

**DOCUMENTED FACT — app.JobContext, the whole type.** Every progression write lives here:
  fields : ConsumableExp (Int32, THE DCP POOL), CulmativeExp (Int32[], per vocation),
           CurrentJob, QualifiedJobBits (UInt32), ChangedJobBits, ViewedNewJobBits,
           EquipedArmors, MaxEquipList
  methods: get_ConsumableExpProp() / set_ConsumableExpProp(Int32)        <- DCP
           get_NowJobCulmativeExpProp() / set_NowJobCulmativeExpProp(Int32)
           calcJobRank(JobEnum) / getMaxJobRank(JobEnum) / setJobExpWithJobRank(JobEnum, UInt32)
           getJobExp(JobEnum) / addJobExp(JobEnum)
           **isJobQualified(JobEnum) / setJobQualified(JobEnum)**
           isJobChanged / setJobChanged / isJobViewedNew / setJobViewedNew
           getWeapons(JobEnum) / getArmors(JobEnum) / setWeapon / setArmors / getEquipArmorList

**DOCUMENTED FACT — RANK AND QUALIFICATION ARE DIFFERENT THINGS, and we only ever did one.**
`setJobExpWithJobRank` sets how far a vocation has PROGRESSED. `setJobQualified` is what makes it
SELECTABLE at the Vocation Guild. Since 2026-09-21 this script has maxed ranks on all ten
vocations without ever calling setJobQualified, so a maxed rank could be sitting on a vocation
that never appeared in the guild list. Added as its own category, off by default. `QualifiedJobBits`
(UInt32) is the underlying bitfield if a bulk read is ever wanted.
[INFERENCE, untested] This may be the real explanation for any "a vocation is missing from the
guild" report on this save. Nobody has checked; the box is there now.

**MERGED.** `dd2forge_3ng3_dcp.lua` retired into `dd2forge_3ng1_progress.lua`. DCP was never a
panel's worth of work -- it is one property on a context this file already walks, and Discipline
Points are progression, so they belong beside ranks and augments. Mechanism unchanged from the
original (it was already correct): set_ConsumableExpProp, verified through get_ConsumableExpProp.
Queued FIRST so a DCP-only run finishes on the first tick instead of after the queue drains.

**SPLIT BY CATEGORY.** Six tick boxes -- core skills, weapon skills, augments, vocation ranks,
unlock vocations, Discipline Points -- and the run queues only what is ticked. Ranks still sort
LAST. The run button names what it is about to do rather than saying "unlock everything".
`phase23.json` is now required only for the three categories that iterate ids, so a DCP-only or
ranks-only run is no longer blocked by a reference file it never reads.

**BUG FIXED, pre-existing.** `setup()` never reset `tasks`, `ti`, `pendingTask` or `stats`. v1 was
a single button nobody pressed twice so it never showed. With categories, pressing it repeatedly
is the whole point, and without the reset the second run appended to the first one's queue and
re-walked everything already done. Found by reading, not by it failing.

**THE REFINE LIST IS DOWN TO ONE.** Of the eight Julian marked on 2026-09-26: map (§12a), the
plague cure (§13), stamina (§14), both affinity items (§15), and progress + DCP (this note) are
done. Only the curves/chain-physics revert remains, and §13 already names its likely cause --
writing the asset's shared ChainCustomSetting instead of installing our own with add_ref() and
the 0x20 use-custom-settings byte.

Live script count: 20, down from 24 at the start of the day. Nothing was deleted; four panels were
folded into the three that already owned their subject.
'@
Add-Content -Path $p -Value $t -Encoding UTF8
Write-Output ("field notes: appended {0} chars" -f $t.Length)
Write-Output ''
& 'D:\dd2-forge\tools\deploy.ps1' -Message 'progress: split into six categories, fold DCP in, add vocation qualification, reset the queue between runs' 2>&1 | Select-String -Pattern '^=== |app.js OK|present and parsing|  clean|pushed|main ->|ours-active' | ForEach-Object { $_.Line }
Write-Output ("deploy exit: {0}" -f $LASTEXITCODE)
Remove-Item 'D:\dd2-forge\tools\_note7.ps1' -Force
