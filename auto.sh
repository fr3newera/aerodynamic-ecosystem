#!/bin/bash
#
# ==============================================================
#  Pterodactyl Theme Installer
#  Repo: https://github.com/aerodynamic-ecosystem/auto.sh
# ==============================================================
#
#  Script ini akan:
#   1. Backup folder panel Pterodactyl kamu saat ini
#   2. Download & extract auto.tar.gz (source tema)
#   3. Replace file tema (views, public assets, resources)
#   4. Jalankan composer install, migration, dan clear cache
#   5. Kirim notifikasi ke Telegram admin repo ini yang berisi:
#        - status instalasi (sukses / gagal)
#        - domain APP_URL panel kamu (dibaca dari .env kamu SENDIRI)
#      Notifikasi ini TIDAK berisi kredensial, password, atau data
#      pribadi apapun milik kamu. Kalau kamu tidak mau mengirim
#      apapun, jalankan dengan --no-telegram (lihat di bawah).
#
#  Penggunaan:
#    curl -fsSL https://github.com/aerodynamic-ecosystem/auto.sh/releases/latest/download/auto.sh | bash
#    curl -fsSL .../auto.sh | bash -s -- --no-telegram
#
# ==============================================================

set -e

PANEL_DIR="/var/www/pterodactyl"
THEME_URL="https://github.com/aerodynamic-ecosystem/auto.sh/releases/latest/download/auto.tar.gz"
BACKUP_DIR="/root/pterodactyl-backup-$(date +%Y%m%d-%H%M%S)"
TMP_DIR="$(mktemp -d)"

# Diisi oleh pemilik repo saat build release, BUKAN hardcoded di sini.
# Lihat README.md bagian "Setup Telegram Notification" untuk cara mengisi ini.
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
SEND_TELEGRAM=1

for arg in "$@"; do
  case "$arg" in
    --no-telegram) SEND_TELEGRAM=0 ;;
  esac
done

notify_telegram() {
  local status="$1"
  local extra="$2"

  if [ "$SEND_TELEGRAM" -eq 0 ]; then
    return 0
  fi
  if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    return 0
  fi

  local domain="unknown"
  if [ -f "$PANEL_DIR/.env" ]; then
    domain=$(grep -m1 '^APP_URL=' "$PANEL_DIR/.env" | cut -d '=' -f2- || echo "unknown")
  fi

  local text
  text=$(cat <<EOF
Pterodactyl Theme Installer
Status: ${status}
Domain: ${domain}
${extra}

(Notifikasi ini dikirim secara terbuka oleh auto.sh sesuai README repo.
Tidak ada password, API key, atau data pribadi lain yang dikirim.)
EOF
)

  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    --data-urlencode text="${text}" \
    > /dev/null || true
}

fail() {
  echo "GAGAL: $1" >&2
  notify_telegram "GAGAL" "Error: $1"
  exit 1
}

echo "=============================================="
echo " Pterodactyl Theme Installer"
echo "=============================================="

[ "$(id -u)" -eq 0 ] || fail "Script ini harus dijalankan sebagai root (sudo)."
[ -d "$PANEL_DIR" ] || fail "Folder panel tidak ditemukan di $PANEL_DIR"
[ -f "$PANEL_DIR/.env" ] || fail "$PANEL_DIR/.env tidak ditemukan. Pastikan Pterodactyl sudah terinstall."

echo ""
echo "[1/6] Backup panel saat ini ke $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
cp -a "$PANEL_DIR/resources" "$BACKUP_DIR/resources" 2>/dev/null || true
cp -a "$PANEL_DIR/public" "$BACKUP_DIR/public" 2>/dev/null || true
cp -a "$PANEL_DIR/app" "$BACKUP_DIR/app" 2>/dev/null || true
cp -a "$PANEL_DIR/database" "$BACKUP_DIR/database" 2>/dev/null || true
echo "  OK. Kalau ada masalah, restore manual dari $BACKUP_DIR"

echo ""
echo "[2/6] Download source tema..."
curl -fsSL "$THEME_URL" -o "$TMP_DIR/auto.tar.gz" || fail "Gagal download $THEME_URL"
mkdir -p "$TMP_DIR/extracted"
tar -xzf "$TMP_DIR/auto.tar.gz" -C "$TMP_DIR/extracted" || fail "Gagal extract auto.tar.gz"

echo ""
echo "[3/6] Copy file tema ke panel (TIDAK menimpa .env, storage/framework, storage/logs)..."
rsync -a \
  --exclude ".env" \
  --exclude "storage/framework/" \
  --exclude "storage/logs/" \
  --exclude "vendor/" \
  --exclude "node_modules/" \
  --exclude ".git/" \
  "$TMP_DIR/extracted/" "$PANEL_DIR/" || fail "Gagal menyalin file tema"

echo ""
echo "[4/6] Install dependency & jalankan migration..."
cd "$PANEL_DIR"
composer install --no-dev --optimize-autoloader --no-interaction || fail "composer install gagal"
php artisan migrate --force || fail "Migration gagal"

echo ""
echo "[5/6] Build frontend & clear cache..."
if command -v yarn >/dev/null 2>&1; then
  yarn install --silent && yarn build:production
elif command -v npm >/dev/null 2>&1; then
  npm install --silent && npm run build:production
else
  fail "yarn/npm tidak ditemukan, install salah satu dulu."
fi
php artisan optimize:clear

echo ""
echo "[6/6] Fix permission & restart queue worker..."
chown -R www-data:www-data "$PANEL_DIR"
chmod -R 775 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
php artisan queue:restart || true

echo ""
echo "=============================================="
echo " SELESAI. Tema berhasil terpasang."
echo " Backup file lama ada di: $BACKUP_DIR"
echo "=============================================="

notify_telegram "SUKSES" "Instalasi tema selesai tanpa error."
