#!/usr/bin/env bash
# ==============================================================================
#  JAGAT TECH - ONE-LINE QUICK INSTALLER BOOTSTRAP
# ==============================================================================
set -e

TMP_DIR=$(mktemp -d)
INSTALLER_URL="https://raw.githubusercontent.com/kangdaqiq/autoinstal/main/install.sh"

echo "=== JAGAT TECH AUTO INSTALLER ==="
echo "Mengunduh script installer..."

if command -v curl &> /dev/null; then
    curl -sSL "$INSTALLER_URL" -o "${TMP_DIR}/install.sh"
elif command -v wget &> /dev/null; then
    wget -qO "${TMP_DIR}/install.sh" "$INSTALLER_URL"
else
    apt-get update -y && apt-get install -y curl
    curl -sSL "$INSTALLER_URL" -o "${TMP_DIR}/install.sh"
fi

chmod +x "${TMP_DIR}/install.sh"

# Sambungkan kembali stdin ke terminal /dev/tty agar input interaktif berfungsi saat di-pipe
if [ -r /dev/tty ]; then
    bash "${TMP_DIR}/install.sh" "$@" </dev/tty
else
    bash "${TMP_DIR}/install.sh" "$@"
fi

rm -rf "${TMP_DIR}"
