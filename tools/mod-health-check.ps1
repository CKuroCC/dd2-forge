# DD2 mod health check - installed-vs-loaded audit for Fluffy + REFramework
# Built 2026-09-26. Run: powershell -NoProfile -ExecutionPolicy Bypass -File this.ps1

# ===================== PART 1 (fluffy-audit.ps1) =====================
$ErrorActionPreference = 'Continue'
$g = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2'

Write-Output '=== 1. REFramework log: pak / loose loader lines ==='
$log = Join-Path $g 're2_framework_log.txt'
if (Test-Path $log) {
    $li = Get-Item $log
    Write-Output ("log size={0} bytes  modified={1}" -f $li.Length, $li.LastWriteTime)
    Select-String -Path $log -Pattern 'pak_mods','LoadPakDirectory','Loose','\.pak' |
        Select-Object -First 30 | ForEach-Object { $_.Line.Trim() }
} else { Write-Output 'NO LOG' }

Write-Output ''
Write-Output '=== 2. loose_files log: size + Wilhelmina/nude entries ==='
$lf = Join-Path $g 'reframework_loose_files.txt'
$li = Get-Item $lf
Write-Output ("loose_files size={0} bytes  modified={1}  lines={2}" -f $li.Length, $li.LastWriteTime, (Get-Content $lf).Count)
Select-String -Path $lf -Pattern 'ch310002|3050|charaedit' | Select-Object -First 15 | ForEach-Object { $_.Line.Trim() }

Write-Output ''
Write-Output '=== 3. faulty_files ==='
$ff = Join-Path $g 'reframework_faulty_files.txt'
$fi = Get-Item $ff
Write-Output ("faulty size={0} modified={1}" -f $fi.Length, $fi.LastWriteTime)

Write-Output ''
Write-Output '=== 4. Nudify.lua identity ==='
$n = Join-Path $g 'reframework\autorun\Nudify.lua'
$ni = Get-Item $n
Write-Output ("size={0}  modified={1}  hash={2}" -f $ni.Length, $ni.LastWriteTime, (Get-FileHash $n -Algorithm MD5).Hash)
Get-Content $n -TotalCount 25

Write-Output ''
Write-Output '=== 5. crash dump timestamp ==='
$cd = Join-Path $g 'reframework_crash.dmp'
if (Test-Path $cd) { $ci = Get-Item $cd; Write-Output ("crash.dmp {0} bytes  {1}" -f $ci.Length, $ci.LastWriteTime) }

Write-Output ''
Write-Output '=== 6. natives tree: top folders + file-id suffix census ==='
$nat = Join-Path $g 'natives'
Get-ChildItem $nat -Directory | ForEach-Object { $_.FullName }
$all = Get-ChildItem $nat -Recurse -File
Write-Output ("total native files = {0}" -f $all.Count)
$all | ForEach-Object { if ($_.Name -match '\.(\d{6,})$') { $matches[1] } } |
    Group-Object | Sort-Object Count -Descending | Select-Object -First 15 |
    ForEach-Object { "  id {0}  x{1}" -f $_.Name, $_.Count }

Write-Output ''
Write-Output '=== 7. Wilhelmina files present? ==='
$w = @(
 'natives\stm\appsystem\charaedit\ch000\prebake\ch310002_0\body_mat_albd.tex.760230703',
 'natives\stm\appsystem\charaedit\ch000\prebake\ch310002_0\body_mat_nrra.tex.760230703',
 'natives\stm\character\_kit\_equipment\_furmasks\pants\pants_3050_f_mskm.tex.760230703',
 'natives\stm\character\_kit\_equipment\_furmasks\tops\tops_3050_f_mskm.tex.760230703',
 'reframework\data\MeshModEnabler\database\mantles\Female\Mantle_3050.json',
 'reframework\data\MeshModEnabler\database\pants\Female\Pants_3050.json',
 'reframework\data\MeshModEnabler\database\tops\Female\Tops_3050.json'
)
foreach ($p in $w) { $full = Join-Path $g $p; "{0}  {1}" -f (Test-Path $full), $p }

Write-Output ''
Write-Output '=== 8. other declared mod files present? ==='
$o = @(
 'reframework\autorun\AffinityBar.lua','reframework\fonts\GoNotoCurrent-Regular.ttf',
 'reframework\images\Heart_Love.png','reframework\autorun\CarryMeSenpai.lua',
 'reframework\autorun\NoSpaCensor.lua','reframework\autorun\gibbed_RiddleOfRuminationMarker.lua',
 'pak_mods\x0000-ClearDescriptions.pak','pak_mods\x0001-FemaleNudeMod-v2.4.pak',
 'pak_mods\x0002-NudeNatural_Sphinx_SF3D.pak','reframework\autorun\MeshModEnabler.lua',
 'dinput8.dll'
)
foreach ($p in $o) { $full = Join-Path $g $p; "{0}  {1}" -f (Test-Path $full), $p }

