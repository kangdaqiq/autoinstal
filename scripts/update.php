<?php
/**
 * ==============================================================================
 *   JAGAT TECH — SYSTEM WEB CONSOLE & AUTO UPDATER
 * ==============================================================================
 *  Cross-Platform Web Controller: Windows Native, Debian, & Armbian (Amlogic S905X)
 *  Fitur: Update Git/Composer/DB, Restart Service, Status, Backup & Live Logs
 *  Akses Langsung (Tanpa PIN Autentikasi)
 * ==============================================================================
 */

// Matikan limit eksekusi waktu agar tidak timeout saat composer / git pull
@ini_set('max_execution_time', 0);
@set_time_limit(0);

$isWindows = (PHP_OS_FAMILY === 'Windows');

// --- 1. Handle Streaming Terminal (SSE) ---
if (isset($_GET['action']) && $_GET['action'] === 'stream') {
    header('Content-Type: text/event-stream');
    header('Cache-Control: no-cache, no-store, must-revalidate');
    header('Pragma: no-cache');
    header('X-Accel-Buffering: no'); // Penting untuk Nginx agar tidak mem-buffer stream

    // Cegah output buffering bawaan PHP
    while (ob_get_level() > 0) {
        ob_end_clean();
    }

    $cmdKey = isset($_GET['cmd']) ? preg_replace('/[^a-zA-Z0-9_\-]/', '', $_GET['cmd']) : 'status';

    // Daftar perintah yang diizinkan untuk keamanan
    $validCommands = [
        'update'  => 'update',
        'status'  => 'status',
        'restart' => 'restart',
        'backup'  => 'backup',
        'log_web' => 'logs',
        'log_wa'  => 'logs wa',
        'log_bot' => 'logs bot',
    ];

    if (!isset($validCommands[$cmdKey])) {
        echo "data: [ERROR] Perintah tidak valid.\n\n";
        exit;
    }

    $subCommand = $validCommands[$cmdKey];

    // --- Auto-Sync Skrip CLI & Web Console ke Versi Terbaru GitHub saat Update ---
    if ($cmdKey === 'update') {
        echo "data: [AUTO-SYNC] Memeriksa pembaruan skrip CLI & Web Console dari GitHub...\n\n";
        @ob_flush();
        flush();

        $ctx = stream_context_create([
            'http' => [
                'timeout' => 4,
                'header'  => "User-Agent: JagatTech-Updater/1.0\r\n"
            ]
        ]);

        if ($isWindows) {
            $serverDir = getenv('JAGAT_SERVER_DIR') ?: 'C:\jagat-server';
            $psScript = $serverDir . '\scripts\absen.ps1';
            $latestPs1 = @file_get_contents('https://raw.githubusercontent.com/kangdaqiq/autoinstal/main/scripts/absen.ps1', false, $ctx);
            if ($latestPs1 && strlen($latestPs1) > 1000) {
                @file_put_contents($psScript, $latestPs1);
                echo "data: [AUTO-SYNC] Skrip absen.ps1 di server berhasil diperbarui ke rilis terbaru.\n\n";
                @ob_flush();
                flush();
            }
        } else {
            $latestSh = @file_get_contents('https://raw.githubusercontent.com/kangdaqiq/autoinstal/main/scripts/absen-cli.sh', false, $ctx);
            if ($latestSh && strlen($latestSh) > 1000) {
                $tmpFile = tempnam(sys_get_temp_dir(), 'absen_');
                if ($tmpFile) {
                    file_put_contents($tmpFile, $latestSh);
                    @shell_exec("sudo cp -f {$tmpFile} /usr/local/bin/absen && sudo chmod +x /usr/local/bin/absen");
                    @unlink($tmpFile);
                    echo "data: [AUTO-SYNC] Skrip /usr/local/bin/absen berhasil diperbarui ke rilis terbaru.\n\n";
                    @ob_flush();
                    flush();
                }
            }
        }

        // Self-update file update.php ini sendiri
        $latestSelf = @file_get_contents('https://raw.githubusercontent.com/kangdaqiq/autoinstal/main/scripts/update.php', false, $ctx);
        if ($latestSelf && strlen($latestSelf) > 1000 && is_writable(__FILE__)) {
            @file_put_contents(__FILE__, $latestSelf);
            echo "data: [AUTO-SYNC] Halaman Web Console (update.php) berhasil diperbarui ke rilis terbaru.\n\n";
            @ob_flush();
            flush();
        }
    }

    if ($isWindows) {
        // Windows Native Execution
        $serverDir = getenv('JAGAT_SERVER_DIR') ?: 'C:\jagat-server';
        $psScript = $serverDir . '\scripts\absen.ps1';
        $cmdBatch = 'C:\Windows\System32\absen.cmd';

        if (file_exists($psScript)) {
            $execCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . $psScript . '" ' . $subCommand . ' 2>&1';
        } elseif (file_exists($cmdBatch)) {
            $execCommand = 'cmd.exe /c absen.cmd ' . $subCommand . ' 2>&1';
        } else {
            $execCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "absen ' . $subCommand . '" 2>&1';
        }
    } else {
        // Linux / Armbian Execution (membutuhkan sudoers rule: www-data ALL=(ALL) NOPASSWD: /usr/local/bin/absen)
        $execCommand = 'sudo /usr/local/bin/absen ' . $subCommand . ' 2>&1';
    }

    echo "data: [INFO] Memulai perintah: " . $subCommand . " (" . ($isWindows ? 'Windows Native' : 'Linux') . ")...\n\n";
    @ob_flush();
    flush();

    $descriptors = [
        0 => ["pipe", "r"], // stdin
        1 => ["pipe", "w"], // stdout
        2 => ["pipe", "w"], // stderr
    ];

    @putenv('JAGAT_WEB_INVOCATION=1');
    $process = proc_open($execCommand, $descriptors, $pipes);

    if (is_resource($process)) {
        fclose($pipes[0]); // Tutup stdin

        // Set non-blocking
        stream_set_blocking($pipes[1], 0);
        stream_set_blocking($pipes[2], 0);

        while (true) {
            $read = [$pipes[1], $pipes[2]];
            $write = null;
            $except = null;

            $numChanged = @stream_select($read, $write, $except, 0, 200000); // 200ms timeout
            if ($numChanged > 0) {
                foreach ($read as $pipe) {
                    while (($line = fgets($pipe)) !== false) {
                        // Bersihkan kode ANSI warna terminal agar rapi di browser
                        $clean = preg_replace('/\x1b\[[0-9;]*m/', '', $line);
                        $clean = trim($clean, "\r\n");
                        if ($clean !== '') {
                            echo "data: " . $clean . "\n\n";
                            @ob_flush();
                            flush();
                        }
                    }
                }
            }

            $status = proc_get_status($process);
            if (!$status['running']) {
                // Baca sisa buffer
                while (($line = fgets($pipes[1])) !== false) {
                    $clean = preg_replace('/\x1b\[[0-9;]*m/', '', $line);
                    $clean = trim($clean, "\r\n");
                    if ($clean !== '') {
                        echo "data: " . $clean . "\n\n";
                    }
                }
                while (($line = fgets($pipes[2])) !== false) {
                    $clean = preg_replace('/\x1b\[[0-9;]*m/', '', $line);
                    $clean = trim($clean, "\r\n");
                    if ($clean !== '') {
                        echo "data: " . $clean . "\n\n";
                    }
                }
                break;
            }
        }

        fclose($pipes[1]);
        fclose($pipes[2]);
        $exitCode = proc_close($process);

        echo "data: [SELESAI] Perintah selesai dieksekusi dengan kode keluar: " . $exitCode . "\n\n";
    } else {
        echo "data: [ERROR] Gagal membuka proses terminal di sistem server.\n\n";
    }

    @ob_flush();
    flush();
    exit;
}

