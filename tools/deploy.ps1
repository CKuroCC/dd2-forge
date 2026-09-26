<#
deploy.ps1  --  the only way the site should go out.

    powershell -ExecutionPolicy Bypass -File tools\deploy.ps1 -Message "what changed"
    ... -Backup     also take a save backup first
    ... -NoPush     do everything, commit locally, stop before publishing

Why this exists: on 2026-09-25 the site was found publishing a script inventory
three days stale, listing names that had been renamed away, because refreshing
the data was a thing someone had to remember. Steps you have to remember are
steps that get skipped. This runs them in order and refuses to publish if any
of them fail.
#>
param(
    [Parameter(Mandatory = $true)][string]$Message,
    [switch]$Backup,
    [switch]$NoPush
)
$ErrorActionPreference = 'Stop'
$repo = 'D:\dd2-forge'
Set-Location -LiteralPath $repo

function Step($n, $t) { Write-Output ''; Write-Output "=== $n. $t" }

Step 1 'rebuild suite.json from the live autorun folder'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\refresh-site-data.ps1')
if ($LASTEXITCODE -ne 0) { throw 'refresh-site-data.ps1 failed' }

Step 2 'save inventory'
$saveArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $repo 'tools\scan-saves.ps1'))
if ($Backup) { $saveArgs += '-Backup' }
# Capture, THEN trim for display. Piping a running process into
# Select-Object -First closes the pipe early, the child dies, $LASTEXITCODE
# goes non-zero, and the deploy refuses over a scanner that worked perfectly.
$saveOut = & powershell @saveArgs
if ($LASTEXITCODE -ne 0) { $saveOut | ForEach-Object { Write-Output "  $_" }; throw 'scan-saves.ps1 failed' }
$saveOut | Select-Object -First 2 | ForEach-Object { Write-Output "  $_" }

Step 3 'javascript parses'
& node --check (Join-Path $repo 'assets\app.js')
if ($LASTEXITCODE -ne 0) { throw 'assets\app.js does not parse -- NOT deploying' }
Write-Output '  app.js OK'

Step 4 'every json the site loads is present and valid'
$appjs  = Get-Content -LiteralPath (Join-Path $repo 'assets\app.js') -Raw
$wanted = [regex]::Matches($appjs, "load\('([^']+\.json)'\)") |
          ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$bad = @()
foreach ($w in $wanted) {
    $p = Join-Path $repo "data\$w"
    if (-not (Test-Path -LiteralPath $p)) { $bad += "$w MISSING"; continue }
    try { Get-Content -LiteralPath $p -Raw | ConvertFrom-Json | Out-Null }
    catch { $bad += "$w INVALID JSON" }
}
if ($bad.Count) { $bad | ForEach-Object { Write-Output "  ! $_" }; throw 'data check failed -- NOT deploying' }
Write-Output ("  {0} json present and parsing" -f $wanted.Count)

Step 5 'nothing private is about to be committed'
$leaks = @()
Get-ChildItem -LiteralPath (Join-Path $repo 'data') -File -Filter *.json | ForEach-Object {
    $t = Get-Content -LiteralPath $_.FullName -Raw
    # the Steam account id is the one thing that has actually leaked in here
    if ($t -match '\\userdata\\\d{6,}\\') { $leaks += ($_.Name + ' contains a Steam account id') }
}
if ($leaks.Count) { $leaks | ForEach-Object { Write-Output "  ! $_" }; throw 'privacy check failed -- NOT deploying' }
Write-Output '  clean'

Step 6 'commit'
# git writes ordinary progress to stderr ("LF will be replaced by CRLF", "To
# https://github.com/..."). With $ErrorActionPreference = 'Stop' PowerShell turns
# any native stderr line into a TERMINATING NativeCommandError, so on 2026-09-26
# this script died silently at this step twice in a row when launched detached --
# the console host swallowed it and the log just stopped after "=== 6. commit".
# Git's real verdict is $LASTEXITCODE, never stderr. Suspend the preference here.
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & git add -A 2>&1 | Out-String | Write-Verbose
    $staged = (& git diff --cached --name-only) -join "`n"
    if (-not $staged) { Write-Output '  nothing to commit'; exit 0 }
    Write-Output $staged
    & git commit -q -m $Message 2>&1 | Out-String | Write-Output
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
    & git log --oneline -1 2>&1 | Out-String | Write-Output
} finally { $ErrorActionPreference = $prevEAP }

if ($NoPush) {
    Write-Output ''
    Write-Output 'COMMITTED LOCALLY, NOT PUSHED (-NoPush). `git push` when ready.'
    exit 0
}

Step 7 'push -- Vercel redeploys on this'
# Same stderr trap as step 6: git prints "To https://github.com/..." to stderr
# on every successful push.
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try { & git push 2>&1 | Out-String | Write-Output }
finally { $ErrorActionPreference = $prevEAP }
if ($LASTEXITCODE -ne 0) { throw 'push failed' }
Write-Output '  pushed'
