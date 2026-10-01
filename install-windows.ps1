<#
==============================================================================
      _   _    ____    _  _____   _____ _____ ____ _   _ 
     | | / \  / ___|  / \|_   _| |_   _| ____/ ___| | | |
  _  | |/ _ \| |  _  / _ \ | |     | | |  _|| |   | |_| |
 | |_| / ___ \ |_| |/ ___ \| |     | | | |__| |___|  _  |
  \___/_/   \_\____/_/   \_\_|     |_| |_____\____|_| |_|
==============================================================================
  AUTO INSTALLER JAGAT TECH FOR WINDOWS (NATIVE POWERSHELL)
  Stack: Nginx | PHP 8.3/8.2 | MariaDB/MySQL | Composer | GOWA | Bot WA | Bot Tele
==============================================================================
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "C:\jagat-server",
    [string]$Domain = "localhost",
    [string]$WebPort = "80",
    [string]$DbHost = "127.0.0.1",
    [string]$DbPort = "3306",
    [string]$DbName = "absen_jagat",
    [string]$DbUser = "absen_user",
    [string]$DbPass = "JagatTech123@",
    [string]$WaPort = "3000",
    [string]$WaUser = "admin",
    [string]$WaPass = "JagatTech123@",
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
    if ($PSBoundParameters.Count -gt 0) {
        foreach ($key in $PSBoundParameters.Keys) {
            $val = $PSBoundParameters[$key]
            if ($val -is [switch]) {
                if ($val) { $argList += " -$key" }
            } else {
                $argList += " -$key `"$val`""
            }
        }
    }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    Exit
}

$Host.UI.RawUI.WindowTitle = "JAGAT TECH - Auto Installer Windows Server & Absensi"
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
} catch {}

# -----------------------------------------------------------------------------
# 2. Helper Output & UI
# -----------------------------------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host @"
==============================================================================
      _   _    ____    _  _____   _____ _____ ____ _   _ 
     | | / \  / ___|  / \|_   _| |_   _| ____/ ___| | | |
  _  | |/ _ \| |  _  / _ \ | |     | | |  _|| |   | |_| |
 | |_| / ___ \ |_| |/ ___ \| |     | | | |__| |___|  _  |
  \___/_/   \_\____/_/   \_\_|     |_| |_____\____|_| |_|
==============================================================================
  AUTO INSTALLER SERVER, WEB ABSENSI & WHATSAPP GATEWAY (WINDOWS NATIVE)
  Provider : JAGAT TECH
==============================================================================
"@ -ForegroundColor Cyan
}

function Log-Step([string]$msg) {
    Write-Host "`n>>> $msg" -ForegroundColor Blue
}

function Log-Info([string]$msg) {
    Write-Host " [i] $msg" -ForegroundColor White
}

function Log-Success([string]$msg) {
    Write-Host " [+] $msg" -ForegroundColor Green
}

function Log-Warn([string]$msg) {
    Write-Host " [!] $msg" -ForegroundColor Yellow
}

function Log-Error([string]$msg) {
    Write-Host " [x] $msg" -ForegroundColor Red
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

function Prompt-WithDefault([string]$promptText, [string]$defaultValue) {
    if ($NonInteractive) { return $defaultValue }
    Write-Host "$promptText [$defaultValue]: " -NoNewline -ForegroundColor Yellow
    $inputVal = Read-Host
    if ([string]::IsNullOrWhiteSpace($inputVal)) { return $defaultValue }
    return $inputVal.Trim()
}

function Download-FileWithProgress([string]$url, [string]$destPath, [string]$description) {
    Write-Host "   Mengunduh $description..." -ForegroundColor Gray
    $destFolder = Split-Path -Path $destPath
    if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null }
    
    # Gunakan curl.exe jika ada untuk kecepatan dan resume
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source -sSL -f -o "$destPath" "$url"
        if ($LASTEXITCODE -eq 0 -and (Test-Path $destPath)) { return }
    }
    
    # Fallback PowerShell Invoke-WebRequest
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing
}

# -----------------------------------------------------------------------------
# 3. Interaksi Pengguna & Konfigurasi Direktori
# -----------------------------------------------------------------------------
Write-Header
Write-Host "`nSelamat datang di Auto Installer JAGAT TECH untuk Windows Native." -ForegroundColor Green
Write-Host "Skrip ini akan memasang seluruh stack server, Web Absensi, WhatsApp Gateway, dan Bot.`n" -ForegroundColor White

if (-not $NonInteractive) {
    $InstallDir = Prompt-WithDefault "Lokasi Folder Instalasi Server" $InstallDir
    $Domain     = Prompt-WithDefault "Domain / Host Akses Web" $Domain
    $WebPort    = Prompt-WithDefault "Port Akses Web Absensi (HTTP)" $WebPort
    $DbPass     = Prompt-WithDefault "Password Database MariaDB/MySQL" $DbPass
    $WaPass     = Prompt-WithDefault "Password WhatsApp Gateway (GOWA)" $WaPass
}

$BinDir     = Join-Path $InstallDir "bin"
$WwwDir     = Join-Path $InstallDir "www"
$DataDir    = Join-Path $InstallDir "data"
$LogsDir    = Join-Path $InstallDir "logs"
$ScriptsDir = Join-Path $InstallDir "scripts"

$AppDir     = Join-Path $WwwDir "web"
$WaDir      = Join-Path $WwwDir "whatsapp"
$BotGoDir   = Join-Path $WwwDir "bot-go"
$BotTeleDir = Join-Path $WwwDir "bot-tele"

$PhpDir     = Join-Path $BinDir "php"
$NginxDir   = Join-Path $BinDir "nginx"
$NssmDir    = Join-Path $BinDir "nssm"
$NssmExe    = Join-Path $NssmDir "nssm.exe"

# Buat struktur direktori
@($InstallDir, $BinDir, $WwwDir, $DataDir, $LogsDir, $ScriptsDir,
  $PhpDir, $NginxDir, $NssmDir,
  $WaDir, $BotGoDir, $BotTeleDir,
  (Join-Path $LogsDir "nginx"), (Join-Path $LogsDir "php"),
  (Join-Path $LogsDir "whatsapp"), (Join-Path $LogsDir "bot_wa"),
  (Join-Path $LogsDir "bot_tele"), (Join-Path $LogsDir "queue")
) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# -----------------------------------------------------------------------------
# 4. Pengecekan & Instalasi Git
# -----------------------------------------------------------------------------
Log-Step "[1/9] Memeriksa & Menyiapkan Git for Windows..."
$gitCmd = Get-Command git.exe -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Log-Info "Git tidak ditemukan di sistem. Mengunduh MinGit portable..."
    $minGitZip = Join-Path $env:TEMP "mingit.zip"
    $minGitDir = Join-Path $BinDir "git"
    $minGitUrl = "https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/MinGit-2.46.0-64-bit.zip"
    Download-FileWithProgress $minGitUrl $minGitZip "MinGit Portable"
    Expand-Archive -Path $minGitZip -DestinationPath $minGitDir -Force
    Remove-Item -Path $minGitZip -Force -ErrorAction SilentlyContinue
    $env:PATH = "$minGitDir\cmd;$env:PATH"
    Log-Success "Git portable berhasil dipasang di $minGitDir\cmd"
} else {
    Log-Success "Git terdeteksi: $($gitCmd.Source)"
}

