#!/usr/bin/env bash
# ==============================================================================
#  CLI UTILITY JAGAT TECH - MANAJEMEN & UPDATE GIT SISTEM ABSENSI
# ==============================================================================
APP_DIR="/var/www/web"
BOT_WA_DIR="/var/www/bot-go"
BOT_TELE_DIR="/var/www/bot-tele"
WA_DIR="/var/www/whatsapp"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

check_service() {
    local label="$1"
    local svc="$2"
    local note="$3"

    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        local pid
        pid=$(systemctl show -p MainPID --value "$svc" 2>/dev/null)
        if [ -n "$pid" ] && [ "$pid" != "0" ]; then
            printf "  ${GREEN}✔${NC} %-26s : ${GREEN}AKTIF (Running - PID %s)${NC} %s\n" "$label" "$pid" "${note}"
        else
            printf "  ${GREEN}✔${NC} %-26s : ${GREEN}AKTIF (Running)${NC} %s\n" "$label" "${note}"
        fi
    elif systemctl is-enabled "$svc" &>/dev/null || systemctl status "$svc" &>/dev/null; then
        printf "  ${RED}✖${NC} %-26s : ${RED}MATI (Stopped / Inactive)${NC}\n" "$label"
    else
        printf "  ${YELLOW}-${NC} %-26s : ${YELLOW}Non-aktif / Tidak terpasang${NC}\n" "$label"
    fi
}

restart_service() {
    local label="$1"
    local svc="$2"

    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}"; then
        if systemctl restart "$svc" 2>/dev/null; then
            printf "  • %-36s ${GREEN}[OK]${NC}\n" "$label..."
        else
            printf "  • %-36s ${RED}[GAGAL]${NC}\n" "$label..."
        fi
    elif systemctl is-active --quiet "$svc" 2>/dev/null; then
        if systemctl restart "$svc" 2>/dev/null; then
            printf "  • %-36s ${GREEN}[OK]${NC}\n" "$label..."
        else
            printf "  • %-36s ${RED}[GAGAL]${NC}\n" "$label..."
        fi
    else
        printf "  • %-36s ${YELLOW}[Dilewati - Tidak Terpasang]${NC}\n" "$label..."
    fi
}

