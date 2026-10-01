# 🚀 JAGAT TECH — Auto Installer Server, Web Absensi & WhatsApp Gateway (GOWA)

Auto Installer resmi dari **JAGAT TECH** untuk memasang seluruh kebutuhan server (*Nginx, PHP 8.3, MariaDB, Composer, Golang*), men-deploy aplikasi **Web Absensi Multi-Tenant** via Git, serta memasang **WhatsApp Gateway (GOWA Latest Release)** secara otomatis pada **Debian x86_64** dan **Armbian Amlogic S905X** (STB B860H / HG680P / TV Box).

---

## 🖥️ Target Perangkat yang Didukung

1. **Debian x86_64 (amd64):** PC Server, VPS Cloud (DigitalOcean, Linode, Niagahoster, AWS, dsb).
2. **Armbian Amlogic S905X (arm64 / armhf):** STB B860H, Fiberhome HG680P, X96 Mini, TX3 Mini, dsb.
3. **Microsoft Windows (x64):** Windows 10, Windows 11, dan Windows Server 2019/2022 (Native via PowerShell & Windows Services NSSM atau WSL2).

---

## 🌟 Komponen yang Diinstal Otomatis

1. **Core Server Stack:**
   - **Nginx Web Server:** Terkonfigurasi dengan VirtualHost Laravel dan reverse proxy WhatsApp.
   - **PHP 8.3 (FPM & CLI):** Ekstensi lengkap (`pdo_mysql, mbstring, bcmath, gd, zip, intl, xml, curl, opcache, pcntl`).
     - *Khusus S905X:* FPM disetel ke mode `ondemand` hemat daya/RAM dan `memory_limit = 256M`.
   - **MariaDB Database:** Otomatis membuat database `absen_jagat`, user `absen_user`, dan optimasi hemat tulis eMMC untuk STB S905X.
   - **Composer 2.x & Golang:** Terpasang global di `/usr/local/bin`.
   - **Auto-Swap 2GB:** Aktif otomatis jika RAM < 2GB agar tidak kehabisan memori (OOM).
2. **Web Absensi (Git-Based):**
   - Lokasi: `/var/www/web`
   - Repositori: `https://github.com/kangdaqiq/absen_multi.git`
   - Menggunakan template `.env.selfhosted.example` yang otomatis tersambung ke database dan API WhatsApp.
   - Migrasi database (`php artisan migrate`), storage link, dan cache optimize otomatis.
   - Antrian background (`absen-queue` via Supervisor) & cron scheduler Laravel.
3. **WhatsApp Gateway (GOWA Auto-Latest):**
   - Lokasi: `/var/www/whatsapp`
   - Mendeteksi rilis terbaru otomatis dari repositori `aldinokemal/go-whatsapp-web-multidevice`.
   - Mengunduh paket ZIP sesuai arsitektur (`linux_arm64.zip` untuk Armbian S905X atau `linux_amd64.zip` untuk x86_64).
   - Ekstrak binary ke `/var/www/whatsapp/whatsapp` & jalankan Systemd Service (`whatsapp.service`) di port `3000` dengan Basic Auth (`admin:JagatTech123@`) dan Webhook ke bot.
4. **WhatsApp Bot Go (Daemon Absensi):**
   - Lokasi: `/var/www/bot-go` (dan symlink `/var/www/bot-wa`)
   - Repositori: `https://github.com/kangdaqiq/bot-go.git`
   - Mengunduh binary `bot_wa` yang sudah di-compile langsung dari GitHub Release (x86 & ARM64), tanpa membebani CPU/RAM perangkat.
   - Dijalankan sebagai Systemd Service (`bot_wa.service`) di port `5000` dan menerima event webhook dari WhatsApp Gateway.
5. **Telegram Bot Go (Multi-Tenant Bot):**
   - Lokasi: `/var/www/bot-tele`
   - Repositori: `https://github.com/kangdaqiq/bot_tele.git`
   - Mengambil data token bot secara dinamis dari tabel `schools` di database MariaDB.
   - Dijalankan sebagai Systemd Service (`bot_tele.service`) yang aktif di background.
6. **CLI Utility `absen` & Update Mudah:**
   - Command `/usr/local/bin/absen` untuk cek status, log realtime, restart, dan update via Git untuk seluruh komponen.

---

## 📁 Struktur Direktori Terpadu (`/var/www`)