Write-Output ''
Write-Output '=== 9. dinput8.dll (REFramework) version/date ==='
$d = Get-Item (Join-Path $g 'dinput8.dll')
Write-Output ("dinput8.dll {0} bytes  modified={1}" -f $d.Length, $d.LastWriteTime)

Write-Output ''
Write-Output '=== 10. DD2.exe build date ==='
$e = Get-Item (Join-Path $g 'DD2.exe')
Write-Output ("DD2.exe {0} bytes  modified={1}" -f $e.Length, $e.LastWriteTime)

# ===================== PART 2 (fluffy-audit2.ps1) =====================
$ErrorActionPreference = 'Continue'
$g = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2'
$log = Join-Path $g 're2_framework_log.txt'

Write-Output '=== A. log: last boot marker + pak dir handling ==='
Select-String -Path $log -Pattern 'pak_mods' | Select-Object -First 20 | ForEach-Object { $_.Line.Trim() }
Write-Output '--- LoadPakDirectory / IntegrityCheck ---'
Select-String -Path $log -Pattern 'IntegrityCheck','Integrity','invalidat' | Select-Object -First 20 | ForEach-Object { $_.Line.Trim() }

Write-Output ''
Write-Output '=== B. log: every error / warning line (deduped tail) ==='
Select-String -Path $log -Pattern '\[error\]','\[warning\]' |
  ForEach-Object { $_.Line -replace '^\[[^\]]+\]\s*','' } |
  Group-Object | Sort-Object Count -Descending | Select-Object -First 40 |
  ForEach-Object { "x{0}  {1}" -f $_.Count, $_.Name }

Write-Output ''
Write-Output '=== C. log: script / lua mentions ==='
Select-String -Path $log -Pattern 'Nudify','MeshModEnabler','AffinityBar','NoSpaCensor','CarryMe','Rumination','\.lua' |
  Select-Object -Last 40 | ForEach-Object { $_.Line.Trim() }

Write-Output ''
Write-Output '=== D. native file id suffix by extension ==='
$nat = Join-Path $g 'natives'
Get-ChildItem $nat -Recurse -File | ForEach-Object {
    if ($_.Name -match '\.([a-z0-9_]+)\.(\d+)$') { "{0}.{1}" -f $matches[1], $matches[2] }
    elseif ($_.Name -match '\.([a-z0-9_]+)$') { "{0}.(none)" -f $matches[1] }
} | Group-Object | Sort-Object Count -Descending | Select-Object -First 25 |
  ForEach-Object { "  x{0}  {1}" -f $_.Count, $_.Name }

Write-Output ''
Write-Output '=== E. loose_files log: full distinct list (trimmed to path) ==='
$lf = Join-Path $g 'reframework_loose_files.txt'
Get-Content $lf | ForEach-Object { ($_ -split 'Dragons Dogma 2/')[-1] } |
  Sort-Object -Unique | Select-Object -First 60

Write-Output ''
Write-Output '=== F. accessed_files log ==='
$af = Join-Path $g 'reframework_accessed_files.txt'
$ai = Get-Item $af
Write-Output ("accessed_files {0} bytes  modified={1}" -f $ai.Length, $ai.LastWriteTime)

Write-Output ''
Write-Output '=== G. REFramework version string from log head ==='
Get-Content $log -TotalCount 12

# ===================== PART 3 (fluffy-audit3.ps1) =====================
$g = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2'
$rf = Join-Path $g 'reframework'

Write-Output '=== A. config JSONs the log complained about ==='
$j = @('MenuPerformanceFix.json','NoSpaCensor.json','Nudify.json','AffinityBar.json',
       'usercontent\injection_cache.json','usercontent\editor_settings.json','dd2forge\pawnhush.json',
       'CarryMeSenpai.json','FogRemover.json')
foreach ($f in $j) {
  $p = Join-Path (Join-Path $rf 'data') $f
  if (Test-Path $p) { $i = Get-Item $p; "{0,8} bytes  {1}  {2}" -f $i.Length, $i.LastWriteTime, $f }
  else { "  MISSING          {0}" -f $f }
}

Write-Output ''
Write-Output '=== B. reframework/data top level ==='
Get-ChildItem (Join-Path $rf 'data') | ForEach-Object { "{0}  {1}" -f $(if($_.PSIsContainer){'DIR '}else{'FILE'}), $_.Name }

