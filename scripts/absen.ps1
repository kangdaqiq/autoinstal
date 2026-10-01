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

        Write-Host ""
        Write-Color "Alamat Akses:" Yellow
        Write-Color "  - Web Absensi     : http://localhost" White
        Write-Color "  - WhatsApp Portal : http://localhost:3000" White
        Write-Color "  - Bot Webhook     : http://127.0.0.1:5000/webhook" White
    }

    "start" {
        Show-Header
        Write-Color "`nMenyalakan semua layanan Jagat Tech..." Yellow
        $services = @("Jagat-PHP-CGI", "Jagat-Nginx", "Jagat-WhatsApp", "Jagat-BotWA", "Jagat-BotTele", "Jagat-Queue")
        foreach ($s in $services) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                Write-Host "Memulai $s... " -NoNewline
                try {
                    Start-Service -Name $s -ErrorAction Stop
                    Write-Color "[OK]" -color Green
                } catch {
                    Write-Color ("[GAGAL: " + $_.Exception.Message + "]") -color Red
                }
            }
        }
        Write-Color "`nSemua layanan telah diinstruksikan untuk menyala." Green
    }

    "stop" {
        Show-Header
        Write-Color "`nMematikan semua layanan Jagat Tech..." Yellow
        $services = @("Jagat-Queue", "Jagat-BotTele", "Jagat-BotWA", "Jagat-WhatsApp", "Jagat-Nginx", "Jagat-PHP-CGI")
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
        $services = @("Jagat-PHP-CGI", "Jagat-Nginx", "Jagat-WhatsApp", "Jagat-BotWA", "Jagat-BotTele", "Jagat-Queue")
        foreach ($s in $services) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                Write-Host "Restart $s... " -NoNewline
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
                
                Write-Color "  - Menjalankan migrasi database..." Yellow
                & $PhpBin artisan migrate --force
                
                Write-Color "  - Membersihkan dan mengoptimalkan cache Laravel..." Yellow
                & $PhpBin artisan storage:link --force
                & $PhpBin artisan optimize:clear
                & $PhpBin artisan optimize

                Write-Color "  - Me-restart antrian background (queue worker)..." Yellow
                Restart-Service -Name "Jagat-Queue" -ErrorAction SilentlyContinue
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
            "queue" { Join-Path $WebDir "storage\logs\queue.log" }
            "bot"   { Join-Path $LogDir "bot_wa\bot_wa.log" }
            "tele"  { Join-Path $LogDir "bot_tele\bot_tele.log" }
            "wa"    { Join-Path $LogDir "whatsapp\whatsapp.log" }
            "nginx" { Join-Path $LogDir "nginx\error.log" }
            default { Join-Path $WebDir "storage\logs\laravel.log" }
        }

        if (Test-Path $logFile) {
            Write-Color ("Memantau log: " + $logFile + " (Tekan Ctrl+C untuk keluar)`n") Cyan
            Get-Content -Path $logFile -Tail 40 -Wait
        } else {
            Write-Color ("File log belum tersedia: " + $logFile) Yellow
        }
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
        Write-Color "  absen qr          " Green -NoNewline; Write-Host " - Buka portal WhatsApp untuk scan QR code"
        Write-Color "  absen logs        " Green -NoNewline; Write-Host " - Pantau log Laravel realtime"
        Write-Color "  absen logs bot    " Green -NoNewline; Write-Host " - Pantau log WhatsApp Bot Go"
        Write-Color "  absen logs tele   " Green -NoNewline; Write-Host " - Pantau log Telegram Bot Go"
        Write-Color "  absen logs wa     " Green -NoNewline; Write-Host " - Pantau log WhatsApp Gateway"
        Write-Color "  absen logs queue  " Green -NoNewline; Write-Host " - Pantau log Laravel Queue Worker"
        Write-Color "  absen logs nginx  " Green -NoNewline; Write-Host " - Pantau log error Nginx"
        Write-Host ""
    }
}
