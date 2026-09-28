#!/usr/bin/env bash
# ==============================================================================
#  BACKUP SCRIPT - SISTEM ABSENSI (DATABASE & STORAGE)
# ==============================================================================
set -euo pipefail

BACKUP_DIR="/var/backups/absen"
APP_DIR="/var/www/web"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7

mkdir -p "${BACKUP_DIR}"

# 1. Parse Database Credentials from .env
if [ -f "${APP_DIR}/.env" ]; then
    DB_NAME=$(grep -E '^DB_DATABASE=' "${APP_DIR}/.env" | cut -d '=' -f2 | tr -d '"'\'' ')
    DB_USER=$(grep -E '^DB_USERNAME=' "${APP_DIR}/.env" | cut -d '=' -f2 | tr -d '"'\'' ')
    DB_PASS=$(grep -E '^DB_PASSWORD=' "${APP_DIR}/.env" | cut -d '=' -f2 | tr -d '"'\'' ')
else
    echo "Error: File .env tidak ditemukan di ${APP_DIR}!"
    exit 1
fi

echo "[1/3] Membackup Database MySQL (${DB_NAME})..."
DB_BACKUP_FILE="${BACKUP_DIR}/db_${DB_NAME}_${TIMESTAMP}.sql.gz"
mysqldump -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" | gzip > "${DB_BACKUP_FILE}"
echo "      ✔ Database tersimpan: ${DB_BACKUP_FILE}"

echo "[2/3] Membackup Storage & File Upload..."
STORAGE_BACKUP_FILE="${BACKUP_DIR}/storage_${TIMESTAMP}.tar.gz"
if [ -d "${APP_DIR}/storage/app" ]; then
    tar -czf "${STORAGE_BACKUP_FILE}" -C "${APP_DIR}/storage" app
    echo "      ✔ Storage tersimpan: ${STORAGE_BACKUP_FILE}"
fi

echo "[3/3] Membersihkan backup lama (> ${RETENTION_DAYS} hari)..."
find "${BACKUP_DIR}" -type f -name "*.gz" -mtime +"${RETENTION_DAYS}" -delete
echo "      ✔ Pembersihan selesai."

echo "Backup berhasil diselesaikan pada $(date)!"