case "$1" in
    license)
        echo -e "${CYAN}${BOLD}=== PERBAIKAN & VALIDASI LISENSI JAGAT TECH ===${NC}"
        if [ -d "$APP_DIR" ]; then
            cd "$APP_DIR" || exit 1

            # Jika file integritas terhapus/rusak, pulihkan dari release-client.zip terbaru
            if [ ! -f "$APP_DIR/storage/app/license_integrity.json" ]; then
                echo -e "${YELLOW}  • File integritas tidak ditemukan, memulihkan dari paket rilis resmi...${NC}"
                tmp_zip="/tmp/release-client-lic.zip"
                tmp_ext="/tmp/release_lic_extract"
                rm -rf "$tmp_zip" "$tmp_ext" && mkdir -p "$tmp_ext"
                if curl -sSL -f "https://github.com/kangdaqiq/absen_multi/releases/latest/download/release-client.zip" -o "$tmp_zip" && unzip -q -o "$tmp_zip" -d "$tmp_ext"; then
                    src_dir="$tmp_ext/release-client"
                    [ ! -d "$src_dir" ] && src_dir="$tmp_ext"
                    cp -f "$src_dir/storage/app/license_integrity.json" "$APP_DIR/storage/app/license_integrity.json" 2>/dev/null || true
                    cp -f "$src_dir/app/Services/LicenseService.php" "$APP_DIR/app/Services/LicenseService.php" 2>/dev/null || true
                    cp -f "$src_dir/app/Http/Middleware/CheckLicense.php" "$APP_DIR/app/Http/Middleware/CheckLicense.php" 2>/dev/null || true
                    cp -f "$src_dir/app/Http/Middleware/SelfHostedGuard.php" "$APP_DIR/app/Http/Middleware/SelfHostedGuard.php" 2>/dev/null || true
                fi
                rm -rf "$tmp_zip" "$tmp_ext"
            fi

            echo -e "${YELLOW}  • Mengatur ulang kepemilikan storage/ dan cache ke www-data...${NC}"
            chown -R www-data:www-data "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
            chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
            [ -f "$APP_DIR/storage/app/license_integrity.json" ] && chmod 664 "$APP_DIR/storage/app/license_integrity.json" 2>/dev/null || true

            echo -e "${YELLOW}  • Memvalidasi lisensi Ed25519 ke server provider (user www-data)...${NC}"
            su -s /bin/bash -c "cd '$APP_DIR' && php artisan license:validate --force" www-data 2>/dev/null || true
            [ -f "$APP_DIR/storage/app/license_cache.json" ] && chmod 666 "$APP_DIR/storage/app/license_cache.json" 2>/dev/null || true

            echo -e "${GREEN}${BOLD}✔ Lisensi dan hak akses berkas berhasil disinkronkan & diperbaiki!${NC}"
        else
            echo -e "${RED}Direktori $APP_DIR tidak ditemukan.${NC}"
        fi
        ;;

    update)
        echo -e "${CYAN}${BOLD}=== MEMULAI UPDATE SISTEM ABSENSI JAGAT TECH ===${NC}"
        
        # 1. Update Web Absensi dari Release ZIP Resmi (release-client.zip)
        if [ -d "$APP_DIR" ]; then
            echo -e "${YELLOW}▶ [1/3] Mengunduh paket rilis terbaru Web Absen (release-client.zip)...${NC}"
            cd "$APP_DIR" || exit 1
            web_zip_url="https://github.com/kangdaqiq/absen_multi/releases/latest/download/release-client.zip"
            tmp_web_zip="/tmp/release-client.zip"
            tmp_web_ext="/tmp/release_web_extract"
            rm -rf "$tmp_web_zip" "$tmp_web_ext"
            mkdir -p "$tmp_web_ext"

            if curl -sSL -f "$web_zip_url" -o "$tmp_web_zip" && unzip -q -o "$tmp_web_zip" -d "$tmp_web_ext"; then
                src_dir="$tmp_web_ext/release-client"
                [ ! -d "$src_dir" ] && src_dir="$tmp_web_ext"

                # Backup sementara konfigurasi .env dan cache lisensi lokal client
                [ -f "$APP_DIR/.env" ] && cp -f "$APP_DIR/.env" "/tmp/jagat_env.bak"
                [ -f "$APP_DIR/storage/app/license_cache.json" ] && cp -f "$APP_DIR/storage/app/license_cache.json" "/tmp/jagat_lic_cache.bak"

                echo -e "${YELLOW}  • Menyalin file rilis terbaru (termasuk signed license_integrity.json)...${NC}"
                cp -rf "$src_dir/." "$APP_DIR/"
                rm -rf "$APP_DIR/.git" 2>/dev/null || true

                # Kembalikan .env dan cache lisensi lokal client
                [ -f "/tmp/jagat_env.bak" ] && mv -f "/tmp/jagat_env.bak" "$APP_DIR/.env"
                [ -f "/tmp/jagat_lic_cache.bak" ] && mv -f "/tmp/jagat_lic_cache.bak" "$APP_DIR/storage/app/license_cache.json"
                rm -rf "$tmp_web_zip" "$tmp_web_ext"
                echo -e "${GREEN}  ✔ Paket rilis Web Absen berhasil diperbarui!${NC}"
            else
                echo -e "${RED}  ✗ Gagal mengunduh release-client.zip dari GitHub Releases.${NC}"
                rm -rf "$tmp_web_zip" "$tmp_web_ext"
            fi

            echo -e "${YELLOW}  • Memperbarui dependensi PHP (composer install)...${NC}"
            export COMPOSER_ALLOW_SUPERUSER=1
            composer install --no-dev --optimize-autoloader --no-interaction

            echo -e "${YELLOW}  • Menjalankan migrasi database...${NC}"
            php artisan migrate --force

            echo -e "${YELLOW}  • Membersihkan & mengoptimalkan cache Laravel...${NC}"
            php artisan storage:link --force 2>/dev/null || true
            php artisan optimize:clear
            php artisan optimize

            echo -e "${YELLOW}  • Memastikan hak akses direktori & cache milik www-data...${NC}"
            chown -R www-data:www-data "$APP_DIR"
            chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
            [ -f "$APP_DIR/storage/app/license_integrity.json" ] && chmod 664 "$APP_DIR/storage/app/license_integrity.json" 2>/dev/null || true

            # Validasi lisensi sebagai user www-data jika LICENSE_KEY ada di .env
            if grep -q "^LICENSE_KEY=.\+" "$APP_DIR/.env" 2>/dev/null; then
                echo -e "${YELLOW}  • Memvalidasi lisensi sebagai user www-data...${NC}"
                su -s /bin/bash -c "cd '$APP_DIR' && php artisan license:validate --force" www-data 2>/dev/null || true
            fi
            [ -f "$APP_DIR/storage/app/license_cache.json" ] && chmod 666 "$APP_DIR/storage/app/license_cache.json" 2>/dev/null || true
            echo -e "${YELLOW}  • Me-restart antrian background (queue worker)...${NC}"
            supervisorctl restart absen-queue:* 2>/dev/null || true
        fi

        raw_arch=$(uname -m)
        arch_suffix="linux-amd64"
        case "$raw_arch" in
            x86_64)
                arch_suffix="linux-amd64"
                ;;
            aarch64|arm64)
                arch_suffix="linux-arm64"
                ;;
            i386|i686)
                arch_suffix="linux-x86_32"
                ;;
            *)
                arch_suffix="linux-amd64"
                ;;
        esac

        # 2. Update Bot WhatsApp Go (Compiled Binary)
        if [ -d "$BOT_WA_DIR" ]; then
            echo -e "${YELLOW}▶ [2/3] Mengunduh binary compiled terbaru Bot WhatsApp Go (${arch_suffix})...${NC}"
            bot_wa_url="https://github.com/kangdaqiq/bot-go/releases/latest/download/bot-${arch_suffix}.zip"
            tmp_zip="/tmp/bot_wa_${arch_suffix}.zip"
            tmp_extract="/tmp/bot_wa_extract"
            rm -rf "$tmp_extract" "$tmp_zip"
            mkdir -p "$tmp_extract"
            if curl -sSL -f "$bot_wa_url" -o "$tmp_zip" && unzip -q -o "$tmp_zip" -d "$tmp_extract"; then
                found_bin=$(find "$tmp_extract" -type f -name "bot_wa" -o -name "bot_wa.exe" | head -n1)
                [ -z "$found_bin" ] && found_bin=$(find "$tmp_extract" -type f ! -name "*.md" ! -name "*.example" ! -name "*.zip" ! -name "*.bat" | head -n1)
                if [ -n "$found_bin" ]; then
                    systemctl stop bot_wa.service 2>/dev/null || true
                    cp -f "$found_bin" "$BOT_WA_DIR/bot_wa"
                    chmod +x "$BOT_WA_DIR/bot_wa"
                    systemctl restart bot_wa.service 2>/dev/null || true
                    echo -e "${GREEN}  ✔ Binary bot_wa berhasil diperbarui ke versi release terbaru!${NC}"
                fi
                rm -rf "$tmp_extract" "$tmp_zip"
            elif [ -d "$BOT_WA_DIR/.git" ] && command -v /usr/local/go/bin/go &>/dev/null; then
                echo -e "${YELLOW}  Menggunakan fallback: git pull & go build...${NC}"
                cd "$BOT_WA_DIR" || exit 1
                git config --global --add safe.directory "$BOT_WA_DIR" 2>/dev/null || true
                git pull origin main || git pull origin master
                export GOROOT=/usr/local/go
                export PATH=$PATH:/usr/local/go/bin
                /usr/local/go/bin/go mod tidy 2>/dev/null || true
                /usr/local/go/bin/go build -o bot_wa main.go 2>/dev/null || true
                systemctl restart bot_wa.service 2>/dev/null || true
            else
                echo -e "${RED}  ✗ Gagal mengunduh binary bot_wa dari GitHub Releases.${NC}"
            fi
        fi

        # 3. Update Bot Telegram Go (Compiled Binary)
        if [ -d "$BOT_TELE_DIR" ]; then
            echo -e "${YELLOW}▶ [3/3] Mengunduh binary compiled terbaru Bot Telegram Go (${arch_suffix})...${NC}"
            bot_tele_url="https://github.com/kangdaqiq/bot_tele/releases/latest/download/bot_tele-${arch_suffix}.zip"
            tmp_zip="/tmp/bot_tele_${arch_suffix}.zip"
            tmp_extract="/tmp/bot_tele_extract"
            rm -rf "$tmp_extract" "$tmp_zip"
            mkdir -p "$tmp_extract"
            if curl -sSL -f "$bot_tele_url" -o "$tmp_zip" && unzip -q -o "$tmp_zip" -d "$tmp_extract"; then
                found_bin=$(find "$tmp_extract" -type f -name "bot_tele" -o -name "bot_tele.exe" | head -n1)
                [ -z "$found_bin" ] && found_bin=$(find "$tmp_extract" -type f ! -name "*.md" ! -name "*.example" ! -name "*.zip" ! -name "*.bat" | head -n1)
                if [ -n "$found_bin" ]; then
                    systemctl stop bot_tele.service 2>/dev/null || true
                    cp -f "$found_bin" "$BOT_TELE_DIR/bot_tele"
                    chmod +x "$BOT_TELE_DIR/bot_tele"
                    systemctl restart bot_tele.service 2>/dev/null || true
                    echo -e "${GREEN}  ✔ Binary bot_tele berhasil diperbarui ke versi release terbaru!${NC}"
                fi
                rm -rf "$tmp_extract" "$tmp_zip"
            elif [ -d "$BOT_TELE_DIR/.git" ] && command -v /usr/local/go/bin/go &>/dev/null; then
                echo -e "${YELLOW}  Menggunakan fallback: git pull & go build...${NC}"
                cd "$BOT_TELE_DIR" || exit 1
                git config --global --add safe.directory "$BOT_TELE_DIR" 2>/dev/null || true
                git pull origin main || git pull origin master
                export GOROOT=/usr/local/go
                export PATH=$PATH:/usr/local/go/bin
                /usr/local/go/bin/go mod tidy 2>/dev/null || true
                /usr/local/go/bin/go build -o bot_tele . 2>/dev/null || true
                systemctl restart bot_tele.service 2>/dev/null || true
            else
                echo -e "${RED}  ✗ Gagal mengunduh binary bot_tele dari GitHub Releases.${NC}"
            fi
        fi

        echo -e "\n${GREEN}${BOLD}✔ Update Berhasil! Web dan Bot (WA & Telegram) sudah menggunakan versi terbaru.${NC}\n"
        ;;
    status)
        echo -e "${CYAN}${BOLD}======================================================${NC}"
        echo -e "       ${BOLD}STATUS LAYANAN SISTEM ABSENSI JAGAT TECH${NC}        "
        echo -e "${CYAN}${BOLD}======================================================${NC}"
        echo -e "${YELLOW}[ 1. Layanan Web & Core Engine ]${NC}"
        check_service "Nginx Web Server" "nginx"
        check_service "PHP 8.3 FPM Engine" "php8.3-fpm"
        if systemctl list-unit-files 2>/dev/null | grep -q "mariadb.service"; then
            check_service "MariaDB Database" "mariadb"
        else
            check_service "MySQL Database" "mysql"
        fi
        check_service "Cron Scheduler" "cron"

        echo ""
        echo -e "${YELLOW}[ 2. Layanan WhatsApp & Telegram Bot ]${NC}"
        if systemctl list-unit-files 2>/dev/null | grep -q "whatsapp.service"; then
            check_service "WhatsApp Gateway (GOWA)" "whatsapp.service" "(Port 3000 -> 3001)"
        else
            check_service "WhatsApp Gateway (GOWA)" "gowa"
        fi
        check_service "WhatsApp Bot Go" "bot_wa.service" "(Port 5000)"
        check_service "Telegram Bot Go" "bot_tele.service"

        echo ""
        echo -e "${YELLOW}[ 3. Background Queue & Hardware Service ]${NC}"
        if systemctl is-active --quiet supervisor 2>/dev/null; then
            check_service "Supervisor Daemon" "supervisor"
            echo -e "  ${CYAN}• Status Antrian (Queue):${NC}"
            supervisorctl status absen-queue:* 2>/dev/null | sed 's/^/    /' || echo -e "    ${YELLOW}Belum ada worker queue aktif.${NC}"
        else
            check_service "Supervisor Daemon" "supervisor"
        fi

        if systemctl list-unit-files 2>/dev/null | grep -q "armbian-gpio.service"; then
            check_service "Armbian GPIO Init" "armbian-gpio.service"
        fi

        echo ""
        echo -e "${CYAN}${BOLD}======================================================${NC}"
        local free_disk
        free_disk=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 " terpakai)"}')
        local free_ram
        free_ram=$(free -m 2>/dev/null | awk '/^Mem:/{print $3 " MB / " $2 " MB"}')
        local free_swap
        free_swap=$(free -m 2>/dev/null | awk '/^Swap:/{print $3 " MB / " $2 " MB"}')
        echo -e "  • Sisa Disk (eMMC) : ${BOLD}${free_disk}${NC}"
        echo -e "  • Memori (RAM)     : ${BOLD}${free_ram}${NC}"
        echo -e "  • Swap File        : ${BOLD}${free_swap}${NC}"
        echo -e "${CYAN}${BOLD}======================================================${NC}"
        ;;
    restart)
        echo -e "${CYAN}${BOLD}======================================================${NC}"
        echo -e "       ${YELLOW}${BOLD}ME-RESTART SELURUH LAYANAN SISTEM ABSENSI${NC}        "
        echo -e "${CYAN}${BOLD}======================================================${NC}"
        if systemctl list-unit-files 2>/dev/null | grep -q "mariadb.service"; then
            restart_service "Database MariaDB" "mariadb"
        else
            restart_service "Database MySQL" "mysql"
        fi
        restart_service "WhatsApp Gateway (GOWA)" "whatsapp.service"
        restart_service "WhatsApp Bot Go" "bot_wa.service"
        restart_service "Telegram Bot Go" "bot_tele.service"
        restart_service "Cron Scheduler" "cron"
        restart_service "Nginx Web Server" "nginx"

        # Supervisor Queue Worker
        if command -v supervisorctl &>/dev/null; then
            if supervisorctl restart absen-queue:* 2>/dev/null; then
                printf "  • %-36s ${GREEN}[OK]${NC}\n" "Supervisor Worker Queue..."
            else
                printf "  • %-36s ${YELLOW}[Dilewati / Tidak Ada Antrian]${NC}\n" "Supervisor Worker Queue..."
            fi
        fi

        # Khusus PHP-FPM: Jika dipanggil dari web, jalankan async agar koneksi HTTP tidak putus
        if [ "$JAGAT_WEB_INVOCATION" = "1" ] || [ -n "$HTTP_HOST" ] || [ -n "$SERVER_SOFTWARE" ]; then
            (sleep 2 && systemctl restart php8.3-fpm 2>/dev/null) >/dev/null 2>&1 &
            printf "  • %-36s ${GREEN}[OK (Dijadwalkan)]${NC}\n" "PHP 8.3 FPM Engine..."
        else
            restart_service "PHP 8.3 FPM Engine" "php8.3-fpm"
        fi

        echo -e "${CYAN}------------------------------------------------------${NC}"
        echo -e "${GREEN}${BOLD}✔ Seluruh layanan sistem berhasil di-restart!${NC}"
        echo -e "${CYAN}------------------------------------------------------${NC}"
        ;;
    backup)
        echo -e "${CYAN}=== MEMULAI BACKUP SISTEM (DATABASE & STORAGE) ===${NC}"
        if [ -f "/var/www/web/scripts/backup.sh" ]; then
            bash /var/www/web/scripts/backup.sh
        elif [ -f "${APP_DIR}/scripts/backup.sh" ]; then
            bash "${APP_DIR}/scripts/backup.sh"
        elif [ -f "/usr/local/bin/absen-backup" ]; then
            bash /usr/local/bin/absen-backup
        else
            mkdir -p /var/backups/absen
            ts=$(date +"%Y%m%d_%H%M%S")
            echo "Membackup storage..."
            [ -d "${APP_DIR}/storage/app" ] && tar -czf "/var/backups/absen/storage_${ts}.tar.gz" -C "${APP_DIR}/storage" app 2>/dev/null || true
            echo "Membackup database..."
            if [ -f "${APP_DIR}/.env" ]; then
                db_name=$(grep -E '^DB_DATABASE=' "${APP_DIR}/.env" | cut -d '=' -f2 | tr -d '"'\'' ')
                db_user=$(grep -E '^DB_USERNAME=' "${APP_DIR}/.env" | cut -d '=' -f2 | tr -d '"'\'' ')
                db_pass=$(grep -E '^DB_PASSWORD=' "${APP_DIR}/.env" | cut -d '=' -f2 | tr -d '"'\'' ')
                mysqldump -u "${db_user}" -p"${db_pass}" "${db_name}" 2>/dev/null | gzip > "/var/backups/absen/db_${ts}.sql.gz" || true
            else
                mysqldump -u absen_user -pJagatTech123@ absen_jagat 2>/dev/null | gzip > "/var/backups/absen/db_${ts}.sql.gz" || true
            fi
            echo -e "${GREEN}Backup selesai! File tersimpan di /var/backups/absen${NC}"
        fi
        ;;
    logs)
        case "$2" in
            tele)
                echo -e "${CYAN}Memantau Log Telegram Bot Go (Ctrl+C untuk keluar)...${NC}"
                journalctl -u bot_tele.service -f -n 50
                ;;
            bot)
                echo -e "${CYAN}Memantau Log WhatsApp Bot Go (Ctrl+C untuk keluar)...${NC}"
                journalctl -u bot_wa.service -f -n 50
                ;;
            queue)
                echo -e "${CYAN}Memantau Log Queue Worker (Ctrl+C untuk keluar)...${NC}"
                tail -n 50 -f "$APP_DIR/storage/logs/queue.log"
                ;;
            wa)
                echo -e "${CYAN}Memantau Log WhatsApp Gateway (Ctrl+C untuk keluar)...${NC}"
                journalctl -u whatsapp.service -f -n 50 2>/dev/null || journalctl -u gowa.service -f -n 50
                ;;
            nginx)
                echo -e "${CYAN}Memantau Log Nginx Error (Ctrl+C untuk keluar)...${NC}"
                tail -n 50 -f /var/log/nginx/absen_error.log
                ;;
            *)
                echo -e "${CYAN}Memantau Log Laravel (Ctrl+C untuk keluar)...${NC}"
                tail -n 50 -f "$APP_DIR/storage/logs/laravel.log"
                ;;
        esac
        ;;
    *)
        echo -e "${CYAN}======================================================${NC}"
        echo -e "       ${BOLD}JAGAT TECH - COMMAND UTILITY SISTEM ABSENSI${NC}        "
        echo -e "${CYAN}======================================================${NC}"
        echo "Penggunaan: absen [perintah]"
        echo ""
        echo "Perintah yang tersedia:"
        echo -e "  ${GREEN}absen update${NC}         - Update web via Git & update compiled binary bot wa & bot tele"
        echo -e "  ${GREEN}absen status${NC}         - Cek status Nginx, PHP, MariaDB, WA Gateway, Bot WA, Bot Tele, dan Queue"
        echo -e "  ${GREEN}absen restart${NC}        - Restart seluruh service server, WA, dan Bot"
        echo -e "  ${GREEN}absen backup${NC}         - Jalankan backup database dan storage saat ini"
        echo -e "  ${GREEN}absen logs${NC}           - Pantau log Laravel secara realtime"
        echo -e "  ${GREEN}absen logs bot${NC}       - Pantau log WhatsApp Bot Go realtime"
        echo -e "  ${GREEN}absen logs tele${NC}      - Pantau log Telegram Bot Go realtime"
        echo -e "  ${GREEN}absen logs wa${NC}        - Pantau log WhatsApp Gateway (GOWA)"
        echo -e "  ${GREEN}absen logs queue${NC}     - Pantau log antrian proses background (queue)"
        echo -e "  ${GREEN}absen logs nginx${NC}     - Pantau log error web server Nginx"
        echo ""
        ;;
esac