# -----------------------------------------------------------------------------
# 5. Pengecekan & Instalasi PHP 8.2 / 8.3 & Composer
# -----------------------------------------------------------------------------
Log-Step "[2/9] Memeriksa & Menyiapkan PHP 8.3/8.2 dan Composer..."

# Pengecekan & Instalasi Visual C++ 2015-2022 Redistributable (x64) jika belum ada atau versi lama
try {
    $vcReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64' -ErrorAction SilentlyContinue
    $needVcInstall = $true
    if ($vcReg -and $vcReg.Installed -eq 1 -and [int]$vcReg.Minor -ge 29) {
        $needVcInstall = $false
    }
    if ($needVcInstall) {
        Log-Info "Menyiapkan Microsoft Visual C++ 2015-2022 Redistributable (x64)..."
        $vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $vcRedistExe = Join-Path $env:TEMP "vc_redist.x64.exe"
        Download-FileWithProgress $vcRedistUrl $vcRedistExe "Visual C++ Redistributable"
        Start-Process -FilePath $vcRedistExe -ArgumentList "/install", "/quiet", "/norestart" -Wait
        Remove-Item -Path $vcRedistExe -Force -ErrorAction SilentlyContinue
        Log-Success "Visual C++ Redistributable berhasil dipasang/diperbarui."
    }
} catch {
    Log-Warn "Catatan instalasi Visual C++: $($_.Exception.Message)"
}

$systemPhp = Get-Command php.exe -ErrorAction SilentlyContinue
$useSystemPhp = $false
$PhpExe = ""
$PhpCgiExe = ""

if ($systemPhp) {
    $rawPhpOut = (& $systemPhp.Source -v 2>$null) -join " "
    if ($rawPhpOut -match 'PHP\s+([0-9]+\.[0-9]+(?:\.[0-9]+)?)') {
        $cleanVer = $matches[1]
        $isCompatible = $false
        try {
            $isCompatible = ([version]$cleanVer -ge [version]"8.2.0")
        } catch {}

        if ($isCompatible) {
            $phpBase = Split-Path -Path $systemPhp.Source
            $candCgi = Join-Path $phpBase "php-cgi.exe"
            if (Test-Path $candCgi) {
                Log-Success "PHP sistem terdeteksi kompatibel: v$cleanVer ($($systemPhp.Source))"
                $useSystemPhp = $true
                $PhpExe = $systemPhp.Source
                $PhpCgiExe = $candCgi
            } else {
                Log-Warn "PHP sistem v$cleanVer ditemukan, tetapi 'php-cgi.exe' tidak tersedia (dibutuhkan untuk Nginx FastCGI)."
                Log-Info "Installer akan memasang PHP 8.3 Portable mandiri di $PhpDir."
            }
        } else {
            Log-Warn "PHP sistem terdeteksi v$cleanVer (di bawah syarat minimum PHP 8.2+)."
            Log-Info "Untuk menjaga kestabilan, installer akan memasang PHP 8.3 Portable mandiri di $PhpDir."
            Log-Info "PHP lama Anda (misal di XAMPP) TIDAK AKAN terganggu / tertimpa."
        }
    }
}

