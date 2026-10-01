<#
==============================================================================
   ██╗ █████╗  ██████╗  █████╗ ████████╗    ████████╗███████╗ ██████╗██╗  ██╗
   ██║██╔══██╗██╔════╝ ██╔══██╗╚══██╔══╝    ╚══██╔══╝██╔════╝██╔════╝██║  ██║
   ██║███████║██║  ███╗███████║   ██║          ██║   █████╗  ██║     ███████║
   ██║██╔══██║██║   ██║██╔══██║   ██║          ██║   ██╔══╝  ██║     ██╔══██║
   ███║██║  ██║╚██████╔╝██║  ██║   ██║          ██║   ███████╗╚██████╗██║  ██║
   ╚══╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝          ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝
==============================================================================
   UNINSTALLER JAGAT TECH FOR WINDOWS (NATIVE POWERSHELL)
   Membersihkan seluruh Stack Layanan, Nginx, PHP FastCGI, Bot, & Shortcut
==============================================================================
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "C:\jagat-server",
    [string]$DbHost = "127.0.0.1",
    [string]$DbPort = "3306",
    [string]$DbName = "absen_jagat",
    [string]$DbUser = "absen_user",
    [switch]$DeleteDatabase,
    [switch]$Force,
    [switch]$NonInteractive
)

# -----------------------------------------------------------------------------
# 1. Pengecekan Hak Administrator (Self-Elevation)
# -----------------------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Meminta hak Administrator (UAC)..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    if ($Force) { $argList += " -Force" }
    if ($NonInteractive) { $argList += " -NonInteractive" }
    if ($DeleteDatabase) { $argList += " -DeleteDatabase" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    Exit
}

$Host.UI.RawUI.WindowTitle = "JAGAT TECH - Uninstaller Windows Server & Absensi"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# -----------------------------------------------------------------------------
# 2. Helper Output & UI
# -----------------------------------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host @"
==============================================================================
   ██╗ █████╗  ██████╗  █████╗ ████████╗    ████████╗███████╗ ██████╗██╗  ██╗
   ██║██╔══██╗██╔════╝ ██╔══██╗╚══██╔══╝    ╚══██╔══╝██╔════╝██╔════╝██║  ██║
   ██║███████║██║  ███╗███████║   ██║          ██║   █████╗  ██║     ███████║
   ██║██╔══██║██║   ██║██╔══██║   ██║          ██║   ██╔══╝  ██║     ██╔══██║
   ███║██║  ██║╚██████╔╝██║  ██║   ██║          ██║   ███████╗╚██████╗██║  ██║
   ╚══╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝          ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝
==============================================================================
   UNINSTALLER SERVER, WEB ABSENSI & BOT SERVICES (WINDOWS NATIVE)
   Provider : JAGAT TECH
==============================================================================
"@ -ForegroundColor Yellow
}

function Log-Step([string]$msg) {
    Write-Host "`n▶ $msg" -ForegroundColor Cyan
}

function Log-Info([string]$msg) {
    Write-Host " ℹ $msg" -ForegroundColor White
}

function Log-Success([string]$msg) {
    Write-Host " ✔ $msg" -ForegroundColor Green
}

function Log-Warn([string]$msg) {
    Write-Host " ⚠ $msg" -ForegroundColor Yellow
}

function Log-Error([string]$msg) {
    Write-Host " ✖ $msg" -ForegroundColor Red
}

Write-Header

# Deteksi apakah folder instalasi kustom ada di variabel sistem
if ($env:JAGAT_SERVER_DIR -and (Test-Path $env:JAGAT_SERVER_DIR)) {
    $InstallDir = $env:JAGAT_SERVER_DIR
}

