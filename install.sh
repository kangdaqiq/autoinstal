#!/usr/bin/env bash
# ==============================================================================
#   ██╗ █████╗  ██████╗  █████╗ ████████╗    ████████╗███████╗ ██████╗██╗  ██╗
#   ██║██╔══██╗██╔════╝ ██╔══██╗╚══██╔══╝    ╚══██╔══╝██╔════╝██╔════╝██║  ██║
#   ██║███████║██║  ███╗███████║   ██║          ██║   █████╗  ██║     ███████║
#   ██║██╔══██║██║   ██║██╔══██║   ██║          ██║   ██╔══╝  ██║     ██╔══██║
#  ███║██║  ██║╚██████╔╝██║  ██║   ██║          ██║   ███████╗╚██████╗██║  ██║
#  ╚══╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝          ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝
# ==============================================================================
#  AUTO INSTALLER SERVER, WEB ABSENSI & WHATSAPP GATEWAY (GOWA LATEST)
# ==============================================================================
#  Target OS     : Debian (10/11/12) & Armbian Amlogic S905X (B860H/HG680P/Box)
#  Repository    : https://github.com/kangdaqiq/absen_multi.git
#  WhatsApp GW   : aldinokemal/go-whatsapp-web-multidevice (Auto Latest Release)
#  Stack         : Nginx • PHP 8.3 • MariaDB • Composer 2 • Golang • GOWA
#  Provider      : JAGAT TECH
# ==============================================================================

set -E -eo pipefail

# --- Warna Tampilan ---
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_RED="\033[38;5;196m"
C_GREEN="\033[38;5;46m"
C_YELLOW="\033[38;5;220m"
C_BLUE="\033[38;5;39m"
C_CYAN="\033[38;5;51m"
C_PURPLE="\033[38;5;135m"
C_WHITE="\033[38;5;231m"

# --- Icon Status ---
ICON_CHECK="${C_GREEN}✔${C_RESET}"
ICON_CROSS="${C_RED}✖${C_RESET}"
ICON_ARROW="${C_CYAN}➜${C_RESET}"
ICON_WARN="${C_YELLOW}⚠${C_RESET}"
ICON_INFO="${C_BLUE}ℹ${C_RESET}"
ICON_GEAR="${C_PURPLE}⚙${C_RESET}"

# --- Variabel Default & Path Direktori ---
LOG_FILE="/var/log/jagattech_install.log"
BASE_WWW_DIR="/var/www"
APP_DIR="${BASE_WWW_DIR}/web"
BOT_GO_DIR="${BASE_WWW_DIR}/bot-go"
BOT_WA_LINK="${BASE_WWW_DIR}/bot-wa"
BOT_TELE_DIR="${BASE_WWW_DIR}/bot-tele"
WA_DIR="${BASE_WWW_DIR}/whatsapp"

GIT_REPO="https://github.com/kangdaqiq/absen_multi.git"
BOT_GO_REPO="https://github.com/kangdaqiq/bot-go.git"
BOT_GO_PORT="5000"
BOT_TELE_REPO="https://github.com/kangdaqiq/bot_tele.git"
PHP_DEFAULT_VER="8.3"
WEB_USER="www-data"
DEFAULT_DOMAIN="localhost"

DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME_DEFAULT="absen_jagat"
DB_USER_DEFAULT="absen_user"
DEFAULT_PASSWORD="JagatTech123@"

WA_PORT="3000"
WA_USER="admin"
WA_WEBHOOK_DEFAULT="http://127.0.0.1:5000/webhook"

# --- Logging Helper ---
log() {
    local msg="$1"
    echo -e "${msg}"
    echo -e "${msg}" | sed -r "s/\x1B\[[0-9;]*[a-zA-Z]//g" >> "${LOG_FILE}" 2>/dev/null || true
}

log_info()    { log " ${ICON_INFO} ${C_WHITE}$1${C_RESET}"; }
log_step()    { log "\n${C_BOLD}${C_BLUE}▶ $1${C_RESET}"; }
log_success() { log " ${ICON_CHECK} ${C_GREEN}$1${C_RESET}"; }
log_warn()    { log " ${ICON_WARN} ${C_YELLOW}$1${C_RESET}"; }
log_error()   { log " ${ICON_CROSS} ${C_RED}$1${C_RESET}"; }

# --- Task Runner dengan Spinner Animasi Live Progress ---
run_task() {
    local title="$1"
    local command_str="$2"
    local pid
    local spin_chars=('/' '-' '\' '|')
    local i=0

    # Catat ke file log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RUN_TASK] ${title}" >> "${LOG_FILE}" 2>&1

    # Jalankan perintah di background terputus dari stdin agar debconf/dpkg tidak hang
    ( trap - ERR; eval "$command_str" ) < /dev/null >> "${LOG_FILE}" 2>&1 &
    pid=$!

    # Sembunyikan kursor jika di terminal
    [ -t 1 ] && tput civis 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        if [ -t 1 ]; then
            printf "\r  ${C_CYAN}[%s]${C_RESET} ${C_WHITE}%s...${C_RESET}\033[K" "${spin_chars[$i]}" "$title"
        fi
        sleep 0.15
    done

    # Kembalikan kursor
    [ -t 1 ] && tput cnorm 2>/dev/null || true

    set +e
    wait "$pid"
    local exit_code=$?
    set -e

    if [ $exit_code -eq 0 ]; then
        if [ -t 1 ]; then
            printf "\r  ${ICON_CHECK} ${C_GREEN}%s selesai.${C_RESET}\033[K\n" "$title"
        else
            echo "  ✔ $title selesai."
        fi
        return 0
    else
        if [ -t 1 ]; then
            printf "\r  ${ICON_CROSS} ${C_RED}%s gagal! (Exit Code: %s)${C_RESET}\033[K\n" "$title" "$exit_code"
        else
            echo "  ✖ $title gagal! (Exit Code: $exit_code)"
        fi
        echo -e "${C_YELLOW}--- 12 Baris Terakhir Error (${LOG_FILE}) ---${C_RESET}"
        tail -n 12 "${LOG_FILE}" 2>/dev/null || true
        echo -e "${C_YELLOW}------------------------------------------------${C_RESET}"
        return $exit_code
    fi
}

# --- Error Handler ---
handle_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        log_error "Instalasi terhenti karena error di baris $1 (Exit Code: $exit_code)."
        echo -e "${C_YELLOW}--- Rincian Log Error (/var/log/jagattech_install.log) ---${C_RESET}"
        tail -n 15 "${LOG_FILE}" 2>/dev/null || true
        echo -e "${C_YELLOW}------------------------------------------------------------${C_RESET}"
        log_warn "Silakan periksa log lengkap di: ${C_WHITE}${LOG_FILE}${C_RESET}"
    fi
}
trap 'handle_error $LINENO' ERR

# --- Banner JAGAT TECH ---
show_banner() {
    clear || true
    echo -e "${C_PURPLE}${C_BOLD}"
    cat << "EOF"
   ██╗ █████╗  ██████╗  █████╗ ████████╗    ████████╗███████╗ ██████╗██╗  ██╗
   ██║██╔══██╗██╔════╝ ██╔══██╗╚══██╔══╝    ╚══██╔══╝██╔════╝██╔════╝██║  ██║
   ██║███████║██║  ███╗███████║   ██║          ██║   █████╗  ██║     ███████║
   ██║██╔══██║██║   ██║██╔══██║   ██║          ██║   ██╔══╝  ██║     ██╔══██║
█████║██║  ██║╚██████╔╝██║  ██║   ██║          ██║   ███████╗╚██████╗██║  ██║
╚════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝          ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝
EOF
    echo -e "${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}   >>> AUTO INSTALLER SERVER, WEB ABSENSI & GOWA LATEST <<<${C_RESET}"
    echo -e "${C_DIM}   Target  : Debian x86_64 & Armbian Amlogic S905X (STB B860H/HG680P)${C_RESET}"
    echo -e "${C_DIM}   Repo Git: ${GIT_REPO}${C_RESET}"
    echo -e "${C_DIM}   Log File: ${LOG_FILE}${C_RESET}"
    echo -e "──────────────────────────────────────────────────────────────────────────────"
    echo ""
}

