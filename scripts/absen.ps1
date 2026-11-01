<#
==============================================================================
   JAGAT TECH - CLI UTILITY MANAJEMEN SISTEM ABSENSI (WINDOWS)
==============================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$SubCommand = ""
)

$ServerDir = if ($env:JAGAT_SERVER_DIR) { $env:JAGAT_SERVER_DIR } else { "C:\jagat-server" }
$WebDir     = Join-Path $ServerDir "www\web"
$BotWaDir   = Join-Path $ServerDir "www\bot-go"
$BotTeleDir = Join-Path $ServerDir "www\bot-tele"
$WaDir      = Join-Path $ServerDir "www\whatsapp"
$NssmBin    = Join-Path $ServerDir "bin\nssm\nssm.exe"
$PhpBin     = Join-Path $ServerDir "bin\php\php.exe"
$LogDir     = Join-Path $ServerDir "logs"

# Jika php.exe tidak ada di direktori server lokal, gunakan yang ada di PATH
if (-not (Test-Path $PhpBin)) {
    $foundPhp = Get-Command php.exe -ErrorAction SilentlyContinue
    if ($foundPhp) { $PhpBin = $foundPhp.Source }
}

function Write-Color([string]$text, [ConsoleColor]$color = [ConsoleColor]::White) {
    Write-Host $text -ForegroundColor $color
}

function Check-ServiceStatus([string]$displayName, [string]$serviceName) {
    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($null -ne $svc) {
        if ($svc.Status -eq 'Running') {
            Write-Host ("{0,-25} : " -f $displayName) -NoNewline
            Write-Color "[ AKTIF / RUNNING ]" -color Green
        } else {
            Write-Host ("{0,-25} : " -f $displayName) -NoNewline
            Write-Color ("[ MATI / {0} ]" -f $svc.Status) -color Red
        }
    } else {
        $procName = switch ($serviceName) {
            "Jagat-Nginx"    { "nginx" }
            "Jagat-PHP-CGI"  { "php-cgi" }
            "Jagat-WhatsApp" { "whatsapp" }
            "Jagat-BotWA"    { "bot_wa" }
            "Jagat-BotTele"  { "bot_tele" }
            default          { "" }
        }
        if ($procName) {
            $p = Get-Process -Name $procName -ErrorAction SilentlyContinue
            if ($p) {
                Write-Host ("{0,-25} : " -f $displayName) -NoNewline
                Write-Color "[ AKTIF (Process) ]" -color Green
                return
            }
        }
        Write-Host ("{0,-25} : " -f $displayName) -NoNewline
        Write-Color "[ SERVICE TIDAK TERDAFTAR ]" -color Yellow
    }
}

function Show-Header {
    Write-Color "==============================================================" Cyan
    Write-Color "       JAGAT TECH - KONTROL SISTEM SERVER DAN ABSENSI         " Yellow
    Write-Color "==============================================================" Cyan
}

function Test-PortFast([string]$hostname, [int]$port, [int]$timeoutMs = 800) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($hostname, $port, $null, $null)
        $wait = $iar.AsyncWaitHandle.WaitOne($timeoutMs, $false)
        if (-not $wait) {
            $tcp.Close()
            return $false
        }
        $tcp.EndConnect($iar)
        $tcp.Close()
        return $true
    } catch {
        return $false
    }
}

