# refresh-site-data.ps1
# Rebuilds data\suite.json from the LIVE autorun folder and re-copies the small
# JSON the site reads. Run before a site deploy; the site is only as honest as
# this file. Written 2026-09-25 after suite.json was found three days stale and
# still listing script names that had been renamed away.
$ErrorActionPreference = 'Stop'
$repo = 'D:\dd2-forge'
$auto = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\reframework\autorun'
$gdat = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\reframework\data\dd2forge'

function Get-State([string]$name) {
    # Folder wins over extension. A file in _retired\ or _backups\ is still
    # called *.lua, so testing the extension first marked 39 shelved scripts
    # "active" and the site would have claimed 65 armed scripts when 25 are.
    if ($name -match '^_retired\\')              { return 'backup' }
    if ($name -match '^_backups\\')              { return 'backup' }
    if ($name -match '\.superseded$')            { return 'superseded' }
    if ($name -match '\.disabled$')              { return 'disabled' }
    if ($name -match '\.done$')                  { return 'done' }
    if ($name -match '\.(bak|retired)[^\\]*$')   { return 'backup' }
    if ($name -match '\.lua$')                   { return 'active' }
    return 'backup'
}

$scripts = @()
Get-ChildItem -LiteralPath $auto -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($auto.Length + 1)
    # only top-level scripts and the retired bin; module folders belong to their mod
    if ($rel -match '\\' -and $rel -notmatch '^(_retired|_backups)\\') { return }
    $scripts += [pscustomobject]@{
        name     = $rel.Replace('\', '/')
        bytes    = $_.Length
        state    = (Get-State $rel)
        ours     = ($_.Name -like 'dd2forge_*')
        modified = $_.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss')
    }
}

$suite = [ordered]@{
    generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    game      = "Dragon's Dogma 2"
    build     = '3.2.0.0'
    platform  = 'Steam / PC'
    scripts   = @($scripts | Sort-Object name)
}
$suite | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $repo 'data\suite.json') -Encoding UTF8
Write-Output ("suite.json rebuilt: {0} entries, {1} ours-active" -f
    $scripts.Count, @($scripts | Where-Object { $_.ours -and $_.state -eq 'active' }).Count)

# Copy ONLY the JSON the site actually reads, and get that list from the site
# itself rather than a second list that can drift. "Everything under 500 KB"
# was the first version and it dragged 21 probe dumps and two prefs files --
# including the quest guide's done-list and the item browser's cart -- into a
# public repo. Nothing consumed them and nobody asked for them there.
$appjs = Get-Content -LiteralPath (Join-Path $repo 'assets\app.js') -Raw
$wanted = [regex]::Matches($appjs, "load\('([^']+\.json)'\)") |
          ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Write-Output ("site reads {0} json: {1}" -f $wanted.Count, ($wanted -join ', '))

$copied = 0; $missing = @()
foreach ($w in $wanted) {
    $src = Join-Path $gdat $w
    if (Test-Path -LiteralPath $src) {
        Copy-Item $src (Join-Path $repo "data\$w") -Force
        $copied++
    } else {
        # not every file comes from the game -- quests.json and saves.json are
        # built by their own tools. Only shout if neither source has it.
        if (-not (Test-Path -LiteralPath (Join-Path $repo "data\$w"))) { $missing += $w }
    }
}
Write-Output "data/: $copied refreshed from the game"
if ($missing.Count) { Write-Output ("MISSING, site will 404 on: " + ($missing -join ', ')) }

Write-Output '--- ours, active, as the site will now show them ---'
$scripts | Where-Object { $_.ours -and $_.state -eq 'active' } | Sort-Object name |
    ForEach-Object { Write-Output ("  {0,-38} {1,8:N0}  {2}" -f $_.name, $_.bytes, $_.modified) }
Write-Output '--- third-party, active ---'
$scripts | Where-Object { -not $_.ours -and $_.state -eq 'active' } | Sort-Object name |
    ForEach-Object { Write-Output ("  {0,-38} {1,8:N0}" -f $_.name, $_.bytes) }