# --- Cek Hak Akses Root ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Script ini harus dijalankan sebagai root!"
        log_info "Silakan jalankan: ${C_BOLD}sudo bash $0${C_RESET}"
        exit 1
    fi
}

# --- Helper Input Aman (Bekerja Baik di Pipe curl | bash, TTY, atau Non-Interactive) ---
safe_read() {
    local prompt_msg="$1"
    local default_val="$2"
    local user_val=""

    if [ "${AUTO_YES:-false}" = true ]; then
        echo -e "${prompt_msg}${C_BOLD}${default_val}${C_RESET} ${C_DIM}(auto default)${C_RESET}" >&2
        echo "$default_val"
        return 0
    fi

    # Coba baca dari /dev/tty jika tersedia (misal di-pipe lewat curl/wget)
    if [ -r /dev/tty ]; then
        read -r -p "$prompt_msg" user_val </dev/tty 2>/dev/tty || user_val=""
    elif [ -t 0 ]; then
        read -r -p "$prompt_msg" user_val 2>/dev/null || user_val=""
    else
        # Jika benar-benar headless tanpa TTY
        echo -e "${prompt_msg}${C_BOLD}${default_val}${C_RESET} ${C_DIM}(non-interactive default)${C_RESET}" >&2
        user_val=""
    fi

    user_val=$(echo "$user_val" | tr -d '\r\n')
    echo "${user_val:-$default_val}"
}

detect_server_ip() {
    SERVER_IP=$(curl -s4 --connect-timeout 3 --max-time 5 https://ifconfig.me 2>/dev/null || curl -s4 --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="127.0.0.1"
    fi
}

generate_random_password() {
    local length=${1:-16}
    LC_ALL=C tr -dc 'A-Za-z0-9!#%_+=' < /dev/urandom 2>/dev/null | head -c "$length" || openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c "$length"
}

# --- Deteksi OS & Arsitektur (Debian x86_64 & Armbian Amlogic S905X) ---
detect_system() {
    log_step "Mendeteksi Sistem Operasi & Arsitektur Perangkat..."

    # 1. Deteksi OS
    OS_NAME="unknown"
    OS_CODENAME="unknown"
    IS_ARMBIAN=false
    IS_AMLOGIC_S905X=false

    if [ -f /etc/armbian-release ]; then
        IS_ARMBIAN=true
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$ID"
        OS_CODENAME="${VERSION_CODENAME:-$UBUNTU_CODENAME}"
    fi

    if [ -z "$OS_CODENAME" ] || [ "$OS_CODENAME" = "unknown" ]; then
        OS_CODENAME=$(lsb_release -sc 2>/dev/null || echo "bookworm")
    fi

    # 2. Deteksi Arsitektur Perangkat
    RAW_ARCH=$(uname -m)
    case "$RAW_ARCH" in
        x86_64)
            ARCH_NAME="amd64"
            GO_ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH_NAME="arm64"
            GO_ARCH="arm64"
            ;;
        armv7l|armhf)
            ARCH_NAME="armhf"
            GO_ARCH="armv6l"
            ;;
        *)
            log_error "Arsitektur '${RAW_ARCH}' tidak didukung. Installer ini hanya mendukung x86_64 dan Armbian Amlogic S905X."
            exit 1
            ;;
    esac

    # 3. Cek Spesifik Amlogic S905X (STB B860H, HG680P, X96 Mini, TX3 Mini, dsb)
    local dt_model=""
    if [ -f /proc/device-tree/model ]; then
        dt_model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "")
    fi

    local armbian_board=""
    if [ -f /etc/armbian-release ]; then
        armbian_board=$(grep -E '^(BOARD|BOARDFAMILY|LINUXFAMILY)=' /etc/armbian-release | tr '\n' ' ' 2>/dev/null || echo "")
    fi

    local cpu_info=""
    if [ -f /proc/cpuinfo ]; then
        cpu_info=$(grep -E -i 'Hardware|model name|vendor_id' /proc/cpuinfo | head -n2 2>/dev/null || echo "")
    fi

    if [[ "$dt_model" =~ [Aa]mlogic|[Mm]eson|[Ss]905|[Bb]860|[Hh]g680|[Xx]96 ]] || \
       [[ "$armbian_board" =~ meson64|amlogic|s905 ]] || \
       [[ "$cpu_info" =~ [Aa]mlogic|[Mm]eson ]]; then
        IS_AMLOGIC_S905X=true
        DEVICE_TITLE="Armbian Amlogic S905X (STB B860H / HG680P / Box)"
    elif [ "$ARCH_NAME" = "amd64" ]; then
        DEVICE_TITLE="Debian x86_64 (PC / VPS Cloud Server)"
    else
        DEVICE_TITLE="Debian / Armbian ARM (${dt_model:-$RAW_ARCH})"
    fi

    log_success "Distro      : ${C_WHITE}${PRETTY_NAME:-$OS_NAME} (${OS_CODENAME})${C_RESET}"
    if [ "$IS_AMLOGIC_S905X" = true ]; then
        log_success "Perangkat   : ${C_GREEN}${C_BOLD}${DEVICE_TITLE}${C_RESET}"
        log_info "Info Board  : ${C_DIM}${dt_model:-Amlogic Meson S905X}${C_RESET}"
    else
        log_success "Perangkat   : ${C_WHITE}${C_BOLD}${DEVICE_TITLE}${C_RESET}"
    fi
    log_success "Arsitektur  : ${C_YELLOW}${RAW_ARCH}${C_RESET} -> Paket Deb: ${C_BOLD}${ARCH_NAME}${C_RESET} | Binary Go: ${C_BOLD}${GO_ARCH}${C_RESET}"

    # Pastikan turunan debian
    if [[ "$OS_NAME" != "debian" && "$OS_NAME" != "ubuntu" && "$IS_ARMBIAN" != true && "$ID_LIKE" != *"debian"* ]]; then
        log_warn "Sistem Anda terdeteksi sebagai '$OS_NAME'. Script ini dikhususkan untuk Debian / Armbian."
        local continue_confirm
        continue_confirm=$(safe_read "Tetap lanjutkan instalasi? [y/N]: " "N")
        case "$continue_confirm" in
            [yY][eE][sS]|[yY]) ;;
            *) exit 1 ;;
        esac
    fi
}

# --- Cek RAM & Setup Swap Otomatis ---
check_ram_and_swap() {
    log_step "Memeriksa Kapasitas Memori (RAM & Swap)..."
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')

    log_info "Total RAM  : ${C_BOLD}${TOTAL_RAM} MB${C_RESET}"
    log_info "Total Swap : ${C_BOLD}${TOTAL_SWAP} MB${C_RESET}"

    if [ "$TOTAL_RAM" -lt 1800 ] && [ "$TOTAL_SWAP" -lt 1024 ]; then
        log_warn "RAM perangkat di bawah 2GB. Menyiapkan Swap File 2GB otomatis agar proses Composer & Git tidak kehabisan memori..."
        if [ ! -f /swapfile ]; then
            fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 >> "${LOG_FILE}" 2>&1
            chmod 600 /swapfile
            mkswap /swapfile >> "${LOG_FILE}" 2>&1
            swapon /swapfile >> "${LOG_FILE}" 2>&1
            if ! grep -q '/swapfile' /etc/fstab; then
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
            fi
            sysctl -w vm.swappiness=10 >> "${LOG_FILE}" 2>&1 || true
            echo 'vm.swappiness=10' > /etc/sysctl.d/99-jagat-swap.conf 2>/dev/null || true
            log_success "Swap 2GB berhasil diaktifkan (eMMC Safe: swappiness=10)!"
        fi
    else
        log_success "Kapasitas memori mencukupi."
    fi
}

