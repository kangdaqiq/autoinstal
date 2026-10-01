@echo off
setlocal
title JAGAT TECH - Auto Installer WSL2 (Windows)

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [INFO] Meminta hak Administrator...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-wsl.ps1" %*
pause
