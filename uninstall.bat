@echo off
setlocal
title JAGAT TECH - Uninstaller Windows

:: Periksa Administrator Privilege
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [INFO] Meminta hak Administrator untuk proses uninstalasi...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo ==============================================================
echo   JAGAT TECH - UNINSTALLER WINDOWS SERVER & ABSENSI
echo ==============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall-windows.ps1" %*

echo.
pause