if (-not $useSystemPhp) {
    Log-Info "Menyiapkan PHP 8.3 NTS Windows Portable di $PhpDir..."
    $phpZip = Join-Path $env:TEMP "php83.zip"
    
    # Deteksi URL rilis PHP 8.3 terbaru dari situs resmi
    $phpUrl = ""
    try {
        $downloadPage = (Invoke-WebRequest -Uri "https://windows.php.net/download/" -UseBasicParsing -TimeoutSec 8).Content
        if ($downloadPage -match '(/downloads/releases/php-8\.3\.[0-9]+-nts-Win32-[^"''\s>]+-x64\.zip)') {
            $phpUrl = "https://windows.php.net" + $matches[1]
            Log-Info "Ditemukan rilis resmi: $phpUrl"
        }
    } catch {}

    if (-not $phpUrl) {
        $phpUrl = "https://windows.php.net/downloads/releases/php-8.3.14-nts-Win32-vs16-x64.zip"
    }

    try {
        Download-FileWithProgress $phpUrl $phpZip "PHP 8.3 NTS x64"
    } catch {
        Log-Warn "Mencoba arsip rilis PHP 8.3 alternatif..."
        $phpUrl = "https://windows.php.net/downloads/releases/archives/php-8.3.12-nts-Win32-vs16-x64.zip"
        Download-FileWithProgress $phpUrl $phpZip "PHP 8.3 Archives"
    }

    Expand-Archive -Path $phpZip -DestinationPath $PhpDir -Force
    Remove-Item -Path $phpZip -Force -ErrorAction SilentlyContinue
    
    $PhpExe = Join-Path $PhpDir "php.exe"
    $PhpCgiExe = Join-Path $PhpDir "php-cgi.exe"
    
    # Salin & konfigurasi php.ini
    $iniDev = Join-Path $PhpDir "php.ini-development"
    $iniProd = Join-Path $PhpDir "php.ini-production"
    $iniTarget = Join-Path $PhpDir "php.ini"
    if (Test-Path $iniProd) { Copy-Item $iniProd $iniTarget -Force }
    elseif (Test-Path $iniDev) { Copy-Item $iniDev $iniTarget -Force }

    Log-Success "PHP 8.3 Portable terpasang di $PhpDir"
}

# Pastikan direktori PHP aktif berada di urutan terdepan PATH sesi saat ini
$phpBinDir = Split-Path -Path $PhpExe
$env:PATH = "$phpBinDir;$env:PATH"

# Aktifkan ekstensi yang diperlukan di php.ini
if (-not $useSystemPhp) {
    $currentIni = Join-Path $PhpDir "php.ini"
} else {
    $currentIniRaw = & $PhpExe -r "echo php_ini_loaded_file();" 2>$null
    $currentIni = ($currentIniRaw | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 -and (Test-Path $_ -PathType Leaf) } | Select-Object -First 1)
}