# -----------------------------------------------------------------------------
# 3. Konfirmasi Pengguna
# -----------------------------------------------------------------------------
if (-not $Force -and -not $NonInteractive) {
    Write-Host ""
    Write-Host "PERINGATAN: Tindakan ini akan menghapus seluruh instalasi JAGAT TECH:" -ForegroundColor Yellow
    Write-Host " - Seluruh Background Service (PHP FastCGI, Nginx, Queue, WA Gateway, Bot)" -ForegroundColor White
    Write-Host " - Desktop Shortcuts dan CLI 'absen'" -ForegroundColor White
    Write-Host " - Direktori Server: $InstallDir" -ForegroundColor White
    Write-Host ""
    
    $confirm = Read-Host "Apakah Anda yakin ingin melanjutkan proses uninstalasi? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Proses uninstalasi dibatalkan oleh pengguna." -ForegroundColor Gray
        Exit
    }

    if (-not $DeleteDatabase) {
        Write-Host ""
        $confirmDb = Read-Host "Apakah Anda ingin MENGHAPUS database '$DbName' & user '$DbUser'? (y/N)"
        if ($confirmDb -eq 'y' -or $confirmDb -eq 'Y') {
            $DeleteDatabase = $true
        }
    }
}

# -----------------------------------------------------------------------------
# 4. Hentikan & Hapus Background Services Windows (NSSM)
# -----------------------------------------------------------------------------
Log-Step "[1/6] Menghentikan & Menghapus Background Services Windows..."

$services = @(
    "Jagat-Queue",
    "Jagat-BotTele",
    "Jagat-BotWA",
    "Jagat-WhatsApp",
    "Jagat-Nginx",
    "Jagat-PHP-CGI"
)

$nssmExe = Join-Path $InstallDir "bin\nssm\nssm.exe"

foreach ($s in $services) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc -or (Test-Path $nssmExe)) {
        Log-Info "Menghapus service: $s..."
        if (Test-Path $nssmExe) {
            & $nssmExe stop $s 2>$null | Out-Null
            & $nssmExe remove $s confirm 2>$null | Out-Null
        }
        # Fallback sc.exe jika masih tersisa
        $svcCheck = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svcCheck) {
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            & sc.exe delete $s 2>$null | Out-Null
        }
        Log-Success "Service $s berhasil dihapus."
    }
}

# -----------------------------------------------------------------------------
# 5. Hentikan Sisa Proses yang Masih Mengunci File
# -----------------------------------------------------------------------------
Log-Step "[2/6] Memeriksa & Menghentikan Proses yang Masih Aktif..."