```
/var/www/
├── web/              <-- Aplikasi Web Absensi Laravel (DocumentRoot Nginx: web/public)
├── bot-go/           <-- Source code & binary bot WhatsApp Go
├── bot-wa/           <-- Symlink ke bot-go (memudahkan akses)
├── whatsapp/         <-- Binary & data sesi WhatsApp Gateway (GOWA)
└── bot-tele/         <-- Source code & binary bot Telegram Go
```

---

## 🔐 Akun & Parameter Default

Installer ini menggunakan setelan default yang seragam saat Anda menekan **[ENTER]**:
- **Domain / Host:** `localhost` (bisa diakses via `http://localhost` maupun `http://IP_SERVER` di LAN)
- **Default Password:** `JagatTech123@`
- **Database MariaDB:** User `absen_user` | Password `JagatTech123@` | DB `absen_jagat`
- **WhatsApp Gateway:**
  - **Port:** `3000`
  - **Basic Auth:** User `admin` | Password `JagatTech123@`
  - **Webhook URL:** `http://127.0.0.1:5000/webhook` (meneruskan pesan masuk ke bot absensi)

---

## 🚀 Cara Instalasi di Server / STB

Masuk ke terminal VPS / STB Armbian Anda via SSH sebagai root:
```bash
ssh root@IP_PERANGKAT_ANDA
```

Pilih salah satu metode instalasi di bawah ini:

### ⚡ Metode 1: One-Line Quick Install (Paling Praktis & Cepat)
Cukup copy dan paste satu baris perintah ini ke terminal. Skrip akan langsung diunduh dan dijalankan secara otomatis:

```bash
curl -sSL -H 'Cache-Control: no-cache' "https://raw.githubusercontent.com/kangdaqiq/autoinstal/main/quick-install.sh?v=$(date +%s)" | sudo bash
```

> 💡 **Info:** Parameter `Cache-Control` dan `?v=...` memastikan Anda selalu mendapatkan versi terbaru tanpa tertahan cache GitHub CDN.

---

### 📦 Metode 2: Clone via Git (Manual)
Gunakan metode ini jika Anda ingin memeriksa skrip atau menjalankan instalasi dari repositori lokal:

```bash
# 1. Clone repositori
git clone https://github.com/kangdaqiq/autoinstal.git

# 2. Masuk ke direktori
cd autoinstal

# 3. Beri izin eksekusi & jalankan installer
chmod +x install.sh
sudo bash install.sh
```

---

### 🤖 Metode 3: Mode Unattended (Otomatis Penuh Tanpa Tanya)
Jika Anda ingin instalasi berjalan otomatis penuh menggunakan setelan default (`JagatTech123@`) tanpa menunggu konfirmasi tombol ENTER:

- **Via Quick-Install One-Liner:**
  ```bash
  curl -sSL -H 'Cache-Control: no-cache' "https://raw.githubusercontent.com/kangdaqiq/autoinstal/main/quick-install.sh?v=$(date +%s)" | sudo bash -s -- -y
  ```

- **Via Git Clone:**
  ```bash
  sudo bash install.sh -y
  ```

---

### 📝 Langkah Saat Installer Berjalan:
1. Skrip akan memeriksa hak akses root, sistem operasi (Debian/Armbian), dan arsitektur CPU (x86_64 / arm64).
2. Anda akan diminta mengonfirmasi password dan setelan (Cukup tekan **[ENTER]** untuk menggunakan setelan rekomendasi default).
3. Installer akan menampilkan animasi progress bar / spinner secara realtime untuk setiap komponen yang sedang diunduh dan dipasang.
4. Setelah selesai, seluruh URL akses, port, dan kredensial akan ditampilkan di layar.

---

## 🪟 Cara Instalasi di Windows (Windows 10 / 11 / Server)

Tersedia 2 metode instalasi di Windows:

### 🌟 Rekomendasi 1: Native Windows (Paling Praktis Tanpa Virtualisasi)
Metode ini berjalan langsung di Windows tanpa memerlukan fitur virtualisasi/Hyper-V, sangat ringan, dan seluruh background service didaftarkan ke Windows Service via NSSM (otomatis jalan saat PC booting):