if ($currentIni -and (Test-Path $currentIni)) {
    Log-Info "Memverifikasi ekstensi di $currentIni..."
    
    # Set PHPRC lingkungan agar seluruh proses PHP selalu memuat php.ini ini
    $iniDir = Split-Path -Path $currentIni
    $env:PHPRC = $iniDir

    $iniContent = Get-Content -Path $currentIni -Raw
    
    $requiredExtensions = @(
        "curl", "fileinfo", "gd", "mbstring", "openssl",
        "pdo_mysql", "mysqli", "zip", "intl", "sockets", "exif"
    )
    
    foreach ($ext in $requiredExtensions) {
        # Uncomment extension=xxx atau extension=php_xxx.dll (dengan atau tanpa spasi setelah tanda titik koma)
        $iniContent = [System.Text.RegularExpressions.Regex]::Replace($iniContent, "(?m)^;\s*extension\s*=\s*(php_)?$ext(\.dll)?", "extension=$ext")
        $iniContent = [System.Text.RegularExpressions.Regex]::Replace($iniContent, "(?m)^extension\s*=\s*php_$ext\.dll", "extension=$ext")
    }

    # Atur memory_limit, upload_max_filesize, post_max_size
    $iniContent = [System.Text.RegularExpressions.Regex]::Replace($iniContent, "(?m)^memory_limit\s*=.*", "memory_limit = 256M")
    $iniContent = [System.Text.RegularExpressions.Regex]::Replace($iniContent, "(?m)^upload_max_filesize\s*=.*", "upload_max_filesize = 64M")
    $iniContent = [System.Text.RegularExpressions.Regex]::Replace($iniContent, "(?m)^post_max_size\s*=.*", "post_max_size = 64M")
    
    # Tentukan folder ext PHP secara absolut dengan forward slashes (bebas escape regex)
    $activePhpDir = Split-Path -Path $PhpExe
    $phpExtDir = (Join-Path $activePhpDir "ext").Replace('\', '/')
    
    # Hapus semua baris konfigurasi extension_dir yang ada (komentar maupun aktif) dan deduplikasi ekstensi
    $iniLines = $iniContent -split "`r?`n"
    $cleanLines = @()
    $seenExt = @{}
    foreach ($line in $iniLines) {
        if ($line -match '^\s*;?\s*extension_dir\s*=') {
            continue
        }
        if ($line -match '^\s*extension\s*=\s*([a-zA-Z0-9_]+)\s*$') {
            $eName = $matches[1].ToLower()
            if ($seenExt.ContainsKey($eName)) {
                continue
            }
            $seenExt[$eName] = $true
        }
        $cleanLines += $line
    }
    # Sisipkan extension_dir absolut di bagian paling atas
    $iniContent = "extension_dir = `"$phpExtDir`"`r`n" + ($cleanLines -join "`r`n")
    
    Set-Content -Path $currentIni -Value $iniContent -Force

    # Tes verifikasi ekstensi PHP penting
    $loadedModules = (& $PhpExe -c "$currentIni" -m 2>$null) -join " "
    if ($loadedModules -match "openssl" -and $loadedModules -match "pdo_mysql") {
        Log-Success "Ekstensi PHP penting (OpenSSL, PDO MySQL, cURL) aktif sempurna."
    } else {
        Log-Warn "Verifikasi modul PHP mendeteksi beberapa ekstensi belum siap."
    }
}

# Siapkan Composer
$compDir = Join-Path $BinDir "composer"
if (-not (Test-Path $compDir)) { New-Item -ItemType Directory -Path $compDir -Force | Out-Null }
$compPhar = Join-Path $compDir "composer.phar"

if (-not (Test-Path $compPhar)) {
    $sysPhar = "C:\ProgramData\ComposerSetup\bin\composer.phar"
    if (Test-Path $sysPhar) {
        Copy-Item $sysPhar $compPhar -Force
    } else {
        Download-FileWithProgress "https://getcomposer.org/composer.phar" $compPhar "Composer PHAR"
    }
}

$compBat = Join-Path $compDir "composer.bat"
Set-Content -Path $compBat -Value "@`"$PhpExe`" -c `"$currentIni`" `"$compPhar`" %*" -Force
$ComposerCmd = $compPhar
$env:PATH = "$compDir;$env:PATH"
Log-Success "Composer siap digunakan di $compPhar"

# -----------------------------------------------------------------------------
# 6. Menyiapkan NSSM (Windows Service Manager)
# -----------------------------------------------------------------------------
Log-Step "[3/9] Menyiapkan NSSM (Service Daemon Manager)..."
if (-not (Test-Path $NssmExe)) {
    $nssmZip = Join-Path $env:TEMP "nssm.zip"
    $nssmExtract = Join-Path $env:TEMP "nssm_extract"
    Download-FileWithProgress "https://nssm.cc/release/nssm-2.24.zip" $nssmZip "NSSM 2.24"
    Expand-Archive -Path $nssmZip -DestinationPath $nssmExtract -Force
    $foundNssm = Get-ChildItem -Path $nssmExtract -Filter "nssm.exe" -Recurse | Where-Object { $_.DirectoryName -like "*win64*" } | Select-Object -First 1
    if (-not (Test-Path $NssmDir)) { New-Item -ItemType Directory -Path $NssmDir -Force | Out-Null }
    if ($foundNssm) {
        Copy-Item -Path $foundNssm.FullName -Destination $NssmExe -Force
    } else {
        $anyNssm = Get-ChildItem -Path $nssmExtract -Filter "nssm.exe" -Recurse | Select-Object -First 1
        if ($anyNssm) {
            Copy-Item -Path $anyNssm.FullName -Destination $NssmExe -Force
        }
    }
    if (Test-Path $NssmExe) {
        Log-Success "NSSM 64-bit terpasang di $NssmExe"
    } else {
        Log-Error "Gagal memasang NSSM di $NssmExe"
    }
    Remove-Item -Path $nssmZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $nssmExtract -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Log-Success "NSSM sudah terpasang di $NssmExe"
}

# -----------------------------------------------------------------------------
# 7. Memeriksa & Menyiapkan Database MySQL / MariaDB
# -----------------------------------------------------------------------------
Log-Step "[4/9] Memeriksa & Mengonfigurasi Database MariaDB/MySQL..."

# 1. Cek apakah ada service database lokal (misal MySQL XAMPP / MariaDB) yang terpasang namun sedang Stopped
if (-not (Test-PortFast $DbHost ([int]$DbPort))) {
    $existingSvc = Get-Service -Name "mysql", "mariadb", "MySQL80" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Stopped" } | Select-Object -First 1
    if ($existingSvc) {
        Log-Info "Ditemukan layanan database lokal '$($existingSvc.Name)'. Menyalakan layanan..."
        Start-Service -Name $existingSvc.Name -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
}

# 2. Cek apakah ada XAMPP MySQL jika port masih belum aktif
if (-not (Test-PortFast $DbHost ([int]$DbPort))) {
    $xamppBat = "C:\xampp\mysql_start.bat"
    if (Test-Path $xamppBat) {
        Log-Info "Mencoba mengaktifkan MySQL dari instalasi XAMPP lokal..."
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$xamppBat`"" -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
}

# 3. Jika database masih belum aktif, unduh dari server direct mirror cepat (archive.mariadb.org)
if (-not (Test-PortFast $DbHost ([int]$DbPort))) {
    Log-Warn "Database belum aktif di $DbHost`:$DbPort."
    Log-Info "Mengunduh MariaDB Server dari server direct mirror cepat (archive.mariadb.org)..."
    $mariadbMsi = Join-Path $env:TEMP "mariadb-11.4.3-winx64.msi"
    $mariadbUrl = "https://archive.mariadb.org/mariadb-11.4.3/winx64-packages/mariadb-11.4.3-winx64.msi"
    try {
        Download-FileWithProgress $mariadbUrl $mariadbMsi "MariaDB 11.4 LTS (Direct Fast Mirror)"
        Log-Info "Memasang MariaDB Server di latar belakang..."
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$mariadbMsi`" /qn /norestart ALLUSERS=1 SERVICENAME=MariaDB PORT=3306" -Wait
        Start-Sleep -Seconds 5
        Remove-Item -Path $mariadbMsi -Force -ErrorAction SilentlyContinue
    } catch {
        Log-Warn "Gagal mengunduh installer MariaDB: $($_.Exception.Message)"
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($winget) {
            Log-Info "Mencoba pemasangan via winget sebagai alternatif..."
            & $winget.Source install --id MariaDB.Server -e --source winget --accept-source-agreements --accept-package-agreements --silent
            Start-Sleep -Seconds 5
        }
    }
}

# 4. Inisialisasi Database dan Pengguna jika port sudah terbuka
if (Test-PortFast $DbHost ([int]$DbPort)) {
    Log-Success "Database Server aktif di $DbHost`:$DbPort."
    
    # Deteksi client mysql.exe di PATH atau di direktori umum (XAMPP / MariaDB / MySQL)
    $mysqlCli = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if (-not $mysqlCli) {
        $commonCliPaths = @(
            "C:\xampp\mysql\bin\mysql.exe",
            "C:\Program Files\MariaDB 11.4\bin\mysql.exe",
            "C:\Program Files\MariaDB 11.5\bin\mysql.exe",
            "C:\Program Files\MariaDB 10.11\bin\mysql.exe",
            "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
            "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
        )
        foreach ($cp in $commonCliPaths) {
            if (Test-Path $cp) {
                $mysqlCli = [PSCustomObject]@{ Source = $cp }
                break
            }
        }
    }
    if (-not $mysqlCli) {
        $foundMysqlItem = Get-ChildItem -Path "C:\Program Files\MariaDB*", "C:\Program Files\MySQL*", "C:\Program Files (x86)\MariaDB*", "C:\Program Files (x86)\MySQL*" -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundMysqlItem) {
            $mysqlCli = [PSCustomObject]@{ Source = $foundMysqlItem.FullName }
        }
    }

    $mysqlBinDir = ""
    if ($mysqlCli) {
        $mysqlBinDir = Split-Path -Path $mysqlCli.Source
        if ($env:PATH -notlike "*$mysqlBinDir*") {
            $env:PATH = "$mysqlBinDir;$env:PATH"
            Log-Info "Client MySQL/MariaDB ditambahkan ke PATH: $mysqlBinDir"
        }
    }

    if ($mysqlCli) {
        Log-Info "Membuat database $DbName dan user $DbUser otomatis..."
        $sqlScript = @"
CREATE DATABASE IF NOT EXISTS $DbName CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DbUser'@'localhost' IDENTIFIED BY '$DbPass';
CREATE USER IF NOT EXISTS '$DbUser'@'127.0.0.1' IDENTIFIED BY '$DbPass';
GRANT ALL PRIVILEGES ON $DbName.* TO '$DbUser'@'localhost';
GRANT ALL PRIVILEGES ON $DbName.* TO '$DbUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
        $tempSql = Join-Path $env:TEMP "init_jagat_db.sql"
        Set-Content -Path $tempSql -Value $sqlScript -Force
        
        # Coba konek tanpa password root terlebih dahulu (default XAMPP/MariaDB lokal)
        Get-Content -Path $tempSql | & $mysqlCli.Source -h $DbHost -P $DbPort -u root 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Warn "MySQL root memerlukan password atau hak akses khusus."
        } else {
            Log-Success "Database $DbName dan user $DbUser siap digunakan!"
        }
        Remove-Item -Path $tempSql -Force -ErrorAction SilentlyContinue
    }
} else {
    Log-Warn "Database belum dapat dihubungi di $DbHost`:$DbPort. Silakan pastikan service MySQL/MariaDB menyala."
}