# --- Input Konfigurasi Interaktif ---
collect_inputs() {
    detect_server_ip

    echo ""
    echo -e "${C_BOLD}${C_WHITE}--- PENGATURAN INSTALASI WEB ABSENSI & WHATSAPP JAGAT TECH ---${C_RESET}"
    echo -e "${C_DIM}Tekan [ENTER] untuk menyetujui nilai default [di dalam kurung].${C_RESET}\n"

    # 1. Domain / Host
    echo -e "${ICON_ARROW} ${C_BOLD}Domain atau IP Server:${C_RESET}"
    echo -e "   ${C_DIM}(IP Terdeteksi: ${SERVER_IP} | Default: ${DEFAULT_DOMAIN})${C_RESET}"
    APP_DOMAIN=$(safe_read "   Domain/IP [${DEFAULT_DOMAIN}]: " "${DEFAULT_DOMAIN}")
    APP_URL="http://${APP_DOMAIN}"

    # 2. Database Name & User
    echo ""
    echo -e "${ICON_GEAR} ${C_BOLD}Pengaturan Database MariaDB:${C_RESET}"
    DB_NAME=$(safe_read "   Nama Database [${DB_NAME_DEFAULT}]: " "${DB_NAME_DEFAULT}")
    DB_USER=$(safe_read "   User Database [${DB_USER_DEFAULT}]: " "${DB_USER_DEFAULT}")
    DB_PASS=$(safe_read "   Password Database [${DEFAULT_PASSWORD}]: " "${DEFAULT_PASSWORD}")

    # 3. WhatsApp Gateway Password & Webhook
    echo ""
    echo -e "${ICON_GEAR} ${C_BOLD}Pengaturan WhatsApp Gateway (GOWA):${C_RESET}"
    WA_PASS=$(safe_read "   Password WhatsApp Gateway [${DEFAULT_PASSWORD}]: " "${DEFAULT_PASSWORD}")
    WA_WEBHOOK_URL=$(safe_read "   Webhook URL WhatsApp [${WA_WEBHOOK_DEFAULT}]: " "${WA_WEBHOOK_DEFAULT}")

    echo ""
    echo -e "──────────────────────────────────────────────────────────────────────────────"
    echo -e "${C_BOLD}${C_GREEN}RINGKASAN TUGAS INSTALASI:${C_RESET}"
    echo -e "  • Repositori Git : ${C_BOLD}${GIT_REPO}${C_RESET}"
    echo -e "  • Lokasi Web     : ${C_BOLD}${APP_DIR}${C_RESET}"
    echo -e "  • URL Akses Web  : ${C_BOLD}${APP_URL}${C_RESET}"
    echo -e "  • Database       : ${C_BOLD}${DB_NAME}${C_RESET} (User: ${DB_USER})"
    echo -e "  • WhatsApp GW    : ${C_BOLD}Port ${WA_PORT}${C_RESET} (User: ${WA_USER})"
    echo -e "  • WA Webhook     : ${C_CYAN}${WA_WEBHOOK_URL}${C_RESET}"
    echo -e "  • Engine Stack   : ${C_WHITE}Nginx, PHP 8.3, MariaDB, Composer, Golang, GOWA${C_RESET}"
    echo -e "──────────────────────────────────────────────────────────────────────────────"
    
    local confirm
    confirm=$(safe_read "Lanjutkan proses instalasi sekarang? [Y/n]: " "Y")
    case "$confirm" in
        [nN][oO]|[nN])
            log_warn "Instalasi dibatalkan."
            exit 0
            ;;
        *)
            ;;
    esac
}

# --- 1. Base Tools & Dependencies ---
install_base_tools() {
    log_step "[1/11] Memperbarui Repository APT & Menginstal Utilitas Dasar..."
    export DEBIAN_FRONTEND=noninteractive
    
    # Pulihkan dpkg jika ada proses interupsi sebelumnya
    dpkg --configure -a >> "${LOG_FILE}" 2>&1 || true

    run_task "Sinkronisasi index paket repository APT (apt update)" "apt-get update -y"
    
    # 1. Paket Inti Wajib (Tersedia universal di Debian/Armbian)
    run_task "Memasang utilitas inti (curl, git, supervisor, build-essential, jq)" \
        "apt-get install -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' curl wget git unzip zip tar ca-certificates gnupg lsb-release build-essential cron supervisor jq"

    # 2. Firewall UFW
    run_task "Memasang paket firewall UFW" \
        "apt-get install -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' ufw || true"

    # 3. Paket Tambahan (software-properties-common, fail2ban, apt-transport-https)
    run_task "Memasang paket utilitas pelengkap" \
        "apt-get install -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' software-properties-common fail2ban apt-transport-https >> ${LOG_FILE} 2>&1 || true"
    
    # 4. Paket gpiod (Khusus Armbian)
    if [ "$IS_ARMBIAN" = true ] || [ -f /etc/armbian-release ]; then
        run_task "Memasang paket utilitas hardware gpiod (khusus Armbian)" \
            "apt-get install -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' gpiod >> ${LOG_FILE} 2>&1 || true"
    fi

    # Konfigurasi Git untuk stabilitas koneksi & shallow fetch hemat bandwidth
    git config --global http.postBuffer 524288000 2>/dev/null || true
    git config --global http.version HTTP/1.1 2>/dev/null || true
    git config --global core.compression 0 2>/dev/null || true

    log_success "Paket utilitas dasar & git siap digunakan."
}

# --- 2. Install Nginx ---
install_nginx() {
    log_step "[2/11] Menginstal Nginx Web Server..."
    export DEBIAN_FRONTEND=noninteractive

    if systemctl is-active --quiet apache2 2>/dev/null; then
        run_task "Menonaktifkan service Apache2 yang bentrok" "systemctl stop apache2 && systemctl disable apache2"
    fi

    run_task "Mengunduh & memasang Nginx Web Server" "apt-get install -y nginx"
    run_task "Mengaktifkan & menjalankan daemon Nginx" "systemctl enable nginx && systemctl restart nginx"

    local nginx_ver
    nginx_ver=$(nginx -v 2>&1 | awk -F/ '{print $2}')
    log_success "Nginx v${nginx_ver} berhasil diinstal dan berjalan."
}

