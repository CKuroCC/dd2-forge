@echo off
cd /d D:\dd2-forge
node --check assets\app.js && echo JS_SYNTAX_OK
if exist _cleanup.bat del _cleanup.bat
if exist _final.bat (echo skip)
git add -A
git commit -q -m "tidy helper scripts"
git push -q
git log --oneline -1