# -----------------------------------------------------------------------------
# 8. Menyiapkan Nginx for Windows & VirtualHost
# -----------------------------------------------------------------------------
Log-Step "[5/9] Menyiapkan Nginx for Windows & VirtualHost Web Absensi..."
$NginxExe = Join-Path $NginxDir "nginx.exe"
if (-not (Test-Path $NginxExe)) {
    $nginxZip = Join-Path $env:TEMP "nginx.zip"
    $nginxExtract = Join-Path $env:TEMP "nginx_extract"
    Download-FileWithProgress "https://nginx.org/download/nginx-1.26.2.zip" $nginxZip "Nginx 1.26.2 Windows"
    Expand-Archive -Path $nginxZip -DestinationPath $nginxExtract -Force
    $foundFolder = Get-ChildItem -Path $nginxExtract -Directory | Select-Object -First 1
    Copy-Item -Path "$($foundFolder.FullName)\*" -Destination $NginxDir -Recurse -Force
    Remove-Item -Path $nginxZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $nginxExtract -Recurse -Force -ErrorAction SilentlyContinue
    Log-Success "Nginx for Windows terpasang di $NginxDir"
}

# Tulis konfigurasi nginx.conf khusus Jagat Tech
$nginxPublicRoot = ($AppDir + "\public").Replace('\', '/')
$nginxConf = Join-Path $NginxDir "conf\nginx.conf"
$nginxConfContent = @"
worker_processes 2;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    client_max_body_size 64M;

    server {
        listen $WebPort;
        server_name $Domain localhost _;
        root "$nginxPublicRoot";

        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        add_header X-XSS-Protection "1; mode=block";

        index index.php index.html;
        charset utf-8;

        # WhatsApp Gateway Reverse Proxy
        location /wa-portal/ {
            proxy_pass http://127.0.0.1:$WaPort/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade `$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host `$host;
            proxy_cache_bypass `$http_upgrade;
        }

        location / {
            try_files `$uri `$uri/ /index.php?`$query_string;
        }

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        error_page 404 /index.php;

        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME `$document_root`$fastcgi_script_name;
            include fastcgi_params;
            fastcgi_read_timeout 300;
        }

        location ~ /\.(?!well-known).* {
            deny all;
        }
    }
}
"@
Set-Content -Path $nginxConf -Value $nginxConfContent -Force
Log-Success "Konfigurasi VirtualHost Nginx berhasil diperbarui."

# -----------------------------------------------------------------------------
# 9. Deploy Web Absensi Multi-Tenant (Git Clone, Composer, Artisan)
# -----------------------------------------------------------------------------
Log-Step "[6/9] Men-deploy Aplikasi Web Absensi Multi-Tenant (Git & Laravel)..."
$gitRepo = "https://github.com/kangdaqiq/absen_multi.git"
if (-not (Test-Path (Join-Path $AppDir ".git"))) {
    Log-Info "Meng-clone repositori Web Absensi ke $AppDir..."
    git clone $gitRepo $AppDir
} else {
    Log-Info "Repositori Web Absensi sudah ada, menarik pembaruan..."
    Push-Location $AppDir
    git pull origin main 2>$null
    if ($LASTEXITCODE -ne 0) { git pull origin master }
    Pop-Location
}

# Setup .env file
$envFile = Join-Path $AppDir ".env"
$envExample = Join-Path $AppDir ".env.selfhosted.example"
if (-not (Test-Path $envExample)) { $envExample = Join-Path $AppDir ".env.example" }

if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
    Copy-Item $envExample $envFile -Force
}