# --- 3. Install PHP 8.3 & Ekstensi Lengkap (Sury Multi-Arch) ---
install_php() {
    log_step "[3/11] Menyiapkan PHP ${PHP_DEFAULT_VER} & Ekstensi (Sury Multi-Arch)..."
    export DEBIAN_FRONTEND=noninteractive

    local php_ver="$PHP_DEFAULT_VER"

    if [ ! -f /etc/apt/trusted.gpg.d/php.gpg ]; then
        run_task "Mengunduh GPG Key Sury PHP" "curl -sSLo /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg"
    fi

    if [[ "$OS_NAME" == "ubuntu" ]]; then
        if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
            run_task "Menambahkan PPA Ondrej PHP" "add-apt-repository -y ppa:ondrej/php"
        fi
    else
        echo "deb https://packages.sury.org/php/ ${OS_CODENAME} main" > /etc/apt/sources.list.d/php.list
    fi

    run_task "Sinkronisasi repository PHP Sury" "apt-get update -y"

    run_task "Memasang paket PHP ${php_ver} FPM, CLI & ekstensi lengkap" "apt-get install -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' php${php_ver}-fpm php${php_ver}-cli php${php_ver}-common php${php_ver}-mysql php${php_ver}-mbstring php${php_ver}-bcmath php${php_ver}-gd php${php_ver}-zip php${php_ver}-intl php${php_ver}-xml php${php_ver}-curl php${php_ver}-opcache php${php_ver}-readline php${php_ver}-sqlite3"

    local fpm_ini="/etc/php/${php_ver}/fpm/php.ini"
    local cli_ini="/etc/php/${php_ver}/cli/php.ini"
    local fpm_pool="/etc/php/${php_ver}/fpm/pool.d/www.conf"

    local php_mem="512M"
    if [ "$IS_AMLOGIC_S905X" = true ] || [ "$TOTAL_RAM" -lt 1800 ]; then
        php_mem="256M"
        log_info "Menerapkan profil memori hemat RAM (256M) untuk S905X..."
    fi

    for ini in "$fpm_ini" "$cli_ini"; do
        if [ -f "$ini" ]; then
            sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$ini"
            sed -i 's/^post_max_size = .*/post_max_size = 64M/' "$ini"
            sed -i "s/^memory_limit = .*/memory_limit = ${php_mem}/" "$ini"
            sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$ini"
        fi
    done

    # FPM pool tuning untuk S905X
    if [ "$IS_AMLOGIC_S905X" = true ] && [ -f "$fpm_pool" ]; then
        log_info "Mengatur FPM pool ke mode ondemand (hemat daya & memori STB)..."
        sed -i 's/^pm = .*/pm = ondemand/' "$fpm_pool"
        sed -i 's/^pm.max_children = .*/pm.max_children = 8/' "$fpm_pool"
        sed -i 's/^;pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s/' "$fpm_pool"
        sed -i 's/^;pm.max_requests = .*/pm.max_requests = 200/' "$fpm_pool"
    fi

    run_task "Memulai ulang service PHP ${php_ver} FPM" "systemctl restart php${php_ver}-fpm && systemctl enable php${php_ver}-fpm"

    local installed_php
    installed_php=$(php -v | head -n1 | awk '{print $2}')
    log_success "PHP v${installed_php} (FPM & CLI) siap digunakan."
}

# --- 4. Install MariaDB & Buat Database ---
install_database() {
    log_step "[4/11] Menginstal & Menyiapkan Database MariaDB..."
    export DEBIAN_FRONTEND=noninteractive

    run_task "Mengunduh & memasang MariaDB Server" "apt-get install -y mariadb-server mariadb-client || apt-get install -y default-mysql-server default-mysql-client"

    # Tuning khusus S905X (ramah flash storage & hemat RAM)
    if [ "$IS_AMLOGIC_S905X" = true ]; then
        local db_conf_dir="/etc/mysql/mariadb.conf.d"
        [ ! -d "$db_conf_dir" ] && db_conf_dir="/etc/mysql/conf.d"
        mkdir -p "$db_conf_dir"

        cat << 'EOF' > "${db_conf_dir}/99-jagat-s905x.cnf"
[mysqld]
innodb_buffer_pool_size = 64M
innodb_log_file_size = 16M
innodb_flush_log_at_trx_commit = 2
max_connections = 50
key_buffer_size = 16M
table_open_cache = 400
EOF
    fi

    run_task "Memulai ulang & menyalakan daemon MariaDB" "systemctl enable mariadb >> ${LOG_FILE} 2>&1 || systemctl enable mysql >> ${LOG_FILE} 2>&1; systemctl restart mariadb >> ${LOG_FILE} 2>&1 || systemctl restart mysql >> ${LOG_FILE} 2>&1"

    # Siapkan file query SQL sementara yang bersih dan aman dari escaping / eval issues
    local sql_tmp="/tmp/jagat_db_setup.sql"
    cat << EOF > "${sql_tmp}"
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
    chmod 600 "${sql_tmp}"

    run_task "Mengonfigurasi database '${DB_NAME}' & pengguna '${DB_USER}'" "(mariadb -u root < '${sql_tmp}' || mysql -u root < '${sql_tmp}') && rm -f '${sql_tmp}'"
    rm -f "${sql_tmp}" 2>/dev/null || true

    log_success "Database '${DB_NAME}' dan pengguna '${DB_USER}' siap digunakan."
}

# --- 5. Install Composer & Golang ---
install_composer_and_go() {
    log_step "[5/11] Menginstal Composer 2 & Golang Engine..."
    export DEBIAN_FRONTEND=noninteractive
    export COMPOSER_ALLOW_SUPERUSER=1

    # Composer
    if ! command -v composer &> /dev/null; then
        run_task "Mengunduh & memasang Composer 2" "curl -sS --connect-timeout 10 https://getcomposer.org/installer -o /tmp/composer-setup.php && php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer && rm -f /tmp/composer-setup.php"
    fi
    log_success "Composer 2 terpasang di /usr/local/bin/composer."

    # Golang
    local go_ver="go1.23.1"
    local need_install_go=true

    if command -v /usr/local/go/bin/go &> /dev/null; then
        local current_go
        current_go=$(/usr/local/go/bin/go version 2>/dev/null | awk '{print $3}')
        if [ -n "$current_go" ]; then
            need_install_go=false
            log_success "Golang Engine (${current_go}) sudah terpasang."
        fi
    fi

    if [ "$need_install_go" = true ]; then
        local go_archive="${go_ver}.linux-${GO_ARCH}.tar.gz"
        local go_url="https://go.dev/dl/${go_archive}"
        run_task "Mengunduh & mengekstrak Golang Engine (${go_ver} - ${GO_ARCH})" "curl -sSL -f --connect-timeout 15 '$go_url' -o '/tmp/${go_archive}' && rm -rf /usr/local/go && tar -C /usr/local -xzf '/tmp/${go_archive}' && rm -f '/tmp/${go_archive}' || apt-get install -y golang-go"
    fi

    # Setup PATH Go
    cat << 'EOF' > /etc/profile.d/golang.sh
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
EOF
    chmod +x /etc/profile.d/golang.sh
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

    log_success "Golang (${GO_ARCH}) terpasang di /usr/local/go/bin/go."
}

