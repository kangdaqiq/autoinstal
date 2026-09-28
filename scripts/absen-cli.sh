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
    local name="$1"
    local svc="$2"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "${name} : ${GREEN}AKTIF (Running)${NC}"
    else
        echo -e "${name} : ${RED}MATI (Stopped / Inactive)${NC}"
    fi
}

case "$1" in
    update)
        echo -e "${CYAN}${BOLD}=== MEMULAI UPDATE SISTEM ABSENSI JAGAT TECH ===${NC}"
        
        # 1. Update Web Absensi
        if [ -d "$APP_DIR" ]; then
            echo -e "${YELLOW}▶ [1/3] Menarik commit terbaru Web Absen (git pull)...${NC}"
            cd "$APP_DIR" || exit 1
            git config --global --add safe.directory "$APP_DIR" 2>/dev/null || true
            git pull origin main || git pull origin master

            echo -e "${YELLOW}  • Memperbarui dependensi PHP (composer install)...${NC}"
            export COMPOSER_ALLOW_SUPERUSER=1
            composer install --no-dev --optimize-autoloader --no-interaction

            echo -e "${YELLOW}  • Menjalankan migrasi database baru...${NC}"
            php artisan migrate --force

            echo -e "${YELLOW}  • Membersihkan & mengoptimalkan cache Laravel...${NC}"
            php artisan storage:link --force 2>/dev/null || true
            php artisan optimize:clear
            php artisan optimize

            echo -e "${YELLOW}  • Me-restart antrian background (queue worker)...${NC}"
            supervisorctl restart absen-queue:* 2>/dev/null || true
        fi

        # 2. Update Bot WhatsApp Go
        if [ -d "$BOT_WA_DIR" ]; then
            echo -e "${YELLOW}▶ [2/3] Menarik commit terbaru Bot WhatsApp Go (git pull & build)...${NC}"
            cd "$BOT_WA_DIR" || exit 1
            git config --global --add safe.directory "$BOT_WA_DIR" 2>/dev/null || true
            git pull origin main || git pull origin master
            export GOROOT=/usr/local/go
            export PATH=$PATH:/usr/local/go/bin
            /usr/local/go/bin/go mod tidy 2>/dev/null || true
            /usr/local/go/bin/go build -o bot_wa main.go 2>/dev/null || true
            systemctl restart bot_wa.service 2>/dev/null || true
        fi

        # 3. Update Bot Telegram Go
        if [ -d "$BOT_TELE_DIR" ]; then
            echo -e "${YELLOW}▶ [3/3] Menarik commit terbaru Bot Telegram Go (git pull & build)...${NC}"
            cd "$BOT_TELE_DIR" || exit 1
            git config --global --add safe.directory "$BOT_TELE_DIR" 2>/dev/null || true
            git pull origin main || git pull origin master
            export GOROOT=/usr/local/go
            export PATH=$PATH:/usr/local/go/bin
            /usr/local/go/bin/go mod tidy 2>/dev/null || true
            /usr/local/go/bin/go build -o bot_tele . 2>/dev/null || true
            systemctl restart bot_tele.service 2>/dev/null || true
        fi

        echo -e "\n${GREEN}${BOLD}✔ Update Berhasil! Web, Bot WA, dan Bot Telegram sudah versi terbaru dari Git.${NC}\n"
        ;;
    status)
        echo -e "${CYAN}=== Status Layanan Sistem Absensi JAGAT TECH ===${NC}"
        check_service "Nginx Web Server  " "nginx"
        check_service "PHP 8.3 FPM       " "php8.3-fpm"
        if systemctl list-unit-files 2>/dev/null | grep -q "mariadb.service"; then
            check_service "MariaDB Database  " "mariadb"
        else
            check_service "MySQL Database    " "mysql"
        fi
        if systemctl is-active --quiet whatsapp.service 2>/dev/null; then
            check_service "WhatsApp Gateway  " "whatsapp.service"
        else
            check_service "WhatsApp Gateway  " "gowa"
        fi
        check_service "WhatsApp Bot Go   " "bot_wa.service"
        check_service "Telegram Bot Go   " "bot_tele.service"
        echo ""
        echo -e "${CYAN}=== Status Background Worker (Supervisor) ===${NC}"
        supervisorctl status absen-queue:* 2>/dev/null || echo -e "${YELLOW}Supervisor tidak aktif atau belum ada proses.${NC}"
        ;;
    restart)
        echo -e "${YELLOW}Me-restart semua layanan...${NC}"
        systemctl restart php8.3-fpm
        systemctl restart nginx
        systemctl restart whatsapp.service 2>/dev/null || systemctl restart gowa 2>/dev/null || true
        systemctl restart bot_wa.service 2>/dev/null || true
        systemctl restart bot_tele.service 2>/dev/null || true
        supervisorctl restart absen-queue:* 2>/dev/null || true
        echo -e "${GREEN}Semua service berhasil di-restart!${NC}"
        ;;
    backup)
        if [ -f "/var/www/web/scripts/backup.sh" ]; then
            bash /var/www/web/scripts/backup.sh
        elif [ -f "/usr/local/bin/absen-backup" ]; then
            bash /usr/local/bin/absen-backup
        else
            echo -e "${RED}Script backup tidak ditemukan.${NC}"
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
        echo -e "  ${GREEN}absen update${NC}         - Update web, bot wa & bot tele via Git (git pull + migrate + go build)"
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