if (Test-Path $envFile) {
    Log-Info "Menyelaraskan konfigurasi .env Web Absensi..."
    $envContent = Get-Content -Path $envFile -Raw
    
    $appUrl = if ($WebPort -eq "80") { "http://$Domain" } else { "http://${Domain}:${WebPort}" }
    $replacements = @{
        "(?m)^APP_URL=.*"            = "APP_URL=$appUrl"
        "(?m)^DB_CONNECTION=.*"      = "DB_CONNECTION=mysql"
        "(?m)^DB_HOST=.*"            = "DB_HOST=$DbHost"
        "(?m)^DB_PORT=.*"            = "DB_PORT=$DbPort"
        "(?m)^DB_DATABASE=.*"        = "DB_DATABASE=$DbName"
        "(?m)^DB_USERNAME=.*"        = "DB_USERNAME=$DbUser"
        "(?m)^DB_PASSWORD=.*"        = "DB_PASSWORD=$DbPass"
        "(?m)^GOWA_API_URL=.*"       = "GOWA_API_URL=http://127.0.0.1:$WaPort"
        "(?m)^GOWA_API_USER=.*"      = "GOWA_API_USER=$WaUser"
        "(?m)^GOWA_API_PASS=.*"      = "GOWA_API_PASS=$WaPass"
        "(?m)^QUEUE_CONNECTION=.*"   = "QUEUE_CONNECTION=database"
    }

    foreach ($pattern in $replacements.Keys) {
        $envContent = [System.Text.RegularExpressions.Regex]::Replace($envContent, $pattern, $replacements[$pattern])
    }
    Set-Content -Path $envFile -Value $envContent -Force
}

# Jalankan Composer Install & Artisan
Push-Location $AppDir
try {
    Log-Info "Menjalankan composer install..."
    & $PhpExe -c "$currentIni" "$ComposerCmd" install --no-dev --optimize-autoloader --no-interaction

    if ($LASTEXITCODE -ne 0) {
        throw "Composer install gagal (exit code: $LASTEXITCODE). Pastikan ekstensi PHP dan koneksi internet siap."
    }

    # Pastikan client mysql.exe tersedia di PATH untuk import schema database Laravel (mysql-schema.sql)
    $mysqlInPath = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if (-not $mysqlInPath) {
        $candidateMysql = Get-ChildItem -Path "C:\Program Files\MariaDB*", "C:\Program Files\MySQL*", "C:\Program Files (x86)\MariaDB*", "C:\Program Files (x86)\MySQL*", "C:\xampp\mysql\bin" -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidateMysql) {
            $mDir = Split-Path -Path $candidateMysql.FullName
            $env:PATH = "$mDir;$env:PATH"
            Log-Info "Menambahkan '$mDir' ke PATH untuk import skema Laravel."
        }
    }

    Log-Info "Menghasilkan APP_KEY, migrasi database, dan rehash lisensi..."
    & $PhpExe -c "$currentIni" artisan key:generate --force
    & $PhpExe -c "$currentIni" artisan migrate --force
    & $PhpExe -c "$currentIni" artisan license:rehash --force 2>$null
    if ($LASTEXITCODE -ne 0) {
        & $PhpExe -c "$currentIni" artisan license:rehash 2>$null
    }
    & $PhpExe -c "$currentIni" artisan storage:link --force
    & $PhpExe -c "$currentIni" artisan optimize:clear
    & $PhpExe -c "$currentIni" artisan optimize
    Log-Success "Web Absensi berhasil di-deploy dan teroptimasi."
} catch {
    Log-Warn "Ada catatan saat migrasi/composer: $($_.Exception.Message)"
} finally {
    Pop-Location
}

# -----------------------------------------------------------------------------
# 10. Mengunduh & Menyiapkan WhatsApp Gateway (GOWA Latest Release)
# -----------------------------------------------------------------------------
Log-Step "[7/9] Mengunduh & Memasang WhatsApp Gateway (GOWA Windows)..."
$WaExe = Join-Path $WaDir "whatsapp.exe"
try {
    Log-Info "Mencari versi rilis terbaru GOWA..."
    $gowaRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/aldinokemal/go-whatsapp-web-multidevice/releases/latest" -UseBasicParsing
    $latestTag = $gowaRelease.tag_name
    $cleanTag = $latestTag.TrimStart('v')
    $gowaZipName = "whatsapp_${cleanTag}_windows_amd64.zip"
    $gowaUrl = "https://github.com/aldinokemal/go-whatsapp-web-multidevice/releases/download/${latestTag}/${gowaZipName}"

    $gowaZip = Join-Path $env:TEMP "gowa_win.zip"
    $gowaExtract = Join-Path $env:TEMP "gowa_extract"
    Download-FileWithProgress $gowaUrl $gowaZip "WhatsApp Gateway ($latestTag)"
    Expand-Archive -Path $gowaZip -DestinationPath $gowaExtract -Force
    $foundWaExe = Get-ChildItem -Path $gowaExtract -Filter "*.exe" -Recurse | Select-Object -First 1
    if ($foundWaExe) {
        if (-not (Test-Path $WaDir)) { New-Item -ItemType Directory -Path $WaDir -Force | Out-Null }
        Copy-Item -Path $foundWaExe.FullName -Destination $WaExe -Force
        Log-Success "WhatsApp Gateway ($latestTag) terpasang di $WaExe"
    } else {
        Log-Error "File executable WhatsApp Gateway (.exe) tidak ditemukan di dalam paket rilis."
    }
    Remove-Item -Path $gowaZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $gowaExtract -Recurse -Force -ErrorAction SilentlyContinue
} catch {
    Log-Warn "Gagal mengambil rilis otomatis GOWA: $($_.Exception.Message)"
}

