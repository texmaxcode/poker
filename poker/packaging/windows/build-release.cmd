@echo off
setlocal
REM Thin wrapper for developers who prefer cmd.exe
cd /d "%~dp0..\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-release.ps1" %*
