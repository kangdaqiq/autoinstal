@echo off
setlocal
set "SCRIPT_PATH=%~dp0absen.ps1"
if not exist "%SCRIPT_PATH%" if defined JAGAT_SERVER_DIR set "SCRIPT_PATH=%JAGAT_SERVER_DIR%\scripts\absen.ps1"
if not exist "%SCRIPT_PATH%" set "SCRIPT_PATH=C:\jagat-server\scripts\absen.ps1"

if not exist "%SCRIPT_PATH%" (
    echo [ERROR] File absen.ps1 tidak ditemukan di %SCRIPT_PATH%
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %*
