# Inventory only. Deletes nothing. Every removable bucket with a real size.
$rows = @()
function Add-Row($group, $path, $note) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $i = Get-Item -LiteralPath $path
    if ($i.PSIsContainer) {
        $f = @(Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue)
        $b = ($f | Measure-Object Length -Sum).Sum; if ($null -eq $b) { $b = 0 }
        $script:rows += [pscustomobject]@{ Group=$group; Item=(Split-Path $path -Leaf); Bytes=$b; Files=$f.Count; Note=$note; Path=$path }
    } else {
        $script:rows += [pscustomobject]@{ Group=$group; Item=$i.Name; Bytes=$i.Length; Files=1; Note=$note; Path=$path }
    }
}

# 1. Fluffy's mod archives, individually -- the 2.1 GB needs a breakdown
$fm = 'D:\Modding\FluffyModManager\games\DragonsDogma2\Mods'
if (Test-Path -LiteralPath $fm) {
    Get-ChildItem -LiteralPath $fm -File | ForEach-Object {
        Add-Row 'Fluffy archives' $_.FullName 'source archive; Fluffy needs it to uninstall'
    }
}

# 2. research: third-party mods downloaded to read
Get-ChildItem -LiteralPath 'D:\dd2-forge\research' -ErrorAction SilentlyContinue | ForEach-Object {
    Add-Row 'research' $_.FullName 'third-party mod kept for reference'
}

# 3. shelved scripts in the game's autorun
$auto = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\reframework\autorun'
foreach ($d in '_retired', '_backups') { Add-Row 'autorun shelved' (Join-Path $auto $d) 'old versions of our own scripts' }

# 4. committed data the site never reads
$appjs  = Get-Content -LiteralPath 'D:\dd2-forge\assets\app.js' -Raw
$wanted = [regex]::Matches($appjs, "load\('([^']+\.json)'\)") | ForEach-Object { $_.Groups[1].Value }
Get-ChildItem -LiteralPath 'D:\dd2-forge\data' -File -Filter *.json | ForEach-Object {
    if ($wanted -notcontains $_.Name) { Add-Row 'data (unread by site)' $_.FullName 'committed, nothing loads it' }
}

# 5. odds and ends
Add-Row 'game folder'   'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\_disabled_mods' 'a parked pak'
Add-Row 'game folder'   'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\sdk_ida' 'per-type headers; source of the pawn find'
Add-Row 'game folder'   'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\il2cpp_dump.json' 'full type database'
Add-Row 'game folder'   'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\Enums_Internal.hpp' 'every enum'
Add-Row 'game data'     'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\reframework\data\dd2forge\deepdump.json' 'body-editor probe'
Add-Row 'save vault'    'D:\Modding\DD2-SaveVault' 'your save backups'
Add-Row 'forge scratch' 'D:\dd2-forge\tmp' 'gitignored scratch'
Add-Row 'field notes'   'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md.bak-20260923' 'superseded backup'
Add-Row 'field notes'   'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md.bak2-20260923' 'superseded backup'

$rows | Sort-Object Bytes -Descending | ForEach-Object {
    Write-Output ("{0}`t{1}`t{2}`t{3}`t{4}" -f $_.Group, $_.Item, $_.Bytes, $_.Files, $_.Note)
}
Write-Output ("TOTAL`t`t{0}" -f (($rows | Measure-Object Bytes -Sum).Sum))
