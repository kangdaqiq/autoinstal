<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class SystemUpdateController extends Controller
{
    public function index()
    {
        $isWindows = (PHP_OS_FAMILY === 'Windows');
        $serverHost = gethostname() ?: 'JagatServer';
        $serverOS = PHP_OS . ' (' . php_uname('m') . ')';
        $phpVer = PHP_VERSION;

        return view('system.update', compact('isWindows', 'serverHost', 'serverOS', 'phpVer'));
    }

    public function stream(Request $request)
    {
        @ini_set('max_execution_time', 0);
        @set_time_limit(0);

        $cmdKey = preg_replace('/[^a-zA-Z0-9_\-]/', '', $request->query('cmd', 'status'));

        $validCommands = [
            'update'  => 'update',
            'status'  => 'status',
            'restart' => 'restart web',
            'backup'  => 'backup',
            'log_web' => 'logs',
            'log_wa'  => 'logs wa',
            'log_bot' => 'logs bot',
        ];

        if (!isset($validCommands[$cmdKey])) {
            return response()->json(['error' => 'Perintah tidak valid'], 400);
        }

        $subCommand = $validCommands[$cmdKey];
        $isWindows = (PHP_OS_FAMILY === 'Windows');

        $response = new StreamedResponse(function () use ($cmdKey, $subCommand, $isWindows) {
            header('Content-Type: text/event-stream');
            header('Cache-Control: no-cache, no-store, must-revalidate');
            header('Pragma: no-cache');
            header('X-Accel-Buffering: no');

            while (ob_get_level() > 0) {
                ob_end_clean();
            }

            // Auto-Sync skrip CLI dari GitHub saat tombol update ditekan
            if ($cmdKey === 'update') {
                echo "data: [AUTO-SYNC] Memeriksa pembaruan skrip CLI dari GitHub...\n\n";
                @ob_flush(); flush();

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
                        @ob_flush(); flush();
                    }
                } else {
                    $latestSh = @file_get_contents('https://raw.githubusercontent.com/kangdaqiq/autoinstal/main/scripts/absen-cli.sh', false, $ctx);
                    if ($latestSh && strlen($latestSh) > 1000) {
                        $tmpFile = tempnam(sys_get_temp_dir(), 'absen_');
                        if ($tmpFile) {
                            file_put_contents($tmpFile, $latestSh);
                            @shell_exec("sudo cp -f {$tmpFile} /usr/local/bin/absen");
                            @shell_exec("sudo chmod +x /usr/local/bin/absen");
                            @unlink($tmpFile);
                            echo "data: [AUTO-SYNC] Skrip /usr/local/bin/absen berhasil diperbarui ke rilis terbaru.\n\n";
                            @ob_flush(); flush();
                        }
                    }
                }
            }

            if ($isWindows) {
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
                // Linux / Armbian Execution
                $absenBin = '/usr/local/bin/absen';
                if (!file_exists($absenBin)) {
                    $whichAbsen = trim(@shell_exec('which absen 2>/dev/null') ?: '');
                    if ($whichAbsen) {
                        $absenBin = $whichAbsen;
                    }
                }
                $execCommand = 'sudo -n ' . $absenBin . ' ' . $subCommand . ' 2>&1';
            }

            echo "data: [INFO] Memulai perintah: " . $subCommand . " (" . ($isWindows ? 'Windows Native' : 'Linux / Armbian') . ")...\n\n";
            @ob_flush(); flush();

            $descriptors = [
                0 => ["pipe", "r"],
                1 => ["pipe", "w"],
                2 => ["pipe", "w"],
            ];

            @putenv('JAGAT_WEB_INVOCATION=1');
            $process = proc_open($execCommand, $descriptors, $pipes);
            $sudoErrorDetected = false;

            if (is_resource($process)) {
                fclose($pipes[0]);
                stream_set_blocking($pipes[1], 0);
                stream_set_blocking($pipes[2], 0);

                while (true) {
                    $read = [$pipes[1], $pipes[2]];
                    $write = null;
                    $except = null;

                    $numChanged = @stream_select($read, $write, $except, 0, 200000);
                    if ($numChanged > 0) {
                        foreach ($read as $pipe) {
                            while (($line = fgets($pipe)) !== false) {
                                $clean = preg_replace('/\x1b\[[0-9;]*m/', '', $line);
                                $clean = trim($clean, "\r\n");
                                if ($clean !== '') {
                                    if (stripos($clean, 'password is required') !== false || stripos($clean, 'terminal is required') !== false) {
                                        $sudoErrorDetected = true;
                                    }
                                    echo "data: " . $clean . "\n\n";
                                    @ob_flush(); flush();
                                }
                            }
                        }
                    }

                    $status = proc_get_status($process);
                    if (!$status['running']) {
                        while (($line = fgets($pipes[1])) !== false) {
                            $clean = preg_replace('/\x1b\[[0-9;]*m/', '', $line);
                            $clean = trim($clean, "\r\n");
                            if ($clean !== '') {
                                if (stripos($clean, 'password is required') !== false || stripos($clean, 'terminal is required') !== false) {
                                    $sudoErrorDetected = true;
                                }
                                echo "data: " . $clean . "\n\n";
                            }
                        }
                        while (($line = fgets($pipes[2])) !== false) {
                            $clean = preg_replace('/\x1b\[[0-9;]*m/', '', $line);
                            $clean = trim($clean, "\r\n");
                            if ($clean !== '') {
                                if (stripos($clean, 'password is required') !== false || stripos($clean, 'terminal is required') !== false) {
                                    $sudoErrorDetected = true;
                                }
                                echo "data: " . $clean . "\n\n";
                            }
                        }
                        break;
                    }
                }

                fclose($pipes[1]);
                fclose($pipes[2]);
                $exitCode = proc_close($process);

                if ($sudoErrorDetected && !$isWindows) {
                    $webUser = trim(@shell_exec('whoami 2>/dev/null') ?: 'www-data');
                    echo "data: \n\n";
                    echo "data: ============================================================\n\n";
                    echo "data: [KENDALA IZIN SUDO DI ARMBIAN / LINUX]\n\n";
                    echo "data: Web server berjalan sebagai user '{$webUser}' dan membutuhkan\n\n";
                    echo "data: izin NOPASSWD untuk menjalankan /usr/local/bin/absen.\n\n";
                    echo "data: \n\n";
                    echo "data: Silakan buka terminal SSH Armbian Anda dan jalankan perintah ini:\n\n";
                    echo "data:   echo \"{$webUser} ALL=(ALL) NOPASSWD: /usr/local/bin/absen\" | sudo tee /etc/sudoers.d/jagat-absen-web\n\n";
                    echo "data:   sudo chmod 0440 /etc/sudoers.d/jagat-absen-web\n\n";
                    echo "data: \n\n";
                    echo "data: Setelah itu, klik kembali tombol perintah di atas.\n\n";
                    echo "data: ============================================================\n\n";
                    @ob_flush(); flush();
                }

                echo "data: [SELESAI] Perintah selesai dieksekusi dengan kode keluar: " . $exitCode . "\n\n";
            } else {
                echo "data: [ERROR] Gagal membuka proses terminal di sistem server.\n\n";
            }

            @ob_flush(); flush();
        });

        $response->headers->set('Content-Type', 'text/event-stream');
        $response->headers->set('Cache-Control', 'no-cache, no-store, must-revalidate');
        $response->headers->set('X-Accel-Buffering', 'no');

        return $response;
    }
}
