@extends('layouts.app')

@section('title', 'Update Sistem & Web Console')

@section('content')
<style>
    /* Styling Tombol Aksi Sistem (Rich Vibrant Colors & Shadows) */
    .btn-action-sys {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.65rem;
        padding: 0.95rem 1.25rem;
        border-radius: 0.85rem;
        font-weight: 700;
        font-size: 0.875rem;
        color: #ffffff !important;
        cursor: pointer;
        transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.25);
        position: relative;
        overflow: hidden;
    }

    .btn-action-sys svg {
        width: 1.15rem;
        height: 1.15rem;
        flex-shrink: 0;
        stroke: #ffffff;
        filter: drop-shadow(0 1px 1px rgba(0, 0, 0, 0.3));
    }

    .btn-action-sys:hover {
        transform: translateY(-2.5px);
        filter: brightness(1.12);
    }

    .btn-action-sys:active {
        transform: translateY(0);
        filter: brightness(0.95);
    }

    .btn-action-sys:disabled {
        opacity: 0.55;
        cursor: not-allowed;
        transform: none !important;
        filter: grayscale(0.5);
    }

    /* 1. Update: Vivid Cyber Cyan - Blue Gradient */
    .btn-sys-update {
        background: linear-gradient(135deg, #0284c7 0%, #06b6d4 100%) !important;
        border: 1px solid rgba(6, 182, 212, 0.6) !important;
        box-shadow: 0 6px 18px rgba(6, 182, 212, 0.42) !important;
    }
    .btn-sys-update:hover {
        box-shadow: 0 8px 25px rgba(6, 182, 212, 0.58) !important;
    }

    /* 2. Status: Deep Indigo - Royal Purple Gradient */
    .btn-sys-status {
        background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%) !important;
        border: 1px solid rgba(124, 58, 237, 0.6) !important;
        box-shadow: 0 6px 18px rgba(99, 102, 241, 0.42) !important;
    }
    .btn-sys-status:hover {
        box-shadow: 0 8px 25px rgba(99, 102, 241, 0.58) !important;
    }

    /* 3. Restart: Fire Amber - Orange Gradient */
    .btn-sys-restart {
        background: linear-gradient(135deg, #ea580c 0%, #f59e0b 100%) !important;
        border: 1px solid rgba(245, 158, 11, 0.6) !important;
        box-shadow: 0 6px 18px rgba(234, 88, 12, 0.42) !important;
    }
    .btn-sys-restart:hover {
        box-shadow: 0 8px 25px rgba(234, 88, 12, 0.58) !important;
    }

    /* 4. Backup: Rich Emerald - Teal Gradient */
    .btn-sys-backup {
        background: linear-gradient(135deg, #059669 0%, #10b981 100%) !important;
        border: 1px solid rgba(16, 185, 129, 0.6) !important;
        box-shadow: 0 6px 18px rgba(16, 185, 129, 0.42) !important;
    }
    .btn-sys-backup:hover {
        box-shadow: 0 8px 25px rgba(16, 185, 129, 0.58) !important;
    }

    /* Meta Cards Accent Borders */
    .meta-card-host { border-left: 4px solid #06b6d4 !important; }
    .meta-card-php { border-left: 4px solid #6366f1 !important; }
    .meta-card-os { border-left: 4px solid #f59e0b !important; }
    .meta-card-cli { border-left: 4px solid #10b981 !important; }
</style>

<div class="space-y-6">
    <!-- Header Page -->
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
            <h2 class="text-xl font-bold text-gray-800 dark:text-white/90 flex items-center gap-2.5">
                <span class="inline-flex items-center justify-center w-9 h-9 rounded-xl bg-cyan-500/10 text-cyan-600 dark:text-cyan-400">
                    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                </span>
                Update Sistem & Web Console
            </h2>
            <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                Pusat kendali update source code via Git, database migration, build bot terbaru, dan manajemen background service.
            </p>
        </div>

        <div class="flex items-center gap-3">
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold {{ $isWindows ? 'bg-sky-100 text-sky-800 dark:bg-sky-950/60 dark:text-sky-300' : 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300' }}">
                <span>{{ $isWindows ? '🪟 Windows Native' : '🐧 Linux / Armbian' }}</span>
            </span>
            <a href="{{ url('/update.php') }}" target="_blank" class="inline-flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 dark:bg-gray-800 dark:text-gray-200 dark:border-gray-700 dark:hover:bg-gray-700 transition-colors shadow-sm">
                <span>Buka Tab Penuh</span>
                <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                </svg>
            </a>
        </div>
    </div>

    <!-- Server Meta Cards -->
    <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div class="p-4 bg-white dark:bg-gray-800/80 rounded-xl border border-gray-200 dark:border-gray-700/60 shadow-sm meta-card-host">
            <div class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Hostname Server</div>
            <div class="text-sm font-bold text-gray-800 dark:text-white mt-1 truncate">{{ $serverHost }}</div>
        </div>
        <div class="p-4 bg-white dark:bg-gray-800/80 rounded-xl border border-gray-200 dark:border-gray-700/60 shadow-sm meta-card-php">
            <div class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Versi PHP Server</div>
            <div class="text-sm font-bold text-gray-800 dark:text-white mt-1">PHP {{ $phpVer }}</div>
        </div>
        <div class="p-4 bg-white dark:bg-gray-800/80 rounded-xl border border-gray-200 dark:border-gray-700/60 shadow-sm meta-card-os">
            <div class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Sistem Operasi</div>
            <div class="text-sm font-bold text-gray-800 dark:text-white mt-1 truncate">{{ $serverOS }}</div>
        </div>
        <div class="p-4 bg-white dark:bg-gray-800/80 rounded-xl border border-gray-200 dark:border-gray-700/60 shadow-sm meta-card-cli">
            <div class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Engine Eksekusi</div>
            <div class="text-sm font-bold text-emerald-600 dark:text-emerald-400 mt-1">JAGAT CLI `absen`</div>
        </div>
    </div>

    <!-- Main Controller Card -->
    <div class="bg-white dark:bg-gray-800/90 rounded-2xl border border-gray-200 dark:border-gray-700/70 p-6 shadow-sm">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between pb-5 mb-5 border-b border-gray-100 dark:border-gray-700/60 gap-3">
            <div>
                <h3 class="font-bold text-gray-900 dark:text-white text-base">Tombol Perintah Sistem</h3>
                <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">Klik tombol berwarna di bawah untuk mengeksekusi operasi server secara realtime.</p>
            </div>
            <div id="liveStatus" class="inline-flex items-center gap-2 text-xs font-bold text-emerald-600 dark:text-emerald-400">
                <span class="relative flex h-2.5 w-2.5">
                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
                </span>
                <span>Sistem Siap</span>
            </div>
        </div>

        <!-- 4 Vibrant Action Buttons -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5 mb-6">
            <!-- 1. Update (Vivid Cyan-Blue Gradient) -->
            <button type="button" onclick="executeSysCommand('update')" class="btn-action-sys btn-sys-update">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <span>Update Sistem Lengkap</span>
            </button>

            <!-- 2. Status (Deep Indigo-Purple Gradient) -->
            <button type="button" onclick="executeSysCommand('status')" class="btn-action-sys btn-sys-status">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
                <span>Cek Status Layanan</span>
            </button>

            <!-- 3. Restart (Fire Amber-Orange Gradient) -->
            <button type="button" onclick="executeSysCommand('restart')" class="btn-action-sys btn-sys-restart">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
                <span>Restart Semua Service</span>
            </button>

            <!-- 4. Backup (Rich Emerald-Teal Gradient) -->
            <button type="button" onclick="executeSysCommand('backup')" class="btn-action-sys btn-sys-backup">
                <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
                </svg>
                <span>Backup Data & DB</span>
            </button>
        </div>

        <!-- Terminal Output Screen -->
        <div class="rounded-xl overflow-hidden border border-gray-900 bg-gray-950 shadow-2xl">
            <div class="flex items-center justify-between px-4 py-2.5 bg-gray-900 border-b border-gray-800 text-xs">
                <div class="flex items-center gap-2">
                    <span class="w-2.5 h-2.5 rounded-full bg-red-500 inline-block"></span>
                    <span class="w-2.5 h-2.5 rounded-full bg-yellow-500 inline-block"></span>
                    <span class="w-2.5 h-2.5 rounded-full bg-green-500 inline-block"></span>
                    <span id="termHeader" class="ml-2 font-mono text-gray-300 font-medium">console@jagat-tech:~$ siap menerima perintah</span>
                </div>
                <div class="flex items-center gap-2">
                    <button type="button" onclick="copyConsoleLog()" class="px-2.5 py-1 text-[11px] font-semibold text-gray-300 hover:text-white bg-gray-800 hover:bg-gray-700 rounded-md transition-colors border border-gray-700">Salin Log</button>
                    <button type="button" onclick="clearConsoleLog()" class="px-2.5 py-1 text-[11px] font-semibold text-gray-300 hover:text-white bg-gray-800 hover:bg-gray-700 rounded-md transition-colors border border-gray-700">Bersihkan</button>
                </div>
            </div>
            <pre id="consoleOutput" class="p-4 font-mono text-xs leading-relaxed text-emerald-400 h-96 overflow-y-auto whitespace-pre-wrap break-all select-text" style="font-family: 'Fira Code', Consolas, Monaco, monospace; background: #050811;">Selamat datang di Konsol Update Sistem JAGAT TECH.
Tekan salah satu tombol perintah berwarna di atas untuk memulai eksekusi di server.
Log pembaruan akan mengalir di sini secara realtime...</pre>
        </div>
    </div>
</div>

<script>
let streamSource = null;
let commandRunning = false;

function executeSysCommand(cmdKey) {
    if (commandRunning) {
        alert('Ada perintah yang masih berjalan. Harap tunggu hingga proses selesai.');
        return;
    }

    if (cmdKey === 'update' && !confirm('Jalankan update sistem sekarang? Proses ini akan menarik Git terbaru, mengupdate dependensi, migrasi database, dan restart bot.')) {
        return;
    }

    if (cmdKey === 'restart' && !confirm('Restart seluruh service server (Web, WhatsApp, Bot)?')) {
        return;
    }

    const consoleBox = document.getElementById('consoleOutput');
    const termHeader = document.getElementById('termHeader');
    const liveStatus = document.getElementById('liveStatus');
    const buttons = document.querySelectorAll('.btn-action-sys');

    commandRunning = true;
    buttons.forEach(b => {
        b.disabled = true;
    });

    liveStatus.innerHTML = `
        <span class="relative flex h-2.5 w-2.5">
            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-cyan-400 opacity-75"></span>
            <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-cyan-500"></span>
        </span>
        <span class="text-cyan-600 dark:text-cyan-400 font-bold">Menjalankan ${cmdKey.toUpperCase()}...</span>
    `;

    termHeader.innerText = `console@jagat-tech:~$ absen ${cmdKey} (Running)`;
    consoleBox.innerText = `=== MEMULAI EKSEKUSI PERINTAH: ${cmdKey.toUpperCase()} ===\n`;

    if (streamSource) {
        streamSource.close();
    }

    const streamUrl = "{{ route('system.update.stream') }}?cmd=" + encodeURIComponent(cmdKey);
    streamSource = new EventSource(streamUrl);

    streamSource.onmessage = function(e) {
        consoleBox.innerText += e.data + '\n';
        consoleBox.scrollTop = consoleBox.scrollHeight;

        if (e.data.includes('[SELESAI]') || e.data.includes('[ERROR]')) {
            finishSysCommand(e.data.includes('[SELESAI]') ? 'Selesai' : 'Gagal');
        }
    };

    streamSource.onerror = function() {
        finishSysCommand('Koneksi Ditutup');
    };
}

function finishSysCommand(statusText) {
    if (streamSource) {
        streamSource.close();
        streamSource = null;
    }
    commandRunning = false;
    document.querySelectorAll('.btn-action-sys').forEach(b => {
        b.disabled = false;
    });

    const liveStatus = document.getElementById('liveStatus');
    const termHeader = document.getElementById('termHeader');

    liveStatus.innerHTML = `
        <span class="relative flex h-2.5 w-2.5">
            <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
        </span>
        <span class="text-emerald-600 dark:text-emerald-400 font-bold">Sistem Siap (${statusText})</span>
    `;
    termHeader.innerText = 'console@jagat-tech:~$ siap menerima perintah';
}

function clearConsoleLog() {
    if (!commandRunning) {
        document.getElementById('consoleOutput').innerText = 'Konsol telah dibersihkan.\n';
    }
}

function copyConsoleLog() {
    const text = document.getElementById('consoleOutput').innerText;
    navigator.clipboard.writeText(text).then(() => {
        alert('Log konsol berhasil disalin ke clipboard!');
    }).catch(() => {
        alert('Gagal menyalin log.');
    });
}
</script>
@endsection
