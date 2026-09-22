<#
  dd2-forge :: save scanner
  2026-09-22

  Reads the DD2 save folder and the backup vault, and writes data/saves.json
  for the site's Saves tab. With -Backup it takes a timestamped copy FIRST,
  then scans, so the report always reflects the backup it just made.

  Why this exists: on 2026-09-20 a new game overwrote data004Slot.bin at
  12:38 and only a backup taken eleven minutes earlier preserved that
  morning's work. That was luck dressed up as discipline. This makes the
  discipline visible -- every slot carries how long it has gone unbacked, and
  the site says so in words rather than leaving it to memory.

  Read-only unless -Backup is passed. It never writes into the save folder.

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\scan-saves.ps1
    powershell -ExecutionPolicy Bypass -File tools\scan-saves.ps1 -Backup
#>
[CmdletBinding()]
param(
  [switch]$Backup,
  [string]$SaveDir  = "${env:ProgramFiles(x86)}\Steam\userdata\138831487\2054970\remote\win64_save",
  [string]$VaultDir = "D:\dd2-forge-saves",
  [string]$OutFile  = "",   # $PSScriptRoot is not populated inside param(), so resolve it below
  [int]$KeepBackups = 40
)

$ErrorActionPreference = "Stop"
function Info($m) { Write-Host "[saves] $m" }

if (-not $OutFile) { $OutFile = Join-Path (Split-Path $PSScriptRoot -Parent) "data\saves.json" }
New-Item -ItemType Directory -Force -Path (Split-Path $OutFile -Parent) | Out-Null

if (-not (Test-Path $SaveDir)) {
  Info "save folder not found: $SaveDir"
  @{ error = "save folder not found"; saveDir = $SaveDir; generated = (Get-Date).ToString("s") } |
    ConvertTo-Json | Set-Content $OutFile -Encoding UTF8
  exit 1
}

# ---------------------------------------------------------------- backup
New-Item -ItemType Directory -Force -Path $VaultDir | Out-Null
if ($Backup) {
  $stamp = (Get-Date).ToString("yyyy-MM-dd_HHmmss")
  $dest  = Join-Path $VaultDir $stamp
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item "$SaveDir\*" $dest -Recurse -Force
  $n = (Get-ChildItem $dest -File -Recurse).Count
  Info "backed up $n files -> $dest"

  # Prune oldest, but never below KeepBackups. Deleting a backup is the one
  # destructive thing here, so it only ever touches the vault we created.
  $all = Get-ChildItem $VaultDir -Directory | Sort-Object Name
  if ($all.Count -gt $KeepBackups) {
    $all | Select-Object -First ($all.Count - $KeepBackups) | ForEach-Object {
      Remove-Item $_.FullName -Recurse -Force
      Info "pruned old backup $($_.Name)"
    }
  }
}

# ---------------------------------------------------------------- scan
# DD2 writes one file per slot plus a couple of loose ones. data00-1 and
# data000 are not "Slot" files and are reported separately rather than being
# silently folded into the slot list.
function SlotLabel($name) {
  if ($name -match '^data(\d+)Slot\.bin$') { return "Slot " + [int]$matches[1] }
  if ($name -eq 'data00-1.bin')            { return "Autosave / working" }
  if ($name -match '^data(\d+)\.bin$')     { return "Loose " + [int]$matches[1] }
  return $name
}

$backups = @(Get-ChildItem $VaultDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
$lastBackup = if ($backups.Count) { $backups[-1] } else { $null }
$lastBackupTime = if ($lastBackup) {
  try { [datetime]::ParseExact($lastBackup.Name, "yyyy-MM-dd_HHmmss", $null) }
  catch { $lastBackup.CreationTime }
} else { $null }

$slots = @()
foreach ($f in (Get-ChildItem $SaveDir -File | Sort-Object Name)) {
  # Is this exact file present in the newest backup, byte-for-byte by size+time?
  $covered = $false
  if ($lastBackup) {
    $b = Join-Path $lastBackup.FullName $f.Name
    if (Test-Path $b) {
      $bi = Get-Item $b
      $covered = ($bi.Length -eq $f.Length) -and
                 ([math]::Abs(($bi.LastWriteTime - $f.LastWriteTime).TotalSeconds) -lt 2)
    }
  }
  $ageH = if ($lastBackupTime) { [math]::Round((($f.LastWriteTime) - $lastBackupTime).TotalHours, 1) } else { $null }
  $slots += [pscustomobject]@{
    file      = $f.Name
    label     = (SlotLabel $f.Name)
    bytes     = $f.Length
    modified  = $f.LastWriteTime.ToString("s")
    isSlot    = ($f.Name -match 'Slot\.bin$')
    backedUp  = $covered
    driftHours= $ageH      # >0 means the save moved on after the last backup
  }
}

# PowerShell 5.1 has no if-expression and no inline try/catch expression, so
# the parsing lives in a function instead of being inlined into the hashtable.
function StampOf($dir) {
  try { return [datetime]::ParseExact($dir.Name, "yyyy-MM-dd_HHmmss", $null) }
  catch { return $dir.CreationTime }
}

$backupRows = @()
foreach ($b in ($backups | Sort-Object Name -Descending | Select-Object -First 25)) {
  $files = Get-ChildItem $b.FullName -File -Recurse
  $backupRows += [pscustomobject]@{
    name  = $b.Name
    files = $files.Count
    bytes = ($files | Measure-Object Length -Sum).Sum
    taken = (StampOf $b).ToString("s")
  }
}

$unprotected = @($slots | Where-Object { $_.isSlot -and -not $_.backedUp })
$lastBackupStr = $null
if ($lastBackupTime) { $lastBackupStr = $lastBackupTime.ToString("s") }
$out = [pscustomobject]@{
  generated   = (Get-Date).ToString("s")
  saveDir     = $SaveDir
  vaultDir    = $VaultDir
  steamAppId  = "2054970"
  slots       = $slots
  backups     = $backupRows
  summary     = [pscustomobject]@{
    slotCount        = @($slots | Where-Object { $_.isSlot }).Count
    fileCount        = $slots.Count
    totalBytes       = ($slots | Measure-Object bytes -Sum).Sum
    backupCount      = $backups.Count
    lastBackup       = $lastBackupStr
    unprotectedSlots = $unprotected.Count
    newestSave       = (($slots | Sort-Object modified -Descending | Select-Object -First 1).modified)
  }
}

$out | ConvertTo-Json -Depth 6 | Set-Content $OutFile -Encoding UTF8
Info ("wrote {0} -- {1} files, {2} backups, {3} slots unprotected" -f `
  (Resolve-Path $OutFile), $slots.Count, $backups.Count, $unprotected.Count)
