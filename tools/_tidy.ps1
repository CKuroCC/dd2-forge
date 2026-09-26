Set-Location 'D:\dd2-forge'
Remove-Item 'D:\dd2-forge\tools\_deploy.log' -Force -ErrorAction SilentlyContinue
$ErrorActionPreference = 'Continue'
git add -A 2>&1 | Out-Null
$staged = (git diff --cached --name-only) -join ', '
Write-Output ("staged: {0}" -f $staged)
git commit -q -m 'deploy: git stderr no longer kills the run at commit/push' 2>&1 | Out-String | Write-Output
git push 2>&1 | Out-String | Write-Output
Write-Output ("push exit {0}" -f $LASTEXITCODE)
git log --oneline -2 2>&1 | Out-String | Write-Output
Write-Output '--- clean? ---'
$s = git status --short
if ($s) { $s } else { Write-Output '  working tree clean' }
Remove-Item 'D:\dd2-forge\tools\_tidy.ps1' -Force