switch ($Command.ToLower()) {
    "status" {
        Show-Header
        Write-Color "`n[ 1. LAYANAN WEB & CORE ENGINE ]" Yellow
        Check-ServiceStatus "Web Server (Nginx)" "Jagat-Nginx"
        Check-ServiceStatus "PHP FastCGI (Port 9000)" "Jagat-PHP-CGI"

        # Cek Database
        Write-Host ("{0,-25} : " -f "Database MySQL/MariaDB") -NoNewline
        if (Test-PortFast "127.0.0.1" 3306) {
            Write-Color "[ AKTIF (Port 3306) ]" -color Green
        } else {
            Write-Color "[ TIDAK DAPAT DIAKSES (Port 3306) ]" -color Red
        }

        Write-Color "`n[ 2. LAYANAN WHATSAPP & TELEGRAM BOT ]" Yellow
        Check-ServiceStatus "WhatsApp Gateway (GOWA)" "Jagat-WhatsApp"
        Check-ServiceStatus "WhatsApp Bot Go (Port 5000)" "Jagat-BotWA"
        Check-ServiceStatus "Telegram Bot Go" "Jagat-BotTele"

        Write-Color "`n[ 3. BACKGROUND WORKER ]" Yellow
        Check-ServiceStatus "Laravel Queue Worker" "Jagat-Queue"
        Check-ServiceStatus "Laravel Scheduler" "Jagat-Scheduler"

        $nginxPort = "80"
        $nginxConf = Join-Path $ServerDir "bin\nginx\conf\nginx.conf"
        if (Test-Path $nginxConf) {
            $confContent = Get-Content $nginxConf -Raw
            if ($confContent -match '(?m)^\s*listen\s+(\d+)\s*;') {
                $nginxPort = $matches[1]
            }
        }
        $webDisplay = if ($nginxPort -eq "80") { "http://localhost" } else { "http://localhost:$nginxPort" }

        Write-Color "`n==============================================================" Cyan
        try {
            $driveLetter = (Split-Path -Path $ServerDir -Qualifier)
            if (-not $driveLetter) { $driveLetter = "C:" }
            $drive = Get-PSDrive ($driveLetter.TrimEnd(':')) -ErrorAction SilentlyContinue
            if ($drive) {
                $usedGb = [math]::Round(($drive.Used / 1GB), 2)
                $freeGb = [math]::Round(($drive.Free / 1GB), 2)
                $totalGb = [math]::Round((($drive.Used + $drive.Free) / 1GB), 2)
                $pct = [math]::Round(($drive.Used / ($drive.Used + $drive.Free) * 100))
                Write-Color ("  - Ruang Disk ({0}) : {1} GB / {2} GB ({3}% terpakai, Sisa: {4} GB)" -f $driveLetter, $usedGb, $totalGb, $pct, $freeGb) White
            }
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) {
                $totRam = [math]::Round($os.TotalVisibleMemorySize / 1024, 0)
                $freeRam = [math]::Round($os.FreePhysicalMemory / 1024, 0)
                $usedRam = $totRam - $freeRam
                Write-Color ("  - Memori (RAM)      : {0} MB / {1} MB" -f $usedRam, $totRam) White
            }
        } catch {}
        Write-Color "==============================================================" Cyan

        Write-Color "`nAlamat Akses:" Yellow
        Write-Color "  - Web Absensi     : $webDisplay" White
        Write-Color "  - WhatsApp Portal : http://localhost:3000" White
        Write-Color "  - Bot Webhook     : http://127.0.0.1:5000/webhook" White
    }

    "start" {
        Show-Header
        Write-Color "`nMenyalakan semua layanan Jagat Tech..." Yellow
        $services = @("Jagat-PHP-CGI", "Jagat-Nginx", "Jagat-WhatsApp", "Jagat-BotWA", "Jagat-BotTele", "Jagat-Queue", "Jagat-Scheduler")
        foreach ($s in $services) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if (-not $svc -and $s -eq "Jagat-WhatsApp") {
                $waExe = Join-Path $ServerDir "www\whatsapp\whatsapp.exe"
                $nssm = Join-Path $ServerDir "bin\nssm\nssm.exe"
                if ((Test-Path $waExe) -and (Test-Path $nssm)) {
                    Write-Host "Mendaftarkan service Jagat-WhatsApp... " -NoNewline
                    & $nssm install Jagat-WhatsApp "$waExe" 2>$null | Out-Null
                    & $nssm set Jagat-WhatsApp AppParameters "rest --port=3001 --basic-auth=admin:JagatTech123@,admin:jagattech --webhook=http://127.0.0.1:5000/webhook" 2>$null | Out-Null
                    & $nssm set Jagat-WhatsApp AppDirectory (Split-Path $waExe) 2>$null | Out-Null
                    & $nssm set Jagat-WhatsApp AppStdout (Join-Path $ServerDir "logs\whatsapp\whatsapp.log") 2>$null | Out-Null
                    & $nssm set Jagat-WhatsApp AppStderr (Join-Path $ServerDir "logs\whatsapp\whatsapp.log") 2>$null | Out-Null
                    & $nssm set Jagat-WhatsApp Start SERVICE_AUTO_START 2>$null | Out-Null
                    & $nssm start Jagat-WhatsApp 2>$null | Out-Null
                    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
                }
            }
            if ($svc) {
                Write-Host "Memulai $s... " -NoNewline
                try {
                    Start-Service -Name $s -ErrorAction Stop
                    Write-Color "[OK]" -color Green
                } catch {
                    if ($svc.Status -eq "Running") {
                        Write-Color "[RUNNING]" -color Green
                    } else {
                        Write-Color ("[GAGAL: " + $_.Exception.Message + "]") -color Red
                    }
                }
            }
        }
        Write-Color "`nSemua layanan telah diinstruksikan untuk menyala." Green
    }

    "stop" {
        Show-Header
        Write-Color "`nMematikan semua layanan Jagat Tech..." Yellow
        $services = @("Jagat-Scheduler", "Jagat-Queue", "Jagat-BotTele", "Jagat-BotWA", "Jagat-WhatsApp", "Jagat-Nginx", "Jagat-PHP-CGI")
        foreach ($s in $services) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                Write-Host "Menghentikan $s... " -NoNewline
                try {
                    Stop-Service -Name $s -Force -ErrorAction Stop
                    Write-Color "[OK]" -color Green
                } catch {
                    Write-Color ("[GAGAL: " + $_.Exception.Message + "]") -color Red
                }
            }
        }
        Write-Color "`nSemua layanan telah dihentikan." Green
    }

    "restart" {
        Show-Header
        Write-Color "`nMe-restart semua layanan Jagat Tech..." Yellow
        $isFromWeb = ($SubCommand -eq "web" -or $SubCommand -eq "--web" -or $Flag -eq "--web" -or $env:JAGAT_WEB_INVOCATION -eq "1" -or $env:HTTP_HOST -or $env:SERVER_SOFTWARE)

        if ($isFromWeb) {
            # Dari Web: Restart background workers, bot, gateway & web server secara aman
            $services = @("Jagat-Queue", "Jagat-Scheduler", "Jagat-WhatsApp", "Jagat-BotWA", "Jagat-BotTele", "Jagat-Nginx")
            foreach ($s in $services) {
                $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
                if ($svc) {
                    Write-Host "Restart $s... " -NoNewline
                    try {
                        Restart-Service -Name $s -Force -ErrorAction Stop
                        Write-Color "[OK]" -color Green
                    } catch {
                        if (Test-Path $NssmBin) {
                            & $NssmBin restart $s 2>$null | Out-Null
                            Write-Color "[OK (via NSSM)]" -color Green
                        } else {
                            Write-Color ("[GAGAL: " + $_.Exception.Message + "]") -color Red
                        }
                    }
                }
            }

            # Khusus PHP: Bersihkan cache framework & opcache agar perubahan kode langsung aktif tanpa memutus koneksi web
            Write-Host "Refresh Cache PHP & Laravel... " -NoNewline
            try {
                if (Test-Path $PhpBin) {
                    & $PhpBin -r "if(function_exists('opcache_reset')){opcache_reset();}" 2>$null
                }
                Push-Location $WebDir
                & $PhpBin artisan optimize:clear 2>$null | Out-Null
                Pop-Location
                Write-Color "[OK]" -color Green
            } catch {
                Write-Color "[OK]" -color Green
            }

            Write-Host "Status Jagat-PHP-CGI... " -NoNewline
            Write-Color "[AKTIF (Koneksi Web Dijaga)]" -color Green
        } else {
            # Dari Terminal CLI (CMD / PowerShell): Boleh me-restart seluruh service termasuk PHP-CGI
            $services = @("Jagat-Queue", "Jagat-Scheduler", "Jagat-WhatsApp", "Jagat-BotWA", "Jagat-BotTele", "Jagat-Nginx", "Jagat-PHP-CGI")
            foreach ($s in $services) {
                $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
                if ($svc) {
                    Write-Host "Restart $s... " -NoNewline
                    try {
                        Restart-Service -Name $s -Force -ErrorAction Stop
                        Write-Color "[OK]" -color Green
                    } catch {
                        if (Test-Path $NssmBin) {
                            & $NssmBin restart $s 2>$null | Out-Null
                            Write-Color "[OK (via NSSM)]" -color Green
                        } else {
                            Write-Color ("[GAGAL: " + $_.Exception.Message + "]") -color Red
                        }
                    }
                }
            }
        }
        Write-Color "`nSemua layanan berhasil di-restart!" Green
    }

    "license" {
        Show-Header
        Write-Color "`n=== SINKRONISASI & VALIDASI LISENSI JAGAT TECH (WINDOWS) ===" Cyan
        if (Test-Path $WebDir) {
            Push-Location $WebDir
            try {
                if (-not (Test-Path (Join-Path $WebDir "storage\app\license_integrity.json"))) {
                    Write-Color "  - File integritas lisensi tidak ditemukan, memulihkan dari paket rilis resmi..." Yellow
                    $relUrl = "https://github.com/kangdaqiq/absen_multi/releases/latest/download/release-client.zip"
                    $relZip = Join-Path $env:TEMP "absen_license_restore.zip"
                    $relExt = Join-Path $env:TEMP "absen_license_restore_ext"
                    Remove-Item -Path $relZip -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $relExt -Recurse -Force -ErrorAction SilentlyContinue
                    Invoke-WebRequest -Uri $relUrl -OutFile $relZip -UseBasicParsing -TimeoutSec 120
                    Expand-Archive -Path $relZip -DestinationPath $relExt -Force
                    $restFiles = @(
                        "storage\app\license_integrity.json",
                        "app\Services\LicenseService.php",
                        "app\Http\Middleware\CheckLicense.php",
                        "app\Http\Middleware\SelfHostedGuard.php"
                    )
                    foreach ($rf in $restFiles) {
                        $srcRf = Join-Path $relExt $rf
                        $dstRf = Join-Path $WebDir $rf
                        if (Test-Path $srcRf) {
                            $dstDir = Split-Path -Path $dstRf
                            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
                            Copy-Item $srcRf $dstRf -Force
                        }
                    }
                    Remove-Item -Path $relZip -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $relExt -Recurse -Force -ErrorAction SilentlyContinue
                }
                Write-Color "  - Memvalidasi lisensi Ed25519 ke server provider..." Yellow
                & $PhpBin artisan license:validate --force
                Write-Color "[OK] Sinkronisasi lisensi selesai!" Green
            } catch {
                Write-Color "Gagal validasi lisensi: $($_.Exception.Message)" Red
            } finally {
                Pop-Location
            }
        } else {
            Write-Color "Direktori $WebDir tidak ditemukan." Red
        }
    }
    "update" {
        Show-Header
        Write-Color "`n=== MEMULAI UPDATE SISTEM ABSENSI JAGAT TECH (WINDOWS) ===" Yellow

        # 1. Update Web Absensi (Git Pull untuk Server Utama vs Release ZIP untuk Klien)
        if (Test-Path $WebDir) {
            Push-Location $WebDir
            try {
                $appMode = ""
                $envPath = Join-Path $WebDir ".env"
                if (Test-Path $envPath) {
                    $envLines = Get-Content $envPath
                    foreach ($line in $envLines) {
                        if ($line -match '^\s*APP_MODE\s*=\s*(.*)$') {
                            $appMode = $matches[1].Trim().Trim('"').Trim("'").ToLower()
                            break
                        }
                    }
                }

                if ($appMode -eq "hosted") {
                    Write-Color "`n[1/3] Server Utama terdeteksi (APP_MODE=hosted). Memperbarui Web Absensi via Git Pull..." Cyan
                    git config --global --add safe.directory $WebDir 2>$null
                    if (Test-Path (Join-Path $WebDir ".git")) {
                        git fetch --all --prune
                        git pull origin main
                        Write-Color "  ✔ Source code Web Absensi berhasil diperbarui via Git Pull!" Green
                    } else {
                        Write-Color "  - Inisialisasi repositori Git resmi..." Yellow
                        git init
                        git remote add origin https://github.com/kangdaqiq/absen_multi.git 2>$null
                        git fetch origin main
                        git reset --hard origin/main
                        Write-Color "  ✔ Repositori Git berhasil dihubungkan & diperbarui!" Green
                    }
                } else {
                    Write-Color "`n[1/3] Server Klien terdeteksi ($appMode). Mengunduh rilis resmi Web Absensi (release-client.zip)..." Cyan
                    $webRelUrl = "https://github.com/kangdaqiq/absen_multi/releases/latest/download/release-client.zip"
                    $webRelZip = Join-Path $env:TEMP "absen_update_client.zip"
                    $envBackup = Join-Path $env:TEMP "absen_env_update_backup"
                    $licBackup = Join-Path $env:TEMP "absen_lic_update_backup.json"

                    Remove-Item -Path $webRelZip -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $envBackup -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $licBackup -Force -ErrorAction SilentlyContinue

                    if (Test-Path (Join-Path $WebDir ".env")) {
                        Copy-Item (Join-Path $WebDir ".env") $envBackup -Force
                    }
                    if (Test-Path (Join-Path $WebDir "storage\app\license_cache.json")) {
                        Copy-Item (Join-Path $WebDir "storage\app\license_cache.json") $licBackup -Force
                    }

                    Invoke-WebRequest -Uri $webRelUrl -OutFile $webRelZip -UseBasicParsing -TimeoutSec 300
                    if (Test-Path $webRelZip) {
                        Write-Color "  - Mengekstrak paket rilis Web Absensi..." Yellow
                        if (Test-Path (Join-Path $WebDir ".git")) {
                            Remove-Item -Path (Join-Path $WebDir ".git") -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        Expand-Archive -Path $webRelZip -DestinationPath $WebDir -Force
                        Remove-Item -Path $webRelZip -Force -ErrorAction SilentlyContinue
                    }

                    if (Test-Path $envBackup) {
                        Copy-Item $envBackup (Join-Path $WebDir ".env") -Force
                        Remove-Item -Path $envBackup -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path $licBackup) {
                        $stApp = Join-Path $WebDir "storage\app"
                        if (-not (Test-Path $stApp)) { New-Item -ItemType Directory -Path $stApp -Force | Out-Null }
                        Copy-Item $licBackup (Join-Path $stApp "license_cache.json") -Force
                        Remove-Item -Path $licBackup -Force -ErrorAction SilentlyContinue
                    }
                    Write-Color "  ✔ Paket rilis Web Absensi berhasil diperbarui!" Green
                }

                Write-Color "  - Memperbarui dependensi PHP (composer install)..." Yellow
                composer install --no-dev --optimize-autoloader --no-interaction
                
                Write-Color "  - Menjalankan migrasi database..." Yellow
                & $PhpBin artisan migrate --force
                
                Write-Color "  - Membersihkan dan mengoptimalkan cache Laravel..." Yellow
                & $PhpBin artisan storage:link --force
                & $PhpBin artisan optimize:clear
                & $PhpBin artisan optimize
                & $PhpBin artisan license:validate --force 2>$null

                Write-Color "  - Me-restart antrian background (queue worker & scheduler)..." Yellow
                Restart-Service -Name "Jagat-Queue" -ErrorAction SilentlyContinue
                Restart-Service -Name "Jagat-Scheduler" -ErrorAction SilentlyContinue
            } finally {
                Pop-Location
            }
        }

        # 2. Update Bot WhatsApp Go
        if (Test-Path $BotWaDir) {
            Write-Color "`n[2/3] Memperbarui binary WhatsApp Bot Go..." Cyan
            $botWaUrl = "https://github.com/kangdaqiq/bot-go/releases/latest/download/bot-windows-amd64.zip"
            $tempZip = Join-Path $env:TEMP "bot_wa_win.zip"
            $tempDir = Join-Path $env:TEMP "bot_wa_win_extract"
            if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                Invoke-WebRequest -Uri $botWaUrl -OutFile $tempZip -UseBasicParsing
                Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
                $newExe = Get-ChildItem -Path $tempDir -Filter "bot_wa*.exe" -Recurse | Select-Object -First 1
                if ($newExe) {
                    Stop-Service -Name "Jagat-BotWA" -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    Copy-Item -Path $newExe.FullName -Destination (Join-Path $BotWaDir "bot_wa.exe") -Force
                    Start-Service -Name "Jagat-BotWA" -ErrorAction SilentlyContinue
                    Write-Color "  - Bot WhatsApp Go berhasil diperbarui." Green
                }
            } catch {
                Write-Color ("  - Gagal memperbarui Bot WA: " + $_.Exception.Message) Red
            } finally {
                Remove-Item -Path $tempZip -ErrorAction SilentlyContinue
                Remove-Item -Path $tempDir -Recurse -ErrorAction SilentlyContinue
            }
        }

        # 3. Update Bot Telegram Go
        if (Test-Path $BotTeleDir) {
            Write-Color "`n[3/3] Memperbarui binary Telegram Bot Go..." Cyan
            $botTeleUrl = "https://github.com/kangdaqiq/bot_tele/releases/latest/download/bot_tele-windows-amd64.zip"
            $tempZip = Join-Path $env:TEMP "bot_tele_win.zip"
            $tempDir = Join-Path $env:TEMP "bot_tele_win_extract"
            if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                Invoke-WebRequest -Uri $botTeleUrl -OutFile $tempZip -UseBasicParsing
                Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
                $newExe = Get-ChildItem -Path $tempDir -Filter "bot_tele*.exe" -Recurse | Select-Object -First 1
                if ($newExe) {
                    Stop-Service -Name "Jagat-BotTele" -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    Copy-Item -Path $newExe.FullName -Destination (Join-Path $BotTeleDir "bot_tele.exe") -Force
                    Start-Service -Name "Jagat-BotTele" -ErrorAction SilentlyContinue
                    Write-Color "  - Bot Telegram Go berhasil diperbarui." Green
                }
            } catch {
                Write-Color ("  - Gagal memperbarui Bot Telegram: " + $_.Exception.Message) Red
            } finally {
                Remove-Item -Path $tempZip -ErrorAction SilentlyContinue
                Remove-Item -Path $tempDir -Recurse -ErrorAction SilentlyContinue
            }
        }

        Write-Color "`nUpdate selesai! Seluruh komponen telah diperbarui." Green
    }

    "logs" {
        $logFile = switch ($SubCommand.ToLower()) {
            "queue"     { Join-Path $LogDir "queue\queue.log" }
            "scheduler" { Join-Path $LogDir "scheduler\scheduler.log" }
            "bot"       { Join-Path $LogDir "bot_wa\bot_wa.log" }
            "tele"      { Join-Path $LogDir "bot_tele\bot_tele.log" }
            "wa"        { Join-Path $LogDir "whatsapp\whatsapp.log" }
            "nginx"     { Join-Path $LogDir "nginx\error.log" }
            default     { Join-Path $WebDir "storage\logs\laravel.log" }
        }

        if (Test-Path $logFile) {
            Write-Color ("Memantau log: " + $logFile + " (Tekan Ctrl+C untuk keluar)`n") Cyan
            Get-Content -Path $logFile -Tail 40 -Wait
        } else {
            Write-Color ("File log belum tersedia: " + $logFile) Yellow
        }
    }

    "backup" {
        Show-Header
        Write-Color "`n=== MEMULAI BACKUP SISTEM ABSENSI (WINDOWS) ===" Yellow
        $backupDir = Join-Path $ServerDir "backups"
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")

        # 1. Backup Storage Web
        $storageDir = Join-Path $WebDir "storage\app"
        if (Test-Path $storageDir) {
            Write-Color "[1/2] Membackup direktori file upload storage..." Cyan
            $zipStorage = Join-Path $backupDir "storage_$timestamp.zip"
            try {
                Compress-Archive -Path $storageDir -DestinationPath $zipStorage -Force
                Write-Color "  - Storage tersimpan: $zipStorage" Green
            } catch {
                Write-Color ("  - Gagal membackup storage: " + $_.Exception.Message) Red
            }
        }

        # 2. Backup Database
        $mysqldump = Get-Command mysqldump.exe -ErrorAction SilentlyContinue
        if (-not $mysqldump) {
            $candidateDump = Get-ChildItem -Path "C:\Program Files\MariaDB*", "C:\Program Files\MySQL*", "C:\Program Files (x86)\MariaDB*", "C:\Program Files (x86)\MySQL*", "C:\xampp\mysql\bin" -Filter "mysqldump.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($candidateDump) { $mysqldump = $candidateDump.FullName }
        }

        if ($mysqldump) {
            Write-Color "[2/2] Membackup database database MariaDB/MySQL..." Cyan
            $sqlFile = Join-Path $backupDir "db_absen_$timestamp.sql"
            try {
                & $mysqldump -h 127.0.0.1 -u absen_user -pJagatTech123@ absen_jagat --result-file="$sqlFile" 2>$null
                if ((Test-Path $sqlFile) -and (Get-Item $sqlFile).Length -gt 0) {
                    Write-Color "  - Database SQL tersimpan: $sqlFile" Green
                } else {
                    & $mysqldump -h 127.0.0.1 -u root --all-databases --result-file="$sqlFile" 2>$null
                    Write-Color "  - Database SQL tersimpan: $sqlFile" Green
                }
            } catch {
                Write-Color ("  - Gagal backup dump database: " + $_.Exception.Message) Red
            }
        } else {
            Write-Color "[2/2] Client mysqldump.exe tidak ditemukan di PATH, backup database dilewati." Yellow
        }

        Write-Color "`nBackup selesai! Direktori penyimpanan: $backupDir" Green
    }

    "qr" {
        Write-Color "Membuka halaman Portal WhatsApp Gateway di browser..." Cyan
        Start-Process "http://localhost:3000"
    }

    default {
        Show-Header
        Write-Host "Penggunaan: absen [perintah]"
        Write-Host ""
        Write-Host "Perintah yang tersedia:"
        Write-Color "  absen status      " Green -NoNewline; Write-Host " - Cek status Web, Nginx, MariaDB, WA, Bot dan Queue"
        Write-Color "  absen start       " Green -NoNewline; Write-Host " - Menyalakan seluruh service"
        Write-Color "  absen stop        " Green -NoNewline; Write-Host " - Menghentikan seluruh service"
        Write-Color "  absen restart     " Green -NoNewline; Write-Host " - Me-restart seluruh service"
        Write-Color "  absen update      " Green -NoNewline; Write-Host " - Update Git Web Absensi dan download binary bot terbaru"
        Write-Color "  absen backup      " Green -NoNewline; Write-Host " - Backup database MySQL dan folder storage file"
        Write-Color "  absen qr          " Green -NoNewline; Write-Host " - Buka portal WhatsApp untuk scan QR code"
        Write-Color "  absen logs        " Green -NoNewline; Write-Host " - Pantau log Laravel realtime"
        Write-Color "  absen logs bot    " Green -NoNewline; Write-Host " - Pantau log WhatsApp Bot Go"
        Write-Color "  absen logs tele   " Green -NoNewline; Write-Host " - Pantau log Telegram Bot Go"
        Write-Color "  absen logs wa        " Green -NoNewline; Write-Host " - Pantau log WhatsApp Gateway"
        Write-Color "  absen logs queue     " Green -NoNewline; Write-Host " - Pantau log Laravel Queue Worker"
        Write-Color "  absen logs scheduler " Green -NoNewline; Write-Host " - Pantau log Laravel Scheduler"
        Write-Color "  absen logs nginx     " Green -NoNewline; Write-Host " - Pantau log error Nginx"
        Write-Host ""
    }
}
