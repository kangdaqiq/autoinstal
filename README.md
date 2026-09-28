# 🚀 JAGAT TECH — Auto Installer Server, Web Absensi & WhatsApp Gateway (GOWA)

Auto Installer resmi dari **JAGAT TECH** untuk memasang seluruh kebutuhan server (*Nginx, PHP 8.3, MariaDB, Composer, Golang*), men-deploy aplikasi **Web Absensi Multi-Tenant** via Git, serta memasang **WhatsApp Gateway (GOWA Latest Release)** secara otomatis pada **Debian x86_64** dan **Armbian Amlogic S905X** (STB B860H / HG680P / TV Box).

---

## 🖥️ Target Perangkat yang Didukung

1. **Debian x86_64 (amd64):** PC Server, VPS Cloud (DigitalOcean, Linode, Niagahoster, AWS, dsb).
2. **Armbian Amlogic S905X (arm64 / armhf):** STB B860H, Fiberhome HG680P, X96 Mini, TX3 Mini, dsb.

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
   - Otomatis mengunduh modul Go dan mengompilasi binary `bot_wa` menggunakan Golang yang terpasang.
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
- **Default Password:** `JagatTech123@`
- **Database MariaDB:** User `absen_user` | Password `JagatTech123@` | DB `absen_jagat`
- **WhatsApp Gateway:**
  - **Port:** `3000`
  - **Basic Auth:** User `admin` | Password `JagatTech123@`
  - **Webhook URL:** `http://127.0.0.1:5000/webhook` (meneruskan pesan masuk ke bot absensi)

---

## 🚀 Cara Instalasi di Server / STB

1. Masuk ke terminal VPS / STB Armbian Anda via SSH sebagai root:
   ```bash
   ssh root@IP_PERANGKAT_ANDA
   ```

2. Jalankan installer:
   ```bash
   sudo bash install.sh
   ```

3. Tekan **[ENTER]** untuk menggunakan setelan default (termasuk password default `JagatTech123@`).
4. Tunggu beberapa menit hingga proses selesai!

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
5. Menarik commit terbaru WhatsApp Bot Go via `git pull` & mengompilasi ulang binary (`go build`).
6. Menarik commit terbaru Telegram Bot Go via `git pull` & mengompilasi ulang binary (`go build`).
7. Me-restart queue worker & seluruh bot service.

---

## 🛠️ Perintah Pintas Lainnya

```bash
absen status        # Cek status kesehatan Nginx, PHP, MariaDB, WA Gateway, Bot WA, Bot Tele, dan Queue
absen restart       # Restart seluruh service server, WA, dan kedua Bot
absen logs          # Pantau log Laravel realtime
absen logs bot      # Pantau log WhatsApp Bot Go realtime
absen logs tele     # Pantau log Telegram Bot Go realtime
absen logs wa       # Pantau log WhatsApp Gateway
absen logs queue    # Pantau log antrian pesan / background worker
absen logs nginx    # Pantau error log web server
```
