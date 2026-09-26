$ErrorActionPreference = 'Continue'
Set-Location 'D:\dd2-forge'
$s = git status --short
if ($s) {
  Write-Output 'tidying leftovers:'; $s
  git add -A 2>&1 | Out-Null
  git commit -q -m 'tools: drop the one-off helper scripts' 2>&1 | Out-String | Write-Output
  git push 2>&1 | Out-String | Write-Output
}
Write-Output '--- final ---'
git log --oneline -1 2>&1 | Out-String | Write-Output
$s2 = git status --short
if ($s2) { $s2 } else { Write-Output 'working tree clean' }

# field notes
$p = 'C:\Users\Burori\Documents\WEKA-Hub\DD2-MODDING-FIELD-NOTES.md'
$t = @'

### §11b — Pak Bridge is live, and a PowerShell trap that killed the deploy twice (2026-09-26)

[source: live logs + two failed deploy runs, 2026-09-26, sensitivity: internal]

**DOCUMENTED FACT — Pak Bridge works.** v1.1.0 installed via Fluffy; REFramework nightly
(v1.5.9.1 +507, build 2026-09-16) satisfies its only real requirement. From 16:15 the log
carries lines of the exact shape:
  [Plugin] [PakBridge] redirect natives/.../body_820_f_ALB.tex.251211553 -> old suffix 760230703
which is the TU3.2 file-ID remap working in real time. It also patched MeshModEnabler in place
and kept the original as MeshModEnabler.lua.pakbridge-original (21,759 bytes). Its manifest
lists the files it converted. `trace=ch310002,3050,body_mat` is now set in DD2PakBridge.ini so
Wilhelmina's own assets get logged by name on the next boot.

**DOCUMENTED FACT — the deploy trap. `git` writes ordinary progress to STDERR.**
"warning: LF will be replaced by CRLF" and "To https://github.com/..." are both stderr, on
SUCCESSFUL commands. deploy.ps1 sets `$ErrorActionPreference = 'Stop'`, which turns any native
stderr line into a TERMINATING NativeCommandError. Run in a visible console it looked fine;
run detached with -WindowStyle Hidden it died at "=== 6. commit" and the log simply stopped,
twice, with no error anywhere. **Git's verdict is $LASTEXITCODE and never stderr.** Steps 6 and 7
now suspend the preference around the git calls and restore it in a `finally`.

**Second trap, same session.** deploy.ps1 takes a MANDATORY -Message. Launched detached without
it, PowerShell sat at an invisible Read-Host prompt forever. A detached launch of any script with
a mandatory parameter is a hang waiting to happen -- pass every mandatory parameter explicitly,
and if a detached run produces no output for a minute, suspect a prompt before suspecting the work.
'@
Add-Content -Path $p -Value $t -Encoding UTF8
Write-Output ("appended {0} chars to field notes" -f $t.Length)
Remove-Item 'D:\dd2-forge\tools\_final.ps1' -Force
