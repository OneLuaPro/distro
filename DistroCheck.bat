@echo off
pushd "%~dp0"
start "" wlua.exe "%~dp0DistroCheck.lua" %*
popd
exit