# -----------------------------------------------------------------------------
# 11. Mengunduh & Menyiapkan Bot WhatsApp Go & Bot Telegram Go
# -----------------------------------------------------------------------------
Log-Step "[8/9] Mengunduh & Memasang WhatsApp Bot Go & Telegram Bot Go..."
$BotWaExe   = Join-Path $BotGoDir "bot_wa.exe"
$BotTeleExe = Join-Path $BotTeleDir "bot_tele.exe"

# Bot WA .env
$botWaEnv = Join-Path $BotGoDir ".env"
if (-not (Test-Path $botWaEnv)) {
    $botWaEnvContent = @"
PORT=5000
DB_CONNECTION=mysql
DB_HOST=$DbHost
DB_PORT=$DbPort
DB_NAME=$DbName
DB_DATABASE=$DbName
DB_USER=$DbUser
DB_USERNAME=$DbUser
DB_PASSWORD=$DbPass

GOWA_API_BASE_URL=http://127.0.0.1:$WaPort
GOWA_API_USER=$WaUser
GOWA_API_PASS=$WaPass
WA_API_URL=http://127.0.0.1:$WaPort
WA_API_BASE_URL=http://127.0.0.1:$WaPort
WA_API_USER=$WaUser
WA_API_PASS=$WaPass

APP_URL=http://$Domain
WA_DEVICE_ID=1
SUPERADMIN_WA_ID=
"@
    Set-Content -Path $botWaEnv -Value $botWaEnvContent -Force
}

# Unduh binary bot_wa.exe
try {
    $botWaUrl = "https://github.com/kangdaqiq/bot-go/releases/latest/download/bot-windows-amd64.zip"
    $bwaZip = Join-Path $env:TEMP "bot_wa_win.zip"
    $bwaExtract = Join-Path $env:TEMP "bot_wa_extract"
    Download-FileWithProgress $botWaUrl $bwaZip "WhatsApp Bot Go (Windows)"
    Expand-Archive -Path $bwaZip -DestinationPath $bwaExtract -Force
    $foundBwa = Get-ChildItem -Path $bwaExtract -Filter "bot_wa*.exe" -Recurse | Select-Object -First 1
    if ($foundBwa) {
        Copy-Item -Path $foundBwa.FullName -Destination $BotWaExe -Force
        Log-Success "WhatsApp Bot Go terpasang di $BotWaExe"
    }
    Remove-Item -Path $bwaZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $bwaExtract -Recurse -Force -ErrorAction SilentlyContinue
} catch {
    Log-Warn "Catatan unduhan Bot WA: $($_.Exception.Message)"
}

# Bot Tele .env
$botTeleEnv = Join-Path $BotTeleDir ".env"
if (-not (Test-Path $botTeleEnv)) {
    $botTeleEnvContent = @"
DB_CONNECTION=mysql
DB_HOST=$DbHost
DB_PORT=$DbPort
DB_DATABASE=$DbName
DB_NAME=$DbName
DB_USERNAME=$DbUser
DB_USER=$DbUser
DB_PASSWORD=$DbPass

APP_URL=http://$Domain
TELEGRAM_BOT_TOKEN=
"@
    Set-Content -Path $botTeleEnv -Value $botTeleEnvContent -Force
}

# Unduh binary bot_tele.exe
try {
    $botTeleUrl = "https://github.com/kangdaqiq/bot_tele/releases/latest/download/bot_tele-windows-amd64.zip"
    $btZip = Join-Path $env:TEMP "bot_tele_win.zip"
    $btExtract = Join-Path $env:TEMP "bot_tele_extract"
    Download-FileWithProgress $botTeleUrl $btZip "Telegram Bot Go (Windows)"
    Expand-Archive -Path $btZip -DestinationPath $btExtract -Force
    $foundBt = Get-ChildItem -Path $btExtract -Filter "bot_tele*.exe" -Recurse | Select-Object -First 1
    if ($foundBt) {
        Copy-Item -Path $foundBt.FullName -Destination $BotTeleExe -Force
        Log-Success "Telegram Bot Go terpasang di $BotTeleExe"
    }
    Remove-Item -Path $btZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $btExtract -Recurse -Force -ErrorAction SilentlyContinue
} catch {
    Log-Warn "Catatan unduhan Bot Telegram: $($_.Exception.Message)"
}


# -----------------------------------------------------------------------------
# 12. Pendaftaran Windows Background Services (via NSSM)
# -----------------------------------------------------------------------------
Log-Step "[9/9] Mendaftarkan Layanan Background Windows (Auto-Start on Boot)..."

function Install-NssmService([string]$name, [string]$appPath, [string]$appArgs, [string]$workDir, [string]$logFile) {
    # Hentikan & hapus jika sudah ada sebelumnya
    & $NssmExe stop $name 2>$null
    & $NssmExe remove $name confirm 2>$null
    
    Log-Info "Mendaftarkan service: $name..."
    & $NssmExe install $name "$appPath" $appArgs
    & $NssmExe set $name AppDirectory "$workDir"
    & $NssmExe set $name AppStdout "$logFile"
    & $NssmExe set $name AppStderr "$logFile"
    & $NssmExe set $name Start SERVICE_AUTO_START
    & $NssmExe set $name AppRestartDelay 5000
    & $NssmExe start $name
}

# 1. Jagat-PHP-CGI
if (Test-Path $PhpCgiExe) {
    Install-NssmService "Jagat-PHP-CGI" $PhpCgiExe "-b 127.0.0.1:9000" (Split-Path $PhpCgiExe) (Join-Path $LogsDir "php\php-cgi.log")
}

# 2. Jagat-Nginx
if (Test-Path $NginxExe) {
    Install-NssmService "Jagat-Nginx" $NginxExe "" $NginxDir (Join-Path $LogsDir "nginx\nginx_service.log")
}

