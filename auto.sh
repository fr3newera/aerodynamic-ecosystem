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
#   3. Replace file tema (views, public assets, resources, app, database)
#   4. Jalankan composer install, migration, dan clear cache
#   5. Build frontend (yarn/npm)
#
#  Penggunaan:
#    curl -fsSL https://github.com/aerodynamic-ecosystem/auto.sh/releases/latest/download/auto.sh | bash
#
# ==============================================================

set -e

PANEL_DIR="/var/www/pterodactyl"
THEME_URL="https://raw.githubusercontent.com/aerodynamic-ecosystem/auto.sh/main/auto.tar.gz"
BACKUP_DIR="/root/pterodactyl-backup-$(date +%Y%m%d-%H%M%S)"
TMP_DIR="$(mktemp -d)"

fail() {
  echo ""
  echo "GAGAL: $1" >&2
  exit 1
}

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

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
cp -a "$PANEL_DIR/public"    "$BACKUP_DIR/public"    2>/dev/null || true
cp -a "$PANEL_DIR/app"       "$BACKUP_DIR/app"       2>/dev/null || true
cp -a "$PANEL_DIR/database"  "$BACKUP_DIR/database"  2>/dev/null || true
echo "  OK. Backup tersimpan di: $BACKUP_DIR"

echo ""
echo "[2/6] Download source tema..."
curl -fsSL "$THEME_URL" -o "$TMP_DIR/auto.tar.gz" || fail "Gagal download $THEME_URL"
mkdir -p "$TMP_DIR/extracted"
tar -xzf "$TMP_DIR/auto.tar.gz" -C "$TMP_DIR/extracted" || fail "Gagal extract auto.tar.gz"
echo "  OK."

echo ""
echo "[3/6] Copy file tema ke panel..."
echo "  (Tidak menimpa .env, storage/framework, storage/logs, vendor, node_modules)"
rsync -a \
  --exclude ".env" \
  --exclude "storage/framework/" \
  --exclude "storage/logs/" \
  --exclude "vendor/" \
  --exclude "node_modules/" \
  --exclude ".git/" \
  "$TMP_DIR/extracted/" "$PANEL_DIR/" || fail "Gagal menyalin file tema"
echo "  OK."

echo ""
echo "[4/6] Install dependency PHP..."
cd "$PANEL_DIR"
composer install --no-dev --optimize-autoloader --no-interaction || fail "composer install gagal"
echo "  OK."

echo ""
echo "[5/6] Jalankan migration & clear cache..."
php artisan migrate --force || fail "Migration gagal"
php artisan optimize:clear
echo "  OK."

echo ""
echo "[6/6] Build frontend & fix permission..."
if command -v yarn >/dev/null 2>&1; then
  yarn install --silent && yarn build:production || fail "yarn build gagal"
elif command -v npm >/dev/null 2>&1; then
  npm install --silent && npm run build:production || fail "npm build gagal"
else
  fail "yarn/npm tidak ditemukan di server, install salah satu dulu."
fi

chown -R www-data:www-data "$PANEL_DIR"
chmod -R 775 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
php artisan queue:restart || true
echo "  OK."

echo ""
echo "=============================================="
echo " SELESAI! Tema berhasil terpasang."
echo " Backup file lama ada di: $BACKUP_DIR"
echo "=============================================="