$serverHost = gethostname() ?: 'JagatServer';
$serverOS = PHP_OS . ' (' . php_uname('m') . ')';
$phpVer = PHP_VERSION;
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>JAGAT TECH — Web System Updater & Console</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-body: #0b0f19;
            --bg-card: #111827;
            --bg-card-sub: #1f2937;
            --border: #374151;
            --primary: #06b6d4;
            --primary-hover: #0891b2;
            --emerald: #10b981;
            --amber: #f59e0b;
            --rose: #f43f5e;
            --text-main: #f9fafb;
            --text-muted: #9ca3af;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: var(--bg-body);
            color: var(--text-main);
            font-family: 'Plus Jakarta Sans', sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justifyContent: space-between;
            padding: 24px 16px;
        }

        .container {
            max-width: 960px;
            width: 100%;
            margin: 0 auto;
        }

        /* Header Bar */
        .header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: rgba(17, 24, 39, 0.8);
            backdrop-filter: blur(12px);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 16px 24px;
            margin-bottom: 24px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .logo-badge {
            background: linear-gradient(135deg, #06b6d4, #3b82f6);
            color: #fff;
            font-weight: 800;
            font-size: 18px;
            width: 42px;
            height: 42px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 4px 12px rgba(6, 182, 212, 0.35);
        }

        .brand-text h1 {
            font-size: 18px;
            font-weight: 800;
            color: var(--text-main);
            letter-spacing: -0.5px;
        }

        .brand-text span {
            font-size: 12px;
            color: var(--text-muted);
            font-weight: 500;
        }

        .server-meta {
            display: flex;
            gap: 8px;
            flex-wrap: wrap;
            align-items: center;
        }

        .badge {
            background: var(--bg-card-sub);
            border: 1px solid var(--border);
            padding: 4px 10px;
            border-radius: 9999px;
            font-size: 11px;
            font-weight: 600;
            color: var(--text-muted);
        }

        .badge.os {
            color: var(--primary);
            border-color: rgba(6, 182, 212, 0.4);
            background: rgba(6, 182, 212, 0.1);
        }

        /* Card Elements */
        .card {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 24px;
            box-shadow: 0 8px 30px rgba(0, 0, 0, 0.35);
            margin-bottom: 24px;
        }

        /* Actions Grid */
        .actions-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 12px;
            margin-bottom: 20px;
        }

        .btn-action {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            padding: 14px 16px;
            border-radius: 12px;
            font-weight: 700;
            font-size: 13px;
            cursor: pointer;
            border: 1px solid transparent;
            transition: all 0.2s ease;
            text-decoration: none;
            color: #fff;
        }

        .btn-update {
            background: linear-gradient(135deg, #0284c7, #06b6d4);
            box-shadow: 0 4px 14px rgba(6, 182, 212, 0.3);
        }
        .btn-update:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(6, 182, 212, 0.45);
        }

        .btn-status {
            background: #1f2937;
            border-color: #4b5563;
        }
        .btn-status:hover {
            background: #374151;
            border-color: #6b7280;
        }

        .btn-restart {
            background: #1f2937;
            border-color: #b45309;
            color: #fde68a;
        }
        .btn-restart:hover {
            background: #78350f;
            border-color: var(--amber);
        }

        .btn-backup {
            background: #1f2937;
            border-color: #047857;
            color: #a7f3d0;
        }
        .btn-backup:hover {
            background: #065f46;
            border-color: var(--emerald);
        }

        .btn-action:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none !important;
        }

        /* Terminal Window */
        .terminal-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: #030712;
            border: 1px solid #1f2937;
            border-bottom: none;
            border-top-left-radius: 12px;
            border-top-right-radius: 12px;
            padding: 10px 16px;
        }

        .terminal-dots {
            display: flex;
            gap: 6px;
        }
        .dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }
        .dot-red { background: #ef4444; }
        .dot-yellow { background: #eab308; }
        .dot-green { background: #22c55e; }

        .terminal-title {
            font-family: 'Fira Code', monospace;
            font-size: 11px;
            color: var(--text-muted);
        }

        .terminal-tools {
            display: flex;
            gap: 8px;
        }

        .btn-mini {
            background: #1f2937;
            color: var(--text-muted);
            border: 1px solid #374151;
            font-size: 11px;
            padding: 2px 8px;
            border-radius: 6px;
            cursor: pointer;
        }
        .btn-mini:hover {
            color: #fff;
            background: #374151;
        }

        .terminal-body {
            background: #030712;
            border: 1px solid #1f2937;
            border-bottom-left-radius: 12px;
            border-bottom-right-radius: 12px;
            padding: 16px;
            min-height: 380px;
            max-height: 520px;
            overflow-y: auto;
            font-family: 'Fira Code', monospace;
            font-size: 12.5px;
            line-height: 1.6;
            color: #a7f3d0;
            white-space: pre-wrap;
            word-break: break-all;
        }

        .pulse-live {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #22c55e;
            box-shadow: 0 0 8px #22c55e;
            animation: pulse 1.5s infinite;
            margin-right: 6px;
        }

        @keyframes pulse {
            0% { opacity: 0.4; transform: scale(0.9); }
            50% { opacity: 1; transform: scale(1.15); }
            100% { opacity: 0.4; transform: scale(0.9); }
        }

        .footer {
            text-align: center;
            font-size: 12px;
            color: #64748b;
            padding-top: 16px;
        }

        .footer a {
            color: var(--primary);
            text-decoration: none;
        }
    </style>
</head>
<body>

<div class="container">
    <!-- Header -->
    <div class="header">
        <div class="brand">
            <div class="logo-badge">JT</div>
            <div class="brand-text">
                <h1>JAGAT TECH — Web Console</h1>
                <span>System Updater & Management Console</span>
            </div>
        </div>
        <div class="server-meta">
            <span class="badge os"><?= htmlspecialchars($isWindows ? '🪟 Windows Native' : '🐧 Linux / Armbian') ?></span>
            <span class="badge">Host: <?= htmlspecialchars($serverHost) ?></span>
            <span class="badge">PHP <?= htmlspecialchars($phpVer) ?></span>
        </div>
    </div>

    <!-- Card Dashboard Operasi -->
    <div class="card">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
            <div>
                <h2 style="font-size: 16px; font-weight: 700; color: var(--text-main);">Pusat Kontrol Perintah</h2>
                <p style="font-size: 12px; color: var(--text-muted);">Pilih aksi di bawah untuk mengeksekusi perintah server secara realtime.</p>
            </div>
            <div id="statusIndicator" style="font-size: 12px; color: var(--emerald); font-weight: 600;">
                <span class="pulse-live"></span> Sistem Siap
            </div>
        </div>

        <!-- Tombol Aksi -->
        <div class="actions-grid">
            <button id="btnUpdate" class="btn-action btn-update" onclick="runCommand('update')">
                <span>🔄 Update Sistem Lengkap</span>
            </button>
            <button id="btnStatus" class="btn-action btn-status" onclick="runCommand('status')">
                <span>📊 Cek Status Layanan</span>
            </button>
            <button id="btnRestart" class="btn-action btn-restart" onclick="runCommand('restart')">
                <span>⚡ Restart Semua Layanan</span>
            </button>
            <button id="btnBackup" class="btn-action btn-backup" onclick="runCommand('backup')">
                <span>💾 Backup Data & DB</span>
            </button>
        </div>

        <!-- Terminal Output -->
        <div class="terminal-header">
            <div class="terminal-dots">
                <span class="dot dot-red"></span>
                <span class="dot dot-yellow"></span>
                <span class="dot dot-green"></span>
            </div>
            <div class="terminal-title" id="terminalTitle">console@jagat-tech:~$ siap menerima perintah</div>
            <div class="terminal-tools">
                <button class="btn-mini" onclick="copyTerminal()">Salin Log</button>
                <button class="btn-mini" onclick="clearTerminal()">Bersihkan</button>
            </div>
        </div>
        <div id="terminal" class="terminal-body">Selamat datang di Web Console JAGAT TECH.
Tekan salah satu tombol di atas untuk menjalankan perintah server.
Log eksekusi akan mengalir di sini secara langsung (realtime)...</div>
    </div>
</div>

<div class="footer">
    &copy; <?= date('Y') ?> <a href="https://github.com/kangdaqiq/autoinstal" target="_blank">JAGAT TECH</a> — Auto Installer & Web Console
</div>

<script>
let evtSource = null;
let isRunning = false;

function runCommand(cmdKey) {
    if (isRunning) {
        alert('Ada perintah yang masih berjalan. Harap tunggu hingga selesai.');
        return;
    }

    if (cmdKey === 'update' && !confirm('Jalankan update sistem sekarang? Proses ini akan menarik Git terbaru, update dependensi, migrasi DB, dan restart bot.')) {
        return;
    }

    if (cmdKey === 'restart' && !confirm('Restart seluruh layanan server (Web, WA, Bot)?')) {
        return;
    }

    const terminal = document.getElementById('terminal');
    const title = document.getElementById('terminalTitle');
    const indicator = document.getElementById('statusIndicator');
    const buttons = document.querySelectorAll('.btn-action');

    isRunning = true;
    buttons.forEach(b => b.disabled = true);
    indicator.innerHTML = '<span class="pulse-live" style="background:#06b6d4;box-shadow:0 0 8px #06b6d4;"></span> Menjalankan ' + cmdKey.toUpperCase() + '...';
    title.innerText = 'console@jagat-tech:~$ absen ' + cmdKey + ' (Running)';

    terminal.innerText = '=== MEMULAI EKSEKUSI PERINTAH: ' + cmdKey.toUpperCase() + ' ===\n';

    if (evtSource) {
        evtSource.close();
    }

    evtSource = new EventSource('?action=stream&cmd=' + encodeURIComponent(cmdKey));

    evtSource.onmessage = function(e) {
        terminal.innerText += e.data + '\n';
        terminal.scrollTop = terminal.scrollHeight;

        if (e.data.includes('[SELESAI]') || e.data.includes('[ERROR]')) {
            finishExecution(e.data.includes('[SELESAI]') ? 'Selesai' : 'Gagal');
        }
    };

    evtSource.onerror = function() {
        finishExecution('Koneksi Selesai / Terputus');
    };
}

function finishExecution(statusText) {
    if (evtSource) {
        evtSource.close();
        evtSource = null;
    }
    isRunning = false;
    document.querySelectorAll('.btn-action').forEach(b => b.disabled = false);
    const indicator = document.getElementById('statusIndicator');
    const title = document.getElementById('terminalTitle');

    indicator.innerHTML = '<span class="pulse-live"></span> Sistem Siap (' + statusText + ')';
    title.innerText = 'console@jagat-tech:~$ siap menerima perintah';
}

function clearTerminal() {
    if (!isRunning) {
        document.getElementById('terminal').innerText = 'Konsol telah dibersihkan.\n';
    }
}

function copyTerminal() {
    const text = document.getElementById('terminal').innerText;
    navigator.clipboard.writeText(text).then(() => {
        alert('Log berhasil disalin ke clipboard!');
    }).catch(() => {
        alert('Gagal menyalin log.');
    });
}
</script>

</body>
</html>
