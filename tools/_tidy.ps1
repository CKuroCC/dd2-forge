# Undo the over-broad copy the first refresh made, and remove the last two
# scratch scripts. Only touches files git does NOT track, so nothing that was
# ever deliberately committed can be lost.
$repo = 'D:\dd2-forge'
Set-Location -LiteralPath $repo

$appjs  = Get-Content -LiteralPath 'assets\app.js' -Raw
$wanted = [regex]::Matches($appjs, "load\('([^']+\.json)'\)") | ForEach-Object { $_.Groups[1].Value }
$tracked = @(& git ls-files 'data/*.json') | ForEach-Object { Split-Path $_ -Leaf }

$removed = 0
Get-ChildItem -LiteralPath 'data' -File -Filter *.json | ForEach-Object {
    if ($wanted -contains $_.Name)  { return }   # the site reads it
    if ($tracked -contains $_.Name) { return }   # it was committed on purpose
    Write-Output ("  drop {0,10:N0}  data\{1}" -f $_.Length, $_.Name)
    Remove-Item -LiteralPath $_.FullName -Force
    $script:removed++
}
Write-Output "dropped $removed unused json from data\"

foreach ($f in 'tools\_cleanup_inventory.ps1', 'tools\_cleanup_run.ps1', 'tools\_tidy.ps1') {
    if (Test-Path -LiteralPath $f) { Write-Output "  drop $f" }
}
Remove-Item -LiteralPath 'tools\_cleanup_inventory.ps1', 'tools\_cleanup_run.ps1' -Force -ErrorAction SilentlyContinue

# tmp\ is scratch and should never have been a candidate for commit
$gi = Get-Content -LiteralPath '.gitignore' -Raw
if ($gi -notmatch '(?m)^tmp/') {
    Add-Content -LiteralPath '.gitignore' -Value "`r`n# scratch: staging copies, extracted archives, generated type lists`r`ntmp/"
    Write-Output 'added tmp/ to .gitignore'
}
Write-Output ''
Write-Output 'data\ now holds:'
Get-ChildItem -LiteralPath 'data' -File | ForEach-Object { Write-Output ("  {0,10:N0}  {1}" -f $_.Length, $_.Name) }
