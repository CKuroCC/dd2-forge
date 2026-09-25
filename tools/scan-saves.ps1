<#
scan-saves.ps1  --  Dragon's Dogma 2 save inventory and backup vault.

Writes data\saves.json for the site's Saves tab. WITHOUT -Backup it only reads;
the only thing it ever creates is a timestamped copy under the vault, and the
vault lives OUTSIDE the repo on purpose -- save files have no business in a
public git history.

  powershell -ExecutionPolicy Bypass -File tools\scan-saves.ps1
  powershell -ExecutionPolicy Bypass -File tools\scan-saves.ps1 -Backup

Why it exists: on 2026-09-20 a new game overwrote data004Slot.bin and only a
copy taken eleven minutes earlier saved that morning. "Is this slot inside the
newest backup" should be a status, not a memory.
#>
param(
    [switch]$Backup,
    [int]$Keep = 40
)
$ErrorActionPreference = 'Stop'

$APPID = '2054970'
$repo  = 'D:\dd2-forge'
$vault = 'D:\Modding\DD2-SaveVault'

# --- find the save folder -------------------------------------------------
$roots = @()
foreach ($base in 'C:\Program Files (x86)\Steam\userdata',
                  'D:\SteamLibrary\userdata',
                  'C:\Program Files\Steam\userdata') {
    if (Test-Path -LiteralPath $base) {
        Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            # DD2 nests the actual saves one level down in win64_save; the
            # bare remote\ folder is empty, which made the first run of this
            # script report zero slots on an install with eight of them.
            foreach ($leaf in "$APPID\remote\win64_save", "$APPID\remote") {
                $p = Join-Path $_.FullName $leaf
                if ((Test-Path -LiteralPath $p) -and
                    @(Get-ChildItem -LiteralPath $p -File -ErrorAction SilentlyContinue).Count -gt 0) {
                    $roots += $p
                    break
                }
            }
        }
    }
}
if ($roots.Count -eq 0) {
    $out = [ordered]@{ error = "no Steam userdata\$APPID\remote folder found"; steamAppId = $APPID }
    $out | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo 'data\saves.json') -Encoding UTF8
    Write-Output "NO SAVE FOLDER FOUND - wrote an honest saves.json saying so"
    exit 0
}
$save = $roots[0]
Write-Output "save folder: $save"

# --- take a backup first, so the report describes the world after it -------
if ($Backup) {
    if (-not (Test-Path -LiteralPath $vault)) { New-Item -ItemType Directory -Path $vault -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $dest  = Join-Path $vault $stamp
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -Path (Join-Path $save '*') -Destination $dest -Recurse -Force
    $n = @(Get-ChildItem -LiteralPath $dest -Recurse -File).Count
    Write-Output "backup taken: $dest ($n files)"

    $all = @(Get-ChildItem -LiteralPath $vault -Directory | Sort-Object Name -Descending)
    if ($all.Count -gt $Keep) {
        $all | Select-Object -Skip $Keep | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
            Write-Output ("pruned old backup: " + $_.Name)
        }
    }
}

# --- the newest backup is what "backed up" is measured against -------------
$backupDirs = @()
if (Test-Path -LiteralPath $vault) {
    $backupDirs = @(Get-ChildItem -LiteralPath $vault -Directory | Sort-Object Name -Descending)
}
$newest = if ($backupDirs.Count -gt 0) { $backupDirs[0] } else { $null }
$newestFiles = @{}
if ($newest) {
    Get-ChildItem -LiteralPath $newest.FullName -File -Recurse | ForEach-Object {
        $newestFiles[$_.Name] = $_
    }
}

# --- inventory -------------------------------------------------------------
$slots = @()
$totalBytes = 0
Get-ChildItem -LiteralPath $save -File | ForEach-Object {
    $isSlot = $_.Name -match 'Slot\.bin$'
    $label  = if ($_.Name -match 'data(\d+)Slot\.bin') { "Slot " + [int]$Matches[1] } else { $_.Name }
    $b = $newestFiles[$_.Name]
    # "backed up" means a copy exists whose size AND timestamp match. A newer
    # save than the backup is EXPOSED, which is the whole point of the column.
    $backedUp = ($null -ne $b) -and ($b.Length -eq $_.Length) -and
                ([math]::Abs(($b.LastWriteTime - $_.LastWriteTime).TotalSeconds) -lt 2)
    $totalBytes += $_.Length
    $slots += [pscustomobject]@{
        label    = $label
        file     = $_.Name
        bytes    = $_.Length
        modified = $_.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss')
        isSlot   = $isSlot
        backedUp = [bool]$backedUp
    }
}

$backups = @()
foreach ($d in $backupDirs) {
    $f = @(Get-ChildItem -LiteralPath $d.FullName -File -Recurse)
    $sum = ($f | Measure-Object Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    $backups += [pscustomobject]@{
        name  = $d.Name
        taken = $d.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss')
        files = $f.Count
        bytes = $sum
    }
}

$slotOnly  = @($slots | Where-Object { $_.isSlot })
$exposed   = @($slotOnly | Where-Object { -not $_.backedUp })

$out = [ordered]@{
    generated  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    steamAppId = $APPID
    # The real path contains the Steam account id, and saves.json is committed
    # to a public repo. The path is useful, the id is nobody's business.
    saveDir    = ($save -replace '\\userdata\\\d+\\', '\userdata\<account>\')
    vaultDir   = $vault
    summary    = [ordered]@{
        slotCount        = $slotOnly.Count
        fileCount        = $slots.Count
        backupCount      = $backups.Count
        lastBackup       = if ($backups.Count) { $backups[0].taken } else { $null }
        totalBytes       = $totalBytes
        unprotectedSlots = $exposed.Count
    }
    slots   = $slots
    backups = $backups
}
$out | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $repo 'data\saves.json') -Encoding UTF8

Write-Output ("slots: {0}, files: {1}, {2:N0} bytes, backups: {3}, EXPOSED: {4}" -f
    $slotOnly.Count, $slots.Count, $totalBytes, $backups.Count, $exposed.Count)
$slots | ForEach-Object {
    Write-Output ("  {0,-10} {1,-22} {2,10:N0}  {3}  {4}" -f
        $_.label, $_.file, $_.bytes, $_.modified, $(if ($_.backedUp) { 'in backup' } else { 'EXPOSED' }))
}