$processNames = @("nginx", "php-cgi", "whatsapp", "bot_wa", "bot_tele")
foreach ($p in $processNames) {
    $procs = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($procs) {
        Log-Info "Menghentikan sisa proses '$p'..."
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 2
Log-Success "Seluruh proses terkait telah dihentikan."

# -----------------------------------------------------------------------------
# 6. Bersihkan Desktop Shortcuts & CLI Global
# -----------------------------------------------------------------------------
Log-Step "[3/6] Menghapus Shortcuts Desktop & Command Prompt System..."

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcuts = @(
    (Join-Path $desktopPath "Web Absensi JAGAT TECH.url"),
    (Join-Path $desktopPath "WhatsApp Gateway Portal.url"),
    (Join-Path $desktopPath "Jagat Server Control (CLI).lnk")
)

foreach ($sc in $shortcuts) {
    if (Test-Path $sc) {
        Remove-Item -Path $sc -Force -ErrorAction SilentlyContinue
        Log-Success "Shortcut dihapus: $(Split-Path $sc -Leaf)"
    }
}

# Hapus absen.cmd dari System32 jika ada
$sys32Absen = "C:\Windows\System32\absen.cmd"
if (Test-Path $sys32Absen) {
    Remove-Item -Path $sys32Absen -Force -ErrorAction SilentlyContinue
    Log-Success "CLI global dihapus: $sys32Absen"
}

# -----------------------------------------------------------------------------
# 7. Bersihkan Environment PATH & Variabel Sistem
# -----------------------------------------------------------------------------
Log-Step "[4/6] Membersihkan System Environment Variables..."

$scriptsDir = Join-Path $InstallDir "scripts"
$phpDir     = Join-Path $InstallDir "bin\php"

$currentMachinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
if ($currentMachinePath) {
    $pathParts = $currentMachinePath.Split(';') | Where-Object { 
        $_ -ne "" -and 
        $_ -ne $scriptsDir -and 
        $_ -ne $phpDir -and
        $_ -notlike "*$InstallDir*"
    }
    $newMachinePath = ($pathParts -join ";")
    [Environment]::SetEnvironmentVariable("PATH", $newMachinePath, "Machine")
    Log-Success "Path direktori server dihapus dari Machine PATH."
}

# Hapus JAGAT_SERVER_DIR
[Environment]::SetEnvironmentVariable("JAGAT_SERVER_DIR", $null, "Machine")
[Environment]::SetEnvironmentVariable("JAGAT_SERVER_DIR", $null, "Process")
Log-Success "Variabel JAGAT_SERVER_DIR telah dihapus."

# -----------------------------------------------------------------------------
# 8. Hapus Database & User (Opsional)
# -----------------------------------------------------------------------------
if ($DeleteDatabase) {
    Log-Step "[5/6] Menghapus Database '$DbName' & User '$DbUser'..."
    
    $mysqlCli = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if (-not $mysqlCli) {
        $commonCliPaths = @(
            "C:\xampp\mysql\bin\mysql.exe",
            "C:\Program Files\MariaDB 11.4\bin\mysql.exe",
            "C:\Program Files\MariaDB 10.11\bin\mysql.exe",
            "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
        )
        foreach ($cp in $commonCliPaths) {
            if (Test-Path $cp) {
                $mysqlCli = [PSCustomObject]@{ Source = $cp }
                break
            }
        }
    }

    if ($mysqlCli) {
        $dropScript = @"
DROP DATABASE IF EXISTS $DbName;
DROP USER IF EXISTS '$DbUser'@'localhost';
DROP USER IF EXISTS '$DbUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
        $tempSql = Join-Path $env:TEMP "drop_jagat_db.sql"
        Set-Content -Path $tempSql -Value $dropScript -Force
        Get-Content -Path $tempSql | & $mysqlCli.Source -h $DbHost -P $DbPort -u root 2>$null
        Remove-Item -Path $tempSql -Force -ErrorAction SilentlyContinue
        Log-Success "Database $DbName dan user $DbUser berhasil dihapus."
    } else {
        Log-Warn "Client MySQL tidak ditemukan. Silakan hapus database '$DbName' secara manual via phpMyAdmin / HeidiSQL."
    }
} else {
    Log-Step "[5/6] Database '$DbName' dipertahankan (data aman jika ingin reinstall)."
}

# -----------------------------------------------------------------------------
# 9. Menghapus Direktori Instalasi Server
# -----------------------------------------------------------------------------
Log-Step "[6/6] Menghapus Direktori Instalasi $InstallDir..."

if (Test-Path $InstallDir) {
    try {
        # Hapus junction jika masih ada
        $botWaJunction = Join-Path $InstallDir "www\bot-wa"
        if (Test-Path $botWaJunction) {
            try { (Get-Item $botWaJunction).Delete() } catch {}
        }

        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction Stop
        Log-Success "Direktori $InstallDir berhasil dihapus sepenuhnya."
    } catch {
        Log-Warn "Sebagian file di $InstallDir masih terkunci oleh sistem: $($_.Exception.Message)"
        Log-Info "Mencoba pembersihan ulang setelah jeda 2 detik..."
        Start-Sleep -Seconds 2
        try {
            Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
            Log-Success "Direktori $InstallDir berhasil dihapus."
        } catch {
            Log-Warn "Silakan hapus sisa folder '$InstallDir' secara manual setelah me-restart komputer."
        }
    }
} else {
    Log-Info "Direktori $InstallDir tidak ditemukan (sudah terhapus sebelumnya)."
}

# -----------------------------------------------------------------------------
# 10. Ringkasan Selesai
# -----------------------------------------------------------------------------
Write-Host @"

==============================================================================
 🎉 UNINSTALASI JAGAT TECH SELESAI DENGAN SUKSES!
==============================================================================
 Seluruh layanan server, Nginx, PHP FastCGI, Bot, shortcut, dan file
 instalasi JAGAT TECH telah berhasil dibersihkan dari komputer Anda.

 Komputer Anda kini bersih dan siap jika sewaktu-waktu ingin di-install ulang.
==============================================================================
"@ -ForegroundColor Green
