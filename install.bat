@echo off
setlocal
title JAGAT TECH - Auto Installer Windows

:: Periksa Administrator Privilege
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [INFO] Meminta hak Administrator untuk instalasi...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo ==============================================================
echo   JAGAT TECH - MEMULAI AUTO INSTALLER UNTUK WINDOWS
echo ==============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-windows.ps1" %*

echo.
pause
