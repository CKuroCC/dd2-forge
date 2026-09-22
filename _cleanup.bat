@echo off
cd /d D:\dd2-forge
git config user.name "Julian Waits II"
git config user.email "kuroninja@ckuro.cc"
if exist _push.bat del _push.bat
git add -A
git commit -q -m "remove push helper"
git push -q
git log --oneline -2