Write-Output ''
Write-Output '=== C. zero-byte or 1-byte json anywhere under reframework ==='
Get-ChildItem $rf -Recurse -File -Filter *.json | Where-Object { $_.Length -lt 3 } |
  ForEach-Object { "{0} bytes  {1}" -f $_.Length, $_.FullName.Replace($g,'') }

Write-Output ''
Write-Output '=== D. _SharedCore + dependency-style folders in autorun ==='
Get-ChildItem (Join-Path $rf 'autorun') -Directory | ForEach-Object { $_.Name }
Write-Output '--- _SharedCore contents ---'
Get-ChildItem (Join-Path $rf 'autorun\_SharedCore') -Recurse -File | ForEach-Object { $_.FullName.Replace($rf,'') }

Write-Output ''
Write-Output '=== E. log: ScriptRunner / lua exception lines ==='
$log = Join-Path $g 're2_framework_log.txt'
Select-String -Path $log -Pattern 'ScriptRunner','lua:','attempt to','stack traceback','\.lua:' |
  Select-Object -First 25 | ForEach-Object { $_.Line.Trim() }

Write-Output ''
Write-Output '=== F. log: Wilhelmina / ch310002 / 760230703 anywhere ==='
Select-String -Path $log -Pattern 'ch310002','760230703','Wilhelmina' | Select-Object -First 10 | ForEach-Object { $_.Line.Trim() }
Write-Output '(none above = never requested)'

Write-Output ''
Write-Output '=== G. Nudify / MeshModEnabler evidence of running ==='
Select-String -Path $log -Pattern 'Nudify','MeshMod','Mesh Mod' | Select-Object -First 15 | ForEach-Object { $_.Line.Trim() }

Write-Output ''
Write-Output '=== H. Fluffy marker file ==='
Get-Content (Join-Path $g 'ModdedByFluffyModManager.txt')

# ===================== PART 4 (fluffy-audit4.ps1) =====================
$g = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2'
$log = Join-Path $g 're2_framework_log.txt'

Write-Output '=== Scripts loaded in the MOST RECENT boot ==='
$lines = Get-Content $log
$idx = ($lines | Select-String -Pattern 'Loading scripts\.\.\.' | Select-Object -Last 1).LineNumber
Write-Output ("last 'Loading scripts' at line {0} of {1}" -f $idx, $lines.Count)
$tail = $lines[($idx-1)..($lines.Count-1)]
$tail | Select-String -Pattern 'Running script' | ForEach-Object {
  ($_ -split '\\autorun\\')[-1] -replace '\.\.\.$',''
}

Write-Output ''
Write-Output '=== Any error/warning AFTER that boot marker ==='
$tail | Select-String -Pattern '\[error\]','\[warning\]' | Select-Object -First 30 | ForEach-Object { ($_.ToString() -replace '^\[[^\]]+\] \[REFramework\] ','').Trim() }

# ===================== PART 5 (fluffy-audit5.ps1) =====================
$g = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2'
Write-Output '=== reframework subfolders (plugins?) ==='
Get-ChildItem (Join-Path $g 'reframework') | ForEach-Object { "{0}  {1}" -f $(if($_.PSIsContainer){'DIR '}else{'FILE'}), $_.Name }
Write-Output '--- plugins dir contents ---'
$pl = Join-Path $g 'reframework\plugins'
if (Test-Path $pl) { Get-ChildItem $pl -Recurse | ForEach-Object { $_.Name } } else { Write-Output 'NO plugins FOLDER -> Pak Bridge / Natives Renamer NOT installed' }

Write-Output ''
Write-Output '=== natives install dates (grouped) ==='
Get-ChildItem (Join-Path $g 'natives') -Recurse -File |
  Group-Object { $_.LastWriteTime.ToString('yyyy-MM-dd') } |
  Sort-Object Name | ForEach-Object { "  {0}  x{1}" -f $_.Name, $_.Count }

Write-Output ''
Write-Output '=== the 4 old-id files: is there a current-id sibling? ==='
$dirs = @(
 'natives\STM\AppSystem\CharaEdit\ch000\prebake\ch310002_0',
 'natives\STM\Character\_kit\_equipment\_furmasks\pants',
 'natives\STM\Character\_kit\_equipment\_furmasks\tops')
foreach ($d in $dirs) {
  $p = Join-Path $g $d
  Write-Output ("-- {0}" -f $d)
  Get-ChildItem $p -File | Where-Object { $_.Name -match '3050|body_mat' } | ForEach-Object { "     {0}   ({1} bytes, {2})" -f $_.Name, $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd') }
}