1. **Jalankan Installer:**
   - Cukup **Klik Ganda (Double-Click)** file:
     ```
     install.bat
     ```
   - *Atau via PowerShell (Run as Administrator):*
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
     ```
2. **Apa yang dilakukan installer Windows otomatis:**
   - Memeriksa atau memasang **Git**, **PHP 8.3/8.2**, **Composer**, dan **MariaDB/MySQL**.
   - Menyiapkan **Nginx for Windows** terkonfigurasi dengan VirtualHost Laravel & reverse proxy WhatsApp.
   - Meng-clone repositori Web Absensi (`absen_multi`), konfigurasi `.env`, migrasi database, dan optimize.
   - Mengunduh rilis resmi **WhatsApp Gateway (GOWA Windows)** dan mengekstrak `whatsapp.exe`.
   - Mengunduh binary Windows untuk **WhatsApp Bot Go (`bot_wa.exe`)** dan **Telegram Bot Go (`bot_tele.exe`)**.
   - Mendaftarkan Windows Background Services (`Jagat-Nginx`, `Jagat-PHP-CGI`, `Jagat-Queue`, `Jagat-WhatsApp`, `Jagat-BotWA`, `Jagat-BotTele`) sehingga otomatis aktif di latar belakang saat komputer dinyalakan.
   - Membuat shortcut di Desktop: *Web Absensi*, *WhatsApp Gateway Portal*, dan *Jagat Server Control*.
   - Mendaftarkan perintah CLI `absen` ke CMD / PowerShell sistem.

---

### 🐧 Rekomendasi 2: WSL2 (Windows Subsystem for Linux - 100% Linux Parity)
Metode ini direkomendasikan jika PC Windows Anda mendukung virtualisasi dan Anda ingin lingkungan produksi yang 100% identik dengan server Debian/Ubuntu Linux (Nginx socket, PHP-FPM, Supervisor, Systemd):

1. **Klik Ganda (Double-Click)** file:
   ```
   install-wsl.bat
   ```
2. Skrip akan menyiapkan distro Ubuntu di WSL2, menjalankan installer Linux Jagat Tech di dalamnya, dan mengatur port-forwarding (port 80, 3000, 5000) ke Windows host.

---

## 📱 Cara Menghubungkan WhatsApp (Scan QR)

Setelah proses instalasi selesai:

1. Buka browser di laptop atau HP yang berada di jaringan yang sama:
   ```
   http://IP_SERVER_ATAU_STB:3000
   ```
2. Masukkan akun yang ditampilkan di ringkasan instalasi:
   - **Username:** `admin`
   - **Password:** *(Password yang diatur saat instalasi)*
3. Klik tombol **Login / Scan**.
4. Buka aplikasi WhatsApp di HP Anda (`Perangkat Tertaut` / `Linked Devices`) lalu scan kode QR di layar.
5. WhatsApp Gateway berhasil terhubung dan siap mengirimkan notifikasi absensi!

---

## 🔄 Cara Update Web Absensi & Kedua Bot (Git Pull Otomatis)

Kapan saja ada pembaruan kode di GitHub (baik pada Web Absen, Bot WhatsApp, atau Bot Telegram), Anda cukup menjalankan satu baris perintah ini di terminal:

```bash
absen update
```

Perintah di atas secara otomatis akan:
1. Menarik commit terbaru Web Absen via `git pull`.
2. Memperbarui paket PHP (`composer install`).
3. Menjalankan migrasi database baru (`php artisan migrate`).
4. Membersihkan & mengoptimalkan cache framework (`php artisan optimize`).
5. Mengunduh dan memperbarui binary compiled terbaru WhatsApp Bot Go dari GitHub Release.
6. Mengunduh dan memperbarui binary compiled terbaru Telegram Bot Go dari GitHub Release.
7. Me-restart queue worker & seluruh bot service.

---

## 🛠️ Perintah Pintas Lainnya

```bash
absen status        # Cek status kesehatan Nginx, PHP, MariaDB, WA Gateway, Bot WA, Bot Tele, dan Queue
absen restart       # Restart seluruh service server, WA, dan kedua Bot
absen swap-delete   # Hapus file swap 2GB untuk melegakan kembali ruang penyimpanan internal eMMC
absen swap-create   # Buat kembali swap file 2GB jika sewaktu-waktu dibutuhkan (eMMC Safe)
absen logs          # Pantau log Laravel realtime
absen logs bot      # Pantau log WhatsApp Bot Go realtime
absen logs tele     # Pantau log Telegram Bot Go realtime
absen logs wa       # Pantau log WhatsApp Gateway
absen logs queue    # Pantau log antrian pesan / background worker
absen logs nginx    # Pantau error log web server
```
