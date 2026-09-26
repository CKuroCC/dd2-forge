$ErrorActionPreference = 'Continue'
$g  = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2'
$a  = Join-Path $g 'reframework\autorun'
$out = @()

function Get-Purpose([string]$path) {
    $lines = Get-Content $path -TotalCount 14 -ErrorAction SilentlyContinue
    foreach ($l in $lines) {
        $t = $l.Trim()
        if ($t -match '^--+\s*=+' ) { continue }
        if ($t -match '^--\s*$') { continue }
        $t = $t -replace '^--+\s*',''
        if ($t.Length -gt 12 -and $t -notmatch '^=+$') { return $t }
    }
    return ''
}
function Get-Buttons([string]$path) {
    $src = Get-Content $path -Raw -ErrorAction SilentlyContinue
    if (-not $src) { return @() }
    return ,(([regex]::Matches($src,'imgui\.button\(\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }))
}
function Get-Writes([string]$path) {
    $src = Get-Content $path -Raw -ErrorAction SilentlyContinue
    if (-not $src) { return $false }
    return [bool]([regex]::IsMatch($src,'set_field|:call\("set[A-Z]|queue_add|write_'))
}

# ---- A/B: lua in autorun tree -------------------------------------------------
foreach ($f in (Get-ChildItem $a -Recurse -File -Filter '*.lua*' -ErrorAction SilentlyContinue)) {
    $rel = $f.FullName.Substring($a.Length + 1)
    $state = 'active'
    if     ($rel -match '^_retired\\')  { $state = 'retired' }
    elseif ($rel -match '^_backups\\')  { $state = 'backup'  }
    elseif ($rel -match '^autorun_OFF') { $state = 'disabled'}
    elseif ($f.Name -match '\.retired-') { $state = 'retired' }
    elseif ($rel -match '\\')           { $state = 'module'  }

    $ours = $f.Name -match '^dd2forge_'
    $kind = 'tool'
    if ($f.Name -match 'probe|Probe')      { $kind = 'probe' }
    elseif ($rel -match '^_SharedCore|^content_editor\\|^editors\\|^Hotkeys\\') { $kind = 'library' }
    elseif (-not $ours)                    { $kind = 'third-party' }

    $btns = Get-Buttons $f.FullName
    $out += [pscustomobject]@{
        group    = if ($ours) { 'dd2-forge script' } else { 'third-party script' }
        name     = $f.Name
        path     = $rel
        state    = $state
        kind     = $kind
        ours     = [bool]$ours
        bytes    = $f.Length
        modified = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        purpose  = Get-Purpose $f.FullName
        buttons  = @($btns)
        writes   = Get-Writes $f.FullName
        route    = 'reframework/autorun'
    }
}

# ---- D: Fluffy-managed mods ---------------------------------------------------
$ini = Get-Content 'D:\Modding\FluffyModManager\games\DragonsDogma2\installed.ini'
$cur = $null; $mods = @{}
foreach ($line in $ini) {
    if ($line -match '^\[(.+)\]$') { $cur = $matches[1]; $mods[$cur] = @{ files=@(); display=$cur } }
    elseif ($cur -and $line -match '^ModName=(.+)$') { $mods[$cur].display = $matches[1] }
    elseif ($cur -and $line -match '^file=(.+)$')    { $mods[$cur].files += $matches[1] }
}
foreach ($k in $mods.Keys) {
    $files = $mods[$k].files
    $present = @(); $missing = @()
    foreach ($fl in $files) {
        $p = Join-Path $g ($fl -replace '/','\')
        if (Test-Path $p) { $present += $fl } else { $missing += $fl }
    }
    $route = 'loose natives'
    if ($files -match '^pak_mods')              { $route = 'pak (pak_mods)' }
    elseif ($files -match 'reframework/autorun') { $route = 'lua script' }
    $stale = @($files | Where-Object { $_ -match '\.760230703$' }).Count
    $out += [pscustomobject]@{
        group    = 'Fluffy mod'
        name     = $mods[$k].display
        path     = $k
        state    = if ($missing.Count -gt 0) { 'files missing' } elseif ($stale -gt 0) { 'installed but inert' } else { 'installed' }
        kind     = 'mod'
        ours     = $false
        bytes    = 0
        modified = ''
        purpose  = ''
        buttons  = @()
        writes   = $false
        route    = $route
        filecount = $files.Count
        stalefiles = $stale
        missingfiles = @($missing)
    }
}

# ---- E: REFramework plugins ---------------------------------------------------
foreach ($p in (Get-ChildItem (Join-Path $g 'reframework\plugins') -File -ErrorAction SilentlyContinue)) {
    $out += [pscustomobject]@{
        group='REFramework plugin'; name=$p.Name; path='reframework/plugins'; state='active'; kind='plugin'
        ours=$false; bytes=$p.Length; modified=$p.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        purpose=''; buttons=@(); writes=$false; route='native dll'
    }
}

$out | ConvertTo-Json -Depth 6 | Set-Content 'D:\dd2-forge\data\inventory.json' -Encoding UTF8
Write-Output ("wrote {0} rows to D:\dd2-forge\data\inventory.json" -f $out.Count)
$out | Group-Object group | ForEach-Object { "  {0,-22} {1}" -f $_.Name, $_.Count }
Write-Output ''
$out | Group-Object state | Sort-Object Count -Descending | ForEach-Object { "  state {0,-20} {1}" -f $_.Name, $_.Count }
