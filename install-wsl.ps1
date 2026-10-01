<#
==============================================================================
   JAGAT TECH - AUTO INSTALLER WSL2 (WINDOWS SUBSYSTEM FOR LINUX)
   Menjalankan 100% Native Linux Stack di Windows secara terisolasi & berkinerja tinggi
==============================================================================
#>

[CmdletBinding()]
param(
    [string]$Distro = "Ubuntu"
)

# Periksa Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Meminta hak Administrator (UAC)..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"")
    Exit
}

Clear-Host
Write-Host @"
==============================================================================
   JAGAT TECH - AUTO INSTALLER WSL2 (UBUNTU / DEBIAN DI WINDOWS)
==============================================================================
 Rekomendasi terbaik jika Anda menginginkan stabilitas 100% Linux Server
 (Nginx + PHP8.3-FPM Socket + Supervisor Queue + Systemd) di dalam Windows!
==============================================================================
"@ -ForegroundColor Cyan

# 1. Periksa ketersediaan WSL
Write-Host "`n[1/4] Memeriksa Windows Subsystem for Linux (WSL2)..." -ForegroundColor Blue
$wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wslCmd) {
    Write-Host "WSL belum aktif di sistem Windows Anda." -ForegroundColor Yellow
    Write-Host "Mengaktifkan fitur WSL dan mengunduh distro $Distro..." -ForegroundColor Cyan
    wsl --install -d $Distro
    Write-Host "`n[PENTING] Silakan restart komputer Anda jika diminta oleh Windows, lalu jalankan kembali skrip ini." -ForegroundColor Red
    pause
    Exit
}

# 2. Cek apakah distro terpasang
$distroList = wsl -l -q 2>$null | ForEach-Object { $_.Trim().Replace("`0","") }
$hasDistro = $distroList -contains $Distro

if (-not $hasDistro) {
    Write-Host "Distro $Distro belum terpasang. Memasang $Distro..." -ForegroundColor Yellow
    wsl --install -d $Distro
}

Write-Host "WSL dan $Distro siap digunakan!" -ForegroundColor Green

# 3. Jalankan Auto Installer di dalam WSL Ubuntu
Write-Host "`n[2/4] Menjalankan Auto Installer JAGAT TECH di dalam $Distro..." -ForegroundColor Blue
$currentDir = Split-Path -Path $MyInvocation.MyCommand.Path
$localInstallSh = Join-Path $currentDir "install.sh"

if (Test-Path $localInstallSh) {
    # Konversi path Windows ke path WSL
    $wslPath = (wsl -d $Distro -u root wslpath -u ($localInstallSh.Replace('\', '/'))).Trim()
    Write-Host "Menjalankan file installer lokal: $wslPath" -ForegroundColor Cyan
    wsl -d $Distro -u root -- bash -c "sed -i 's/\r$//' '$wslPath' && bash '$wslPath'"
} else {
    Write-Host "Mengunduh dan menjalankan quick-install..." -ForegroundColor Cyan
    wsl -d $Distro -u root -- bash -c "curl -sSL 'https://raw.githubusercontent.com/kangdaqiq/autoinstal/main/quick-install.sh' | bash"
}

# 4. Pengaturan Port Forwarding (PortProxy) Windows -> WSL
Write-Host "`n[3/4] Mengonfigurasi Port Forwarding (PortProxy) ke Windows..." -ForegroundColor Blue
$wslIp = (wsl -d $Distro -u root -- hostname -I).Trim().Split(" ")[0]
Write-Host "IP Internal WSL: $wslIp" -ForegroundColor Cyan

$ports = @(80, 3000, 5000)
foreach ($p in $ports) {
    netsh interface portproxy delete v4tov4 listenport=$p listenaddress=0.0.0.0 2>$null | Out-Null
    netsh interface portproxy add v4tov4 listenport=$p listenaddress=0.0.0.0 connectport=$p connectaddress=$wslIp
    Write-Host "  ✔ Port $p diteruskan dari Windows Host -> WSL (${wslIp}:$p)" -ForegroundColor Green
}

# 5. Buat Desktop Shortcuts
Write-Host "`n[4/4] Membuat Shortcut Desktop..." -ForegroundColor Blue
$wshShell = New-Object -ComObject WScript.Shell
$desktopPath = [Environment]::GetFolderPath("Desktop")

$scWeb = $wshShell.CreateShortcut((Join-Path $desktopPath "Web Absensi JAGAT TECH (WSL).url"))
$scWeb.TargetPath = "http://localhost"
$scWeb.Save()

$scWa = $wshShell.CreateShortcut((Join-Path $desktopPath "WhatsApp Gateway Portal (WSL).url"))
$scWa.TargetPath = "http://localhost:3000"
$scWa.Save()

Write-Host @"

==============================================================================
 🎉 INSTALASI SERVER JAGAT TECH PADA WSL2 SELESAI!
==============================================================================
 Akses Web Absensi : http://localhost atau http://IP_WINDOWS_ANDA
 WhatsApp Portal   : http://localhost:3000
 Terminal WSL      : wsl -d $Distro -u root
==============================================================================
"@ -ForegroundColor Green