# --- 6. Clone / Deploy Web Absen dari Git Repo ---
deploy_web_absen() {
    log_step "[6/11] Mengunduh & Memasang Web Absen via Git (${GIT_REPO})..."

    git config --global --add safe.directory "${APP_DIR}" 2>/dev/null || true
    git config --global http.postBuffer 524288000 2>/dev/null || true
    git config --global http.version HTTP/1.1 2>/dev/null || true

    if [ -d "${APP_DIR}/.git" ]; then
        run_task "Menarik commit terbaru Web Absen via Git (git pull)" "cd '${APP_DIR}' && (git pull origin main || git pull origin master)"
    else
        mkdir -p "${APP_DIR}"
        rm -rf "${APP_DIR:?}"/* "${APP_DIR:?}"/.[!.]* 2>/dev/null || true
        run_task "Mengunduh source code Web Absen dari GitHub (Shallow --depth 1)" "git clone --depth 1 --single-branch '${GIT_REPO}' '${APP_DIR}'"
    fi

    cd "${APP_DIR}"

    # Buat direktori framework & storage lengkap
    mkdir -p "${APP_DIR}/storage/framework/cache/data" \
             "${APP_DIR}/storage/framework/sessions" \
             "${APP_DIR}/storage/framework/views" \
             "${APP_DIR}/storage/logs" \
             "${APP_DIR}/bootstrap/cache"

    # Konfigurasi .env (Utamakan .env.selfhosted.example)
    log_info "Mengkonfigurasi file .env dari template .env.selfhosted.example..."
    if [ ! -f .env ]; then
        if [ -f .env.selfhosted.example ]; then
            cp .env.selfhosted.example .env
        elif [ -f .env.example ]; then
            cp .env.example .env
        else
            touch .env
        fi
    fi

    set_env_val() {
        local key="$1"
        local val="$2"
        if grep -q "^${key}=" .env; then
            sed -i "s|^${key}=.*|${key}=${val}|" .env
        else
            echo "${key}=${val}" >> .env
        fi
    }

    set_env_val "APP_NAME" "\"Sistem Absensi JAGAT TECH\""
    set_env_val "APP_ENV" "production"
    set_env_val "APP_DEBUG" "false"
    set_env_val "APP_URL" "${APP_URL}"
    set_env_val "APP_MODE" "self_hosted"

    set_env_val "LICENSE_SERVER_URL" "https://absen.jagattech.my.id"

    # Database Configuration (Harmonized)
    set_env_val "DB_CONNECTION" "mysql"
    set_env_val "DB_HOST" "${DB_HOST}"
    set_env_val "DB_PORT" "${DB_PORT}"
    set_env_val "DB_DATABASE" "${DB_NAME}"
    set_env_val "DB_USERNAME" "${DB_USER}"
    set_env_val "DB_PASSWORD" "${DB_PASS}"
    set_env_val "DB_NAME" "${DB_NAME}"
    set_env_val "DB_USER" "${DB_USER}"

    set_env_val "SESSION_DRIVER" "database"
    set_env_val "SESSION_LIFETIME" "120"
    set_env_val "CACHE_STORE" "database"
    set_env_val "QUEUE_CONNECTION" "database"

    # WhatsApp API (GOWA Harmonized)
    set_env_val "GOWA_API_BASE_URL" "http://127.0.0.1:${WA_PORT}"
    set_env_val "GOWA_API_USER" "${WA_USER}"
    set_env_val "GOWA_API_PASS" "${WA_PASS}"

    set_env_val "WA_API_BASE_URL" "http://127.0.0.1:${WA_PORT}"
    set_env_val "WA_API_URL" "http://127.0.0.1:${WA_PORT}"
    set_env_val "WA_API_USER" "${WA_USER}"
    set_env_val "WA_API_PASS" "${WA_PASS}"

    # Jalankan Composer
    if [ -f composer.json ]; then
        export COMPOSER_ALLOW_SUPERUSER=1
        run_task "Memasang dependensi PHP (composer install --no-dev)" "composer install --no-dev --optimize-autoloader --no-interaction"
    fi

    # Artisan Commands
    if [ -f artisan ]; then
        run_task "Menghasilkan APP_KEY & menjalankan migrasi database" "php artisan key:generate --force && php artisan migrate --force"
        run_task "Membuat storage link & mengoptimalkan cache Laravel" "php artisan storage:link --force && php artisan optimize:clear && php artisan optimize"
    fi

    # Set Permissions
    log_info "Mengatur hak akses direktori www-data..."
    chown -R ${WEB_USER}:${WEB_USER} "${APP_DIR}"
    chmod -R 755 "${APP_DIR}"
    if [ -d "${APP_DIR}/storage" ]; then
        chmod -R 775 "${APP_DIR}/storage"
        chown -R ${WEB_USER}:${WEB_USER} "${APP_DIR}/storage"
    fi
    if [ -d "${APP_DIR}/bootstrap/cache" ]; then
        chmod -R 775 "${APP_DIR}/bootstrap/cache"
        chown -R ${WEB_USER}:${WEB_USER} "${APP_DIR}/bootstrap/cache"
    fi

    log_success "Web Absensi berhasil diinstal dari Git ke ${APP_DIR}."
}

# --- 7. Install & Setup WhatsApp Gateway (GOWA Latest Release) ---
install_gowa_whatsapp() {
    log_step "[7/11] Mengunduh & Memasang WhatsApp Gateway (GOWA Latest Release)..."

    # 1. Cari release terbaru dari GitHub API
    log_info "Mencari versi terbaru GOWA di GitHub API..."
    local latest_tag=""
    latest_tag=$(curl -sSL --connect-timeout 5 --max-time 10 "https://api.github.com/repos/aldinokemal/go-whatsapp-web-multidevice/releases/latest" 2>/dev/null | grep '"tag_name":' | head -n1 | cut -d '"' -f 4 || echo "")
    
    if [ -z "$latest_tag" ]; then
        latest_tag="v9.5.0"
        log_warn "Tidak dapat menjangkau GitHub API secara langsung. Menggunakan fallback versi stabil: ${latest_tag}"
    else
        log_info "Versi terbaru GOWA ditemukan: ${C_BOLD}${C_GREEN}${latest_tag}${C_RESET}"
    fi

    local gowa_ver="${latest_tag#v}"

    # 2. Tentukan nama zip dan binary berdasarkan arsitektur perangkat
    local gowa_zip_name=""
    local gowa_inner_bin=""
    case "$ARCH_NAME" in
        amd64)
            gowa_zip_name="whatsapp_${gowa_ver}_linux_amd64.zip"
            gowa_inner_bin="linux-amd64"
            ;;
        arm64)
            gowa_zip_name="whatsapp_${gowa_ver}_linux_arm64.zip"
            gowa_inner_bin="linux-arm64"
            ;;
        armhf)
            gowa_zip_name="whatsapp_${gowa_ver}_linux_armv7.zip"
            gowa_inner_bin="linux-armv7"
            ;;
        *)
            gowa_zip_name="whatsapp_${gowa_ver}_linux_amd64.zip"
            gowa_inner_bin="linux-amd64"
            ;;
    esac

    local gowa_url="https://github.com/aldinokemal/go-whatsapp-web-multidevice/releases/download/${latest_tag}/${gowa_zip_name}"
    local tmp_zip="/tmp/${gowa_zip_name}"
    local tmp_extract="/tmp/gowa_extract"
    rm -rf "$tmp_extract" "$tmp_zip"
    mkdir -p "$tmp_extract" "${WA_DIR}/storages"

    run_task "Mengunduh & memasang binary WhatsApp Gateway (${latest_tag} - ${ARCH_NAME})" "curl -sSL -f '$gowa_url' -o '$tmp_zip' && unzip -q -o '$tmp_zip' -d '$tmp_extract' && if [ -f '${tmp_extract}/${gowa_inner_bin}' ]; then cp -f '${tmp_extract}/${gowa_inner_bin}' /usr/local/bin/whatsapp && cp -f '${tmp_extract}/${gowa_inner_bin}' '${WA_DIR}/whatsapp'; elif [ -f '${tmp_extract}/whatsapp' ]; then cp -f '${tmp_extract}/whatsapp' /usr/local/bin/whatsapp && cp -f '${tmp_extract}/whatsapp' '${WA_DIR}/whatsapp'; else found_bin=\$(find '$tmp_extract' -type f ! -name '*.md' ! -name '*.txt' | head -n1); [ -n \"\$found_bin\" ] && cp -f \"\$found_bin\" /usr/local/bin/whatsapp && cp -f \"\$found_bin\" '${WA_DIR}/whatsapp'; fi && chmod +x /usr/local/bin/whatsapp '${WA_DIR}/whatsapp' && ln -sf /usr/local/bin/whatsapp /usr/local/bin/gowa && rm -rf '$tmp_extract' '$tmp_zip'"

    # 3. Setup direktori & hak akses penyimpanan WhatsApp di /var/www/whatsapp
    mkdir -p "${WA_DIR}/storages"
    [ -f /usr/local/bin/whatsapp ] && [ ! -f "${WA_DIR}/whatsapp" ] && cp -f /usr/local/bin/whatsapp "${WA_DIR}/whatsapp"
    chmod +x "${WA_DIR}/whatsapp" 2>/dev/null || true
    chown -R ${WEB_USER}:${WEB_USER} "${WA_DIR}"

    # 4. Buat Systemd Service (Berjalan langsung dari /var/www/whatsapp)
    cat << EOF > /etc/systemd/system/whatsapp.service
[Unit]
Description=WhatsApp Gateway Multi-Device Service (JAGAT TECH)
After=network.target

[Service]
Type=simple
User=${WEB_USER}
WorkingDirectory=${WA_DIR}
ExecStart=${WA_DIR}/whatsapp rest --port=${WA_PORT} --basic-auth=${WA_USER}:${WA_PASS} --webhook=${WA_WEBHOOK_URL}
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    run_task "Mengaktifkan & menyalakan daemon WhatsApp Gateway (whatsapp.service)" "systemctl daemon-reload && systemctl enable whatsapp.service && (systemctl restart whatsapp.service || true)"
    log_success "Service WhatsApp Gateway (whatsapp.service) aktif di port ${WA_PORT}."
}

# --- 8. Clone, Build & Setup WhatsApp Bot Go (bot-go) ---
deploy_bot_wa_go() {
    log_step "[8/11] Mengunduh, Membangun & Memasang WhatsApp Bot Go (${BOT_GO_REPO})..."

    git config --global --add safe.directory "${BOT_GO_DIR}" 2>/dev/null || true

    if [ -d "${BOT_GO_DIR}/.git" ]; then
        run_task "Menarik commit terbaru WhatsApp Bot Go via Git (git pull)" "cd '${BOT_GO_DIR}' && (git pull origin main || git pull origin master)"
    else
        mkdir -p "${BOT_GO_DIR}"
        rm -rf "${BOT_GO_DIR:?}"/* "${BOT_GO_DIR:?}"/.[!.]* 2>/dev/null || true
        run_task "Mengunduh source code WhatsApp Bot Go dari GitHub (Shallow --depth 1)" "git clone --depth 1 --single-branch '${BOT_GO_REPO}' '${BOT_GO_DIR}'"
    fi

    cd "${BOT_GO_DIR}"

    # Buat file .env untuk bot-go (Lengkap & Serasi dengan DB & WA)
    log_info "Menyiapkan file .env untuk WhatsApp Bot Go..."
    cat << EOF > "${BOT_GO_DIR}/.env"
# ==============================================================================
#  ENV KONFIGURASI WHATSAPP BOT GO (JAGAT TECH)
# ==============================================================================

# Server Webhook Port (Menerima event pesan dari GOWA)
PORT=${BOT_GO_PORT}

# MariaDB Database Connection
DB_CONNECTION=mysql
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_DATABASE=${DB_NAME}
DB_USER=${DB_USER}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

# WhatsApp Gateway Connection (GOWA)
GOWA_API_BASE_URL=http://127.0.0.1:${WA_PORT}
GOWA_API_USER=${WA_USER}
GOWA_API_PASS=${WA_PASS}
WA_API_URL=http://127.0.0.1:${WA_PORT}
WA_API_BASE_URL=http://127.0.0.1:${WA_PORT}
WA_API_USER=${WA_USER}
WA_API_PASS=${WA_PASS}

# Server Web URL & Device Settings
APP_URL=${APP_URL}
WA_DEVICE_ID=1
SUPERADMIN_WA_ID=
EOF

    # Kompilasi binary Go
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

    run_task "Mengunduh Go module & mengompilasi binary bot_wa (Go Build)" "cd '${BOT_GO_DIR}' && (/usr/local/go/bin/go mod tidy || true) && /usr/local/go/bin/go build -o '${BOT_GO_DIR}/bot_wa' main.go"

    if [ -f "${BOT_GO_DIR}/bot_wa" ]; then
        chmod +x "${BOT_GO_DIR}/bot_wa"
    fi

    # Buat Systemd Service untuk Bot WhatsApp Go
    cat << EOF > /etc/systemd/system/bot_wa.service
[Unit]
Description=WhatsApp Bot Absensi Go Service (JAGAT TECH)
After=network.target mariadb.service mysql.service whatsapp.service
Wants=whatsapp.service

[Service]
Type=simple
User=root
WorkingDirectory=${BOT_GO_DIR}
ExecStart=${BOT_GO_DIR}/bot_wa
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    # Buat symlink /var/www/bot-wa -> /var/www/bot-go agar bisa diakses kedua nama
    ln -sf "${BOT_GO_DIR}" "${BOT_WA_LINK}"

    run_task "Mengaktifkan & menyalakan daemon WhatsApp Bot Go (bot_wa.service)" "systemctl daemon-reload && systemctl enable bot_wa.service && (systemctl restart bot_wa.service || true)"
    log_success "Service WhatsApp Bot Go (bot_wa.service) aktif di port ${BOT_GO_PORT}."
}

# --- 9. Clone, Build & Setup Telegram Bot Go (bot_tele) ---
deploy_bot_tele() {
    log_step "[9/11] Mengunduh, Membangun & Memasang Telegram Bot Go (${BOT_TELE_REPO})..."

    git config --global --add safe.directory "${BOT_TELE_DIR}" 2>/dev/null || true

    if [ -d "${BOT_TELE_DIR}/.git" ]; then
        run_task "Menarik commit terbaru Telegram Bot Go via Git (git pull)" "cd '${BOT_TELE_DIR}' && (git pull origin main || git pull origin master)"
    else
        mkdir -p "${BOT_TELE_DIR}"
        rm -rf "${BOT_TELE_DIR:?}"/* "${BOT_TELE_DIR:?}"/.[!.]* 2>/dev/null || true
        run_task "Mengunduh source code Telegram Bot Go dari GitHub (Shallow --depth 1)" "git clone --depth 1 --single-branch '${BOT_TELE_REPO}' '${BOT_TELE_DIR}'"
    fi

    cd "${BOT_TELE_DIR}"

    # Buat file .env untuk bot_tele (Serasi dengan MariaDB & Web App)
    log_info "Menyiapkan file .env untuk Telegram Bot..."
    cat << EOF > "${BOT_TELE_DIR}/.env"
# ==============================================================================
#  ENV KONFIGURASI TELEGRAM BOT GO (JAGAT TECH)
# ==============================================================================

# Database Connection Settings
DB_CONNECTION=mysql
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_DATABASE=${DB_NAME}
DB_NAME=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}

# Server Web URL Settings
APP_URL=${APP_URL}

# Telegram Bot Token (Dapatkan dari @BotFather di Telegram)
TELEGRAM_BOT_TOKEN=
EOF

    # Kompilasi binary Go
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

    run_task "Mengunduh Go module & mengompilasi binary bot_tele (Go Build)" "cd '${BOT_TELE_DIR}' && (/usr/local/go/bin/go mod tidy || true) && /usr/local/go/bin/go build -o '${BOT_TELE_DIR}/bot_tele' ."

    if [ -f "${BOT_TELE_DIR}/bot_tele" ]; then
        chmod +x "${BOT_TELE_DIR}/bot_tele"
    fi

    # Buat Systemd Service untuk Telegram Bot
    cat << EOF > /etc/systemd/system/bot_tele.service
[Unit]
Description=Telegram Bot Absensi Multi-Tenant Service (JAGAT TECH)
After=network.target mariadb.service mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=${BOT_TELE_DIR}
ExecStart=${BOT_TELE_DIR}/bot_tele
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    run_task "Mengaktifkan & menyalakan daemon Telegram Bot Go (bot_tele.service)" "systemctl daemon-reload && systemctl enable bot_tele.service && (systemctl restart bot_tele.service || true)"
    log_success "Service Telegram Bot Go (bot_tele.service) aktif dan berjalan."
}

# --- 10. Setup Nginx VirtualHost, Supervisor Queue & Cron ---
setup_services_and_vhost() {
    log_step "[10/11] Mengkonfigurasi Nginx, Queue Worker & Scheduler..."

    # Nginx VHost
    local vhost_file="/etc/nginx/sites-available/absen.conf"
    local nginx_server_name="${APP_DOMAIN}"
    if [ "${APP_DOMAIN}" = "localhost" ] || [ "${APP_DOMAIN}" = "127.0.0.1" ]; then
        nginx_server_name="localhost _"
    fi

    cat << EOF > "${vhost_file}"
server {
    listen 80;
    listen [::]:80;
    server_name ${nginx_server_name};
    root ${APP_DIR}/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";

    index index.php index.html;
    charset utf-8;

    client_max_body_size 64M;

    # WhatsApp Gateway Proxy
    location /wa-portal/ {
        proxy_pass http://127.0.0.1:${WA_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php${PHP_DEFAULT_VER}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
        fastcgi_read_timeout 300;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    access_log /var/log/nginx/absen_access.log;
    error_log /var/log/nginx/absen_error.log;
}
EOF

    run_task "Memasang & memverifikasi konfigurasi Nginx VirtualHost" "ln -sf '${vhost_file}' /etc/nginx/sites-enabled/absen.conf && rm -f /etc/nginx/sites-enabled/default 2>/dev/null && nginx -t && systemctl reload nginx"

    # Supervisor Queue Worker (hemat RAM pada S905X: 1 proses)
    local num_workers=2
    if [ "$IS_AMLOGIC_S905X" = true ] || [ "$TOTAL_RAM" -lt 1800 ]; then
        num_workers=1
    fi

    mkdir -p "${APP_DIR}/storage/logs"
    touch "${APP_DIR}/storage/logs/queue.log"
    chown -R ${WEB_USER}:${WEB_USER} "${APP_DIR}/storage"

    cat << EOF > /etc/supervisor/conf.d/absen-queue.conf
[program:absen-queue]
process_name=%(program_name)s_%(process_num)02d
command=php ${APP_DIR}/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
user=${WEB_USER}
numprocs=${num_workers}
redirect_stderr=true
stdout_logfile=${APP_DIR}/storage/logs/queue.log
stopwaitsecs=3600
EOF

    run_task "Menyiapkan & menyalakan antrian Supervisor (absen-queue)" "supervisorctl reread && supervisorctl update && (supervisorctl start absen-queue:* || true)"

    # Crontab Laravel Scheduler (Menggunakan direktori sistem /etc/cron.d/ yang stabil & bebas error pipe)
    run_task "Memasang penjadwal otomatis Crontab Laravel" "echo '* * * * * ${WEB_USER} cd ${APP_DIR} && php artisan schedule:run >> /dev/null 2>&1' > /etc/cron.d/absen-scheduler && chmod 644 /etc/cron.d/absen-scheduler"

    # Khusus Armbian: Set GPIO 73=0 saat startup boot (gpioset -c gpiochip1 73=0)
    if [ "$IS_ARMBIAN" = true ] || [ -f /etc/armbian-release ]; then
        log_info "Mengonfigurasi auto-startup GPIO (gpioset -c gpiochip1 73=0) khusus Armbian..."

        cat << 'EOF' > /etc/systemd/system/armbian-gpio.service
[Unit]
Description=Armbian GPIO Init Service (gpioset -c gpiochip1 73=0)
DefaultDependencies=no
After=sys-subsystem-gpio.devices basic.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'command -v gpioset >/dev/null 2>&1 && (gpioset -z -c gpiochip1 73=0 2>/dev/null || gpioset -m exit gpiochip1 73=0 2>/dev/null || timeout 2s gpioset -c gpiochip1 73=0 2>/dev/null || timeout 2s gpioset gpiochip1 73=0 2>/dev/null || true)'

[Install]
WantedBy=multi-user.target
EOF

        # Cadangan via /etc/rc.local (dijalankan di background '&' agar boot tidak macet)
        if [ ! -f /etc/rc.local ]; then
            cat << 'EOF' > /etc/rc.local
#!/bin/sh -e
exit 0
EOF
            chmod +x /etc/rc.local
        fi

        if ! grep -q 'gpiochip1 73=0' /etc/rc.local; then
            sed -i '/^exit 0/i (command -v gpioset >/dev/null 2>&1 && (gpioset -z -c gpiochip1 73=0 2>/dev/null || gpioset -m exit gpiochip1 73=0 2>/dev/null || timeout 2s gpioset -c gpiochip1 73=0 2>/dev/null || true)) & \n' /etc/rc.local
        fi

        run_task "Mengaktifkan service startup GPIO Armbian (gpiochip1 73=0)" "systemctl daemon-reload && systemctl enable armbian-gpio.service && (gpioset -z -c gpiochip1 73=0 2>/dev/null || gpioset -m exit gpiochip1 73=0 2>/dev/null || timeout 2s gpioset -c gpiochip1 73=0 2>/dev/null || timeout 2s gpioset gpiochip1 73=0 2>/dev/null || true)"
    fi

    log_success "Nginx VirtualHost, Worker Queue, dan Cron Scheduler berhasil aktif!"
}

# --- 11. Buat CLI Shortcut & Fitur Git Update Mudah ---
setup_cli_tool() {
    log_step "[11/11] Memasang Utility CLI & Fitur Git Update Otomatis..."

    cat << 'EOF' > /usr/local/bin/absen
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
        echo -n "Nginx Web Server  : "; systemctl is-active nginx
        echo -n "PHP 8.3 FPM       : "; systemctl is-active php8.3-fpm
        echo -n "Database MariaDB  : "; systemctl is-active mariadb 2>/dev/null || systemctl is-active mysql
        echo -n "WhatsApp Gateway  : "; systemctl is-active whatsapp.service 2>/dev/null || systemctl is-active gowa
        echo -n "WhatsApp Bot Go   : "; systemctl is-active bot_wa.service 2>/dev/null || echo -e "${YELLOW}Non-aktif${NC}"
        echo -n "Telegram Bot Go   : "; systemctl is-active bot_tele.service 2>/dev/null || echo -e "${YELLOW}Non-aktif${NC}"
        echo -n "Queue Worker      : "
        supervisorctl status absen-queue:* 2>/dev/null || echo -e "${YELLOW}Non-aktif${NC}"
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
    logs)
        case "$2" in
            tele)
                journalctl -u bot_tele.service -f -n 50
                ;;
            bot)
                journalctl -u bot_wa.service -f -n 50
                ;;
            queue)
                tail -n 50 -f "$APP_DIR/storage/logs/queue.log"
                ;;
            wa)
                journalctl -u whatsapp.service -f -n 50
                ;;
            nginx)
                tail -n 50 -f /var/log/nginx/absen_error.log
                ;;
            *)
                tail -n 50 -f "$APP_DIR/storage/logs/laravel.log"
                ;;
        esac
        ;;
    swap-delete|swap-off|del-swap)
        echo -e "${YELLOW}Menonaktifkan dan menghapus Swap File 2GB...${NC}"
        if [ -f /swapfile ] || grep -q '/swapfile' /proc/swaps 2>/dev/null; then
            swapoff /swapfile 2>/dev/null || true
            sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null || true
            rm -f /swapfile 2>/dev/null || true
            echo -e "${GREEN}${BOLD}✔ Swapfile 2GB berhasil dinonaktifkan dan dihapus dari penyimpanan internal eMMC!${NC}"
            echo -e "${CYAN}Sisa ruang penyimpanan saat ini:${NC}"
            df -h /
        else
            echo -e "${GREEN}Swapfile (/swapfile) tidak aktif atau sudah dihapus sebelumnya.${NC}"
        fi
        ;;
    swap-create|swap-on)
        echo -e "${YELLOW}Membuat kembali Swap File 2GB (Aman untuk eMMC)...${NC}"
        if [ ! -f /swapfile ]; then
            fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            if ! grep -q '/swapfile' /etc/fstab; then
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
            fi
            sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
            echo 'vm.swappiness=10' > /etc/sysctl.d/99-jagat-swap.conf 2>/dev/null || true
            echo -e "${GREEN}${BOLD}✔ Swapfile 2GB berhasil dibuat dan diaktifkan (swappiness=10)!${NC}"
            free -h
        else
            swapon /swapfile 2>/dev/null || true
            echo -e "${GREEN}Swapfile sudah ada dan aktif.${NC}"
            free -h
        fi
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
        echo -e "  ${GREEN}absen swap-delete${NC}    - Hapus Swap File 2GB untuk melegakan penyimpanan internal eMMC"
        echo -e "  ${GREEN}absen swap-create${NC}    - Buat kembali Swap File 2GB jika sewaktu-waktu dibutuhkan"
        echo -e "  ${GREEN}absen logs${NC}           - Pantau log Laravel secara realtime"
        echo -e "  ${GREEN}absen logs bot${NC}       - Pantau log WhatsApp Bot Go realtime"
        echo -e "  ${GREEN}absen logs tele${NC}      - Pantau log Telegram Bot Go realtime"
        echo -e "  ${GREEN}absen logs wa${NC}        - Pantau log WhatsApp Gateway (GOWA)"
        echo -e "  ${GREEN}absen logs queue${NC}     - Pantau log antrian proses background (queue)"
        echo -e "  ${GREEN}absen logs nginx${NC}     - Pantau log error web server Nginx"
        echo ""
        ;;
esac
EOF

    chmod +x /usr/local/bin/absen
    log_success "Command '${C_BOLD}absen${C_RESET}' berhasil dibuat di /usr/local/bin/absen."
}

# --- Ringkasan Hasil Akhir ---
show_summary() {
    local wa_status="Non-aktif"
    if systemctl is-active --quiet whatsapp.service 2>/dev/null || systemctl is-active --quiet gowa 2>/dev/null; then
        wa_status="${C_GREEN}Aktif (Running)${C_RESET}"
    fi

    local bot_status="Non-aktif"
    if systemctl is-active --quiet bot_wa.service 2>/dev/null; then
        bot_status="${C_GREEN}Aktif (Running)${C_RESET}"
    fi

    local tele_status="Non-aktif"
    if systemctl is-active --quiet bot_tele.service 2>/dev/null; then
        tele_status="${C_GREEN}Aktif (Running)${C_RESET}"
    fi

    echo ""
    echo -e "${C_GREEN}${C_BOLD}"
    cat << "EOF"
  ███████╗███████╗██╗     ███████╗███████╗ █████╗ ██╗
  ██╔════╝██╔════╝██║     ██╔════╝██╔════╝██╔══██╗██║
  ███████╗█████╗  ██║     █████╗  ███████╗███████║██║
  ╚════██║██╔══╝  ██║     ██╔══╝  ╚════██║██╔══██║██║
  ███████║███████╗███████╗███████╗███████║██║  ██║██║
  ╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝
EOF
    echo -e "${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}==============================================================================${C_RESET}"
    echo -e "${C_WHITE}${C_BOLD}   🎉 INSTALASI WEB ABSENSI, BOT WHATSAPP & TELEGRAM JAGAT TECH SELESAI! 🎉${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}==============================================================================${C_RESET}"
    echo ""
    echo -e "${C_BOLD}🌐 INFORMASI AKSES WEB ABSENSI:${C_RESET}"
    echo -e "   • Alamat Web        : ${C_BOLD}${C_GREEN}${APP_URL}${C_RESET}"
    echo -e "   • Direktori Web     : ${C_WHITE}${APP_DIR}${C_RESET}"
    echo -e "   • Sumber Git        : ${C_CYAN}${GIT_REPO}${C_RESET}"
    echo -e "   • Target Perangkat  : ${C_YELLOW}${DEVICE_TITLE}${C_RESET}"
    echo ""
    echo -e "${C_BOLD}📱 WHATSAPP GATEWAY (GOWA):${C_RESET}"
    echo -e "   • Status Layanan    : ${wa_status}"
    echo -e "   • URL Scan QR       : ${C_BOLD}${C_CYAN}http://${SERVER_IP}:${WA_PORT}${C_RESET}"
    echo -e "   • Basic Auth User   : ${C_WHITE}${WA_USER}${C_RESET}"
    echo -e "   • Basic Auth Pass   : ${C_YELLOW}${WA_PASS}${C_RESET}"
    echo -e "   • Webhook Target    : ${C_CYAN}${WA_WEBHOOK_URL}${C_RESET}"
    echo -e "   • Cara Pairing HP   : Buka URL di atas > Klik Login > Scan QR dengan WhatsApp di HP"
    echo ""
    echo -e "${C_BOLD}🤖 WHATSAPP BOT GO (DAEMON):${C_RESET}"
    echo -e "   • Status Layanan    : ${bot_status}"
    echo -e "   • Webhook Port      : ${C_WHITE}Port ${BOT_GO_PORT}/webhook${C_RESET}"
    echo -e "   • Direktori Bot     : ${C_WHITE}${BOT_GO_DIR}${C_RESET}"
    echo -e "   • Sumber Git        : ${C_CYAN}${BOT_GO_REPO}${C_RESET}"
    echo ""
    echo -e "${C_BOLD}✈️ TELEGRAM BOT GO (DAEMON):${C_RESET}"
    echo -e "   • Status Layanan    : ${tele_status}"
    echo -e "   • Direktori Bot     : ${C_WHITE}${BOT_TELE_DIR}${C_RESET}"
    echo -e "   • Sumber Git        : ${C_CYAN}${BOT_TELE_REPO}${C_RESET}"
    echo ""
    echo -e "${C_BOLD}🗄️ KONEKSI DATABASE MARIADB:${C_RESET}"
    echo -e "   • Database Name     : ${C_WHITE}${DB_NAME}${C_RESET}"
    echo -e "   • Database User     : ${C_WHITE}${DB_USER}${C_RESET}"
    echo -e "   • Database Password : ${C_YELLOW}${DB_PASS}${C_RESET}"
    echo ""
    echo -e "${C_BOLD}🔄 CARA UPDATE DI KEMUDIAN HARI (SANGAT MUDAH):${C_RESET}"
    echo -e "   Cukup jalankan satu perintah ini kapan saja di terminal:"
    echo -e "   ${C_BOLD}${C_GREEN}absen update${C_RESET}"
    echo -e "   ${C_DIM}(Otomatis git pull web, bot wa & bot tele, composer, migrate, go build & optimize!)${C_RESET}"
    echo ""
    echo -e "${C_BOLD}💾 PENGELOLAAN MEMORI & STORAGE EMMC:${C_RESET}"
    echo -e "   • Hapus Swap 2GB    : ${C_GREEN}absen swap-delete${C_RESET} ${C_DIM}(Melegakan kembali 2GB ruang eMMC)${C_RESET}"
    echo -e "   • Buat Swap 2GB     : ${C_GREEN}absen swap-create${C_RESET} ${C_DIM}(Aktifkan kembali jika butuh swap)${C_RESET}"
    echo ""
    echo -e "${C_BOLD}🛠️ PERINTAH PINTAS LAINNYA:${C_RESET}"
    echo -e "   • Cek status server : ${C_GREEN}absen status${C_RESET}"
    echo -e "   • Restart service   : ${C_GREEN}absen restart${C_RESET}"
    echo -e "   • Pantau log web    : ${C_GREEN}absen logs${C_RESET}"
    echo -e "   • Pantau log bot WA : ${C_GREEN}absen logs bot${C_RESET}"
    echo -e "   • Pantau log tele   : ${C_GREEN}absen logs tele${C_RESET}"
    echo -e "   • Pantau log WA GW  : ${C_GREEN}absen logs wa${C_RESET}"
    echo -e "   • Pantau log queue  : ${C_GREEN}absen logs queue${C_RESET}"
    echo ""
    echo -e "${C_CYAN}==============================================================================${C_RESET}"
    echo -e "${C_DIM}Log lengkap proses instalasi tersimpan di: ${LOG_FILE}${C_RESET}"
    echo ""
}

# --- Alur Eksekusi Utama ---
main() {
    AUTO_YES=false
    for arg in "$@"; do
        case "$arg" in
            -y|--yes|--unattended)
                AUTO_YES=true
                ;;
        esac
    done

    show_banner
    check_root
    detect_system
    check_ram_and_swap
    collect_inputs

    install_base_tools
    install_nginx
    install_php
    install_database
    install_composer_and_go
    deploy_web_absen
    install_gowa_whatsapp
    deploy_bot_wa_go
    deploy_bot_tele
    setup_services_and_vhost
    setup_cli_tool

    show_summary
}

main "$@"
