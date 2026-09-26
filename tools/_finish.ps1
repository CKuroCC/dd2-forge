Set-Location 'D:\dd2-forge'
Write-Output '=== live powershell (is deploy still up?) ==='
Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object { "  pid {0} started {1} cpu {2}" -f $_.Id, $_.StartTime.ToString('HH:mm:ss'), [math]::Round($_.CPU,1) }
Write-Output ''
Write-Output '=== git status before ==='
git status --short | Select-Object -First 20
Write-Output ''
Write-Output '=== staging + committing directly ==='
git add -A 2>&1 | Out-String
$staged = (git diff --cached --name-only) -join ', '
Write-Output ("staged: {0}" -f $staged)
if ($staged) {
  git -c core.editor=true commit -q -m 'restore 3ng3_dcp (wrongly retired), add mod-health-check + inventory, refresh suite' 2>&1 | Out-String
  git log --oneline -1
  Write-Output ''
  Write-Output '=== pushing ==='
  $p = git push 2>&1 | Out-String
  Write-Output $p
  Write-Output ("push exit: {0}" -f $LASTEXITCODE)
} else { Write-Output 'nothing staged' }
Write-Output ''
git log --oneline -2
git status --short | Select-Object -First 5
Remove-Item 'D:\dd2-forge\tools\_finish.ps1' -Force