# 3. Jagat-Queue Worker
Install-NssmService "Jagat-Queue" $PhpExe "artisan queue:work --sleep=3 --tries=3" $AppDir (Join-Path $LogsDir "queue\queue.log")

# 4. Jagat-WhatsApp Gateway
if (Test-Path $WaExe) {
    $waArgs = "rest --port=$WaPort --basic-auth=$WaUser`:$WaPass --webhook=http://127.0.0.1:5000/webhook"
    Install-NssmService "Jagat-WhatsApp" $WaExe $waArgs $WaDir (Join-Path $LogsDir "whatsapp\whatsapp.log")
}

# 5. Jagat-BotWA
if (Test-Path $BotWaExe) {
    Install-NssmService "Jagat-BotWA" $BotWaExe "" $BotGoDir (Join-Path $LogsDir "bot_wa\bot_wa.log")
}

# 6. Jagat-BotTele
if (Test-Path $BotTeleExe) {
    Install-NssmService "Jagat-BotTele" $BotTeleExe "" $BotTeleDir (Join-Path $LogsDir "bot_tele\bot_tele.log")
}

# -----------------------------------------------------------------------------
# 13. Salin CLI Tool `absen` & Daftarkan ke PATH Sistem
# -----------------------------------------------------------------------------
$scriptSrcDir = Split-Path -Path $MyInvocation.MyCommand.Path
$srcAbsenPs1 = Join-Path $scriptSrcDir "scripts\absen.ps1"
$srcAbsenCmd = Join-Path $scriptSrcDir "scripts\absen.cmd"

if (Test-Path $srcAbsenPs1) { Copy-Item $srcAbsenPs1 (Join-Path $ScriptsDir "absen.ps1") -Force }
if (Test-Path $srcAbsenCmd) { Copy-Item $srcAbsenCmd (Join-Path $ScriptsDir "absen.cmd") -Force }

# Tambahkan $ScriptsDir dan $PhpDir ke System Environment PATH jika belum ada
$currentMachinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$pathsToAdd = @($ScriptsDir)
if (-not $useSystemPhp) { $pathsToAdd += $PhpDir }
if ($mysqlBinDir) { $pathsToAdd += $mysqlBinDir }

foreach ($p in $pathsToAdd) {
    if ($currentMachinePath -notlike "*$p*") {
        $newMachinePath = "$p;$currentMachinePath"
        [Environment]::SetEnvironmentVariable("PATH", $newMachinePath, "Machine")
        $env:PATH = "$p;$env:PATH"
    }
}
[Environment]::SetEnvironmentVariable("JAGAT_SERVER_DIR", $InstallDir, "Machine")
$env:JAGAT_SERVER_DIR = $InstallDir

# Salin juga ke C:\Windows\System32\absen.cmd agar langsung dapat dipanggil di semua command prompt
try {
    Copy-Item (Join-Path $ScriptsDir "absen.cmd") "C:\Windows\System32\absen.cmd" -Force -ErrorAction SilentlyContinue
} catch {}

# Buat Desktop Shortcuts
$wshShell = New-Object -ComObject WScript.Shell
$desktopPath = [Environment]::GetFolderPath("Desktop")

# 1. Shortcut Web Absensi
$webUrl = if ($WebPort -eq "80") { "http://localhost" } else { "http://localhost:$WebPort" }
$webDisplay = if ($WebPort -eq "80") { "http://localhost (atau http://$Domain)" } else { "http://localhost:$WebPort (atau http://${Domain}:$WebPort)" }
$scWeb = $wshShell.CreateShortcut((Join-Path $desktopPath "Web Absensi JAGAT TECH.url"))
$scWeb.TargetPath = $webUrl
$scWeb.Save()

# 2. Shortcut WhatsApp Portal
$scWa = $wshShell.CreateShortcut((Join-Path $desktopPath "WhatsApp Gateway Portal.url"))
$scWa.TargetPath = "http://localhost:$WaPort"
$scWa.Save()

# 3. Shortcut CLI Control
$scCli = $wshShell.CreateShortcut((Join-Path $desktopPath "Jagat Server Control (CLI).lnk"))
$scCli.TargetPath = "cmd.exe"
$scCli.Arguments = "/k absen status"
$scCli.WorkingDirectory = $InstallDir
$scCli.Description = "Kontrol Layanan Server JAGAT TECH"
$scCli.Save()

# -----------------------------------------------------------------------------
# 14. Ringkasan & Selesai
# -----------------------------------------------------------------------------
Write-Host @"

==============================================================================
  [+] INSTALASI SERVER JAGAT TECH WINDOWS SELESAI DENGAN SUKSES!
==============================================================================

  - Direktori Server   : $InstallDir
  - Web Absensi        : $webDisplay
  - WhatsApp Gateway   : http://localhost:$WaPort
                         Username : $WaUser
                         Password : $WaPass
  - WhatsApp Bot Go    : Webhook aktif di port 5000
  - Telegram Bot Go    : Aktif (Silakan set token bot di $BotTeleDir\.env)
  - Database MariaDB   : $DbName (User: $DbUser)

==============================================================================
  CARA MENGELOLA SERVER VIA TERMINAL (CMD / POWERSHELL):
==============================================================================
  absen status     -> Cek kondisi aktif/tidaknya seluruh service
  absen start      -> Menyalakan seluruh service
  absen stop       -> Menghentikan seluruh service
  absen restart    -> Me-restart seluruh service
  absen update     -> Update kode Web via Git & update binary Bot terbaru
  absen qr         -> Buka WhatsApp Gateway di browser untuk scan QR
  absen logs       -> Pantau log realtime aplikasi & bot

  Shortcut telah dibuat di Desktop Anda untuk kemudahan akses!
==============================================================================
"@ -ForegroundColor Green
