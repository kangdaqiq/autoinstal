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
        Write-Color "`n[ STATUS LAYANAN UTAMA ]" Cyan
        Check-ServiceStatus "Web Server (Nginx)" "Jagat-Nginx"
        Check-ServiceStatus "PHP FastCGI (Port 9000)" "Jagat-PHP-CGI"
        Check-ServiceStatus "Laravel Queue Worker" "Jagat-Queue"
        Check-ServiceStatus "Laravel Scheduler" "Jagat-Scheduler"
        Check-ServiceStatus "WhatsApp Gateway (GOWA)" "Jagat-WhatsApp"
        Check-ServiceStatus "WhatsApp Bot Go (Port 5000)" "Jagat-BotWA"
        Check-ServiceStatus "Telegram Bot Go" "Jagat-BotTele"

        # Cek Database
        Write-Host ("{0,-25} : " -f "Database MySQL/MariaDB") -NoNewline
        if (Test-PortFast "127.0.0.1" 3306) {
            Write-Color "[ AKTIF (Port 3306) ]" -color Green
        } else {
            Write-Color "[ TIDAK DAPAT DIAKSES (Port 3306) ]" -color Red
        }

        $nginxPort = "80"
        $nginxConf = Join-Path $ServerDir "bin\nginx\conf\nginx.conf"
        if (Test-Path $nginxConf) {
            $confContent = Get-Content $nginxConf -Raw
            if ($confContent -match '(?m)^\s*listen\s+(\d+)\s*;') {
                $nginxPort = $matches[1]
            }
        }
        $webDisplay = if ($nginxPort -eq "80") { "http://localhost" } else { "http://localhost:$nginxPort" }

        Write-Host ""
        Write-Color "Alamat Akses:" Yellow
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
                    & $nssm set Jagat-WhatsApp AppParameters "rest --port=3000 --basic-auth=admin:JagatTech123@,admin:jagattech --webhook=http://127.0.0.1:5000/webhook" 2>$null | Out-Null
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
        # Urutkan agar layanan background & gateway direstart terlebih dahulu, Jagat-PHP-CGI paling akhir
        $services = @("Jagat-Queue", "Jagat-Scheduler", "Jagat-WhatsApp", "Jagat-BotWA", "Jagat-BotTele", "Jagat-Nginx", "Jagat-PHP-CGI")
        foreach ($s in $services) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                Write-Host "Restart $s... " -NoNewline

                # Khusus Jagat-PHP-CGI: Jika dipanggil dari dalam lingkungan Web/PHP, lakukan async restart agar koneksi web tidak terputus/deadlock
                if ($s -eq "Jagat-PHP-CGI") {
                    $isWebContext = ($env:JAGAT_WEB_INVOCATION -eq "1" -or $env:HTTP_HOST -or $env:SERVER_SOFTWARE -or $env:REQUEST_METHOD)
                    if (-not $isWebContext) {
                        try {
                            $parentPid = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID" -ErrorAction SilentlyContinue).ParentProcessId
                            if ($parentPid) {
                                $parentName = (Get-Process -Id $parentPid -ErrorAction SilentlyContinue).ProcessName
                                if ($parentName -match "php") { $isWebContext = $true }
                            }
                        } catch {}
                    }

                    if ($isWebContext) {
                        Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -Command `"Start-Sleep -Seconds 2; Restart-Service -Name '$s' -Force`"" -WindowStyle Hidden
                        Write-Color "[OK (Dijadwalkan)]" -color Green
                        continue
                    }
                }

                try {
                    Restart-Service -Name $s -Force -ErrorAction Stop
                    Write-Color "[OK]" -color Green
                } catch {
                    Write-Color ("[GAGAL: " + $_.Exception.Message + "]") -color Red
                }
            }
        }
        Write-Color "`nSemua layanan berhasil di-restart!" Green
    }

    "update" {
        Show-Header
        Write-Color "`n=== MEMULAI UPDATE SISTEM ABSENSI JAGAT TECH (WINDOWS) ===" Yellow

        # 1. Update Web Absensi
        if (Test-Path $WebDir) {
            Write-Color "`n[1/3] Menarik commit terbaru Web Absensi (git pull)..." Cyan
            Push-Location $WebDir
            try {
                git pull origin main 2>$null
                if ($LASTEXITCODE -ne 0) { git pull origin master }
                
                Write-Color "  - Memperbarui dependensi PHP (composer install)..." Yellow
                composer install --no-dev --optimize-autoloader --no-interaction
                
                Write-Color "  - Menjalankan migrasi database & rehash lisensi..." Yellow
                & $PhpBin artisan migrate --force
                & $PhpBin artisan license:rehash --force 2>$null
                if ($LASTEXITCODE -ne 0) {
                    & $PhpBin artisan license:rehash 2>$null
                }
                
                Write-Color "  - Membersihkan dan mengoptimalkan cache Laravel..." Yellow
                & $PhpBin artisan storage:link --force
                & $PhpBin artisan optimize:clear
                & $PhpBin artisan optimize

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
