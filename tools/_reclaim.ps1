# Julian's approved clearance, 2026-09-25.
# NOTE: the function is NOT called Kill -- that is a built-in alias for
# Stop-Process, which silently shadowed it and deleted nothing on the first run.
$freed = 0
function Remove-Extra([string]$path, [string]$why) {
    if (-not (Test-Path -LiteralPath $path)) { Write-Output ("  absent  " + $path); return }
    $i = Get-Item -LiteralPath $path
    if ($i.PSIsContainer) {
        $b = (@(Get-ChildItem -LiteralPath $path -Recurse -File) | Measure-Object Length -Sum).Sum
        if ($null -eq $b) { $b = 0 }
        Remove-Item -LiteralPath $path -Recurse -Force
    } else {
        $b = $i.Length
        Remove-Item -LiteralPath $path -Force
    }
    $script:freed += $b
    Write-Output ("  {0,14:N0}  {1}   [{2}]" -f $b, $path, $why)
}

$game = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2'

Write-Output '=== the dump, now folded into reference\dd2-types.tsv ==='
Remove-Extra (Join-Path $game 'il2cpp_dump.json') 'folded, 9/9 lookups verified'

Write-Output '=== the dead pak ==='
Remove-Extra (Join-Path $game '_disabled_mods') 'disabled, and pak mods are dead on TU3.2'

Write-Output '=== superseded probes and research ==='
Remove-Extra (Join-Path $game 'reframework\data\dd2forge\deepdump.json') 'body-editor probe, superseded'
Remove-Extra 'D:\dd2-forge\research\setvocation12' 'superseded; 4MB of it was a screenshot'
Remove-Extra 'D:\dd2-forge\research\questtracker'  'superseded by our quest guide'
Remove-Extra 'D:\dd2-forge\research\plague416'     'superseded by dd2forge_1on_plague'
Remove-Extra 'D:\dd2-forge\research\fogremover'    'FogRemover.lua is installed; copy is redundant'

Write-Output '=== superseded field-note backups ==='
Remove-Extra 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md.bak-20260923'  'live file supersedes it'
Remove-Extra 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md.bak2-20260923' 'live file supersedes it'

Write-Output '=== committed json the site never loads ==='
$appjs  = Get-Content -LiteralPath 'D:\dd2-forge\assets\app.js' -Raw
$wanted = [regex]::Matches($appjs, "load\('([^']+\.json)'\)") | ForEach-Object { $_.Groups[1].Value }
Get-ChildItem -LiteralPath 'D:\dd2-forge\data' -File -Filter *.json | ForEach-Object {
    if ($wanted -notcontains $_.Name) { Remove-Extra $_.FullName 'nothing loads it' }
}

Write-Output ''
Write-Output ("FREED {0:N0} bytes ({1:N2} GB)" -f $freed, ($freed / 1GB))
