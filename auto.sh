#!/bin/bash
#
# ==============================================================
#  Pterodactyl Theme Installer
#  Repo: https://github.com/fr3newera/aerodynamic-ecosystem
# ==============================================================

set -e

PANEL_DIR="/var/www/pterodactyl"
THEME_URL="https://raw.githubusercontent.com/fr3newera/aerodynamic-ecosystem/main/auto.tar.gz"
SCRIPT_URL="https://raw.githubusercontent.com/fr3newera/aerodynamic-ecosystem/main/auto.sh"
BACKUP_DIR="/root/pterodactyl-backup-$(date +%Y%m%d-%H%M%S)"
TMP_DIR="$(mktemp -d)"

# ---- Self-update ----
# Setiap kali script ini dijalankan (termasuk lewat curl | bash), ia otomatis
# mengambil versi terbaru auto.sh dari GitHub lalu menjalankan versi itu,
# supaya perbaikan/patch terbaru (misalnya fix migration di bawah) selalu
# ikut terpakai tanpa perlu update manual. AUTO_SH_NO_SELF_UPDATE mencegah loop.
if [ -z "$AUTO_SH_NO_SELF_UPDATE" ]; then
  LATEST_TMP="$(mktemp)"
  if curl -fsSL "$SCRIPT_URL" -o "$LATEST_TMP" 2>/dev/null && [ -s "$LATEST_TMP" ]; then
    echo "Mengecek update... menjalankan versi terbaru dari GitHub."
    export AUTO_SH_NO_SELF_UPDATE=1
    exec bash "$LATEST_TMP" "$@"
  fi
  rm -f "$LATEST_TMP" 2>/dev/null || true
  echo "  (Gagal cek update, lanjut pakai versi lokal.)"
fi

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
echo "[1/7] Menyiapkan environment & dependency..."
# Auto install Node.js 20 & Yarn jika belum terpasang di server buyer
if ! command -v node >/dev/null 2>&1 || ! command -v yarn >/dev/null 2>&1; then
  echo "  -> Node.js / Yarn tidak ditemukan. Menginstall Node.js 20 & Yarn..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || true
  apt-get install -y nodejs >/dev/null 2>&1 || true
  npm install -g yarn >/dev/null 2>&1 || true
fi

echo ""
echo "[2/7] Backup panel saat ini ke $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
cp -a "$PANEL_DIR/resources" "$BACKUP_DIR/resources" 2>/dev/null || true
cp -a "$PANEL_DIR/public"    "$BACKUP_DIR/public"    2>/dev/null || true
cp -a "$PANEL_DIR/app"       "$BACKUP_DIR/app"       2>/dev/null || true
cp -a "$PANEL_DIR/database"  "$BACKUP_DIR/database"  2>/dev/null || true
echo "  OK. Backup tersimpan di: $BACKUP_DIR"

echo ""
echo "[3/7] Download source tema..."
curl -fsSL "$THEME_URL" -o "$TMP_DIR/auto.tar.gz" || fail "Gagal download $THEME_URL"
mkdir -p "$TMP_DIR/extracted"
tar -xzf "$TMP_DIR/auto.tar.gz" -C "$TMP_DIR/extracted" || fail "Gagal extract auto.tar.gz"
echo "  OK."

echo ""
echo "[4/7] Copy file tema ke panel..."
SRC_DIR="$TMP_DIR/extracted"
if [ ! -d "$SRC_DIR/app" ] && [ $(ls -1 "$SRC_DIR" | wc -l) -eq 1 ]; then
  SUBFOLDER=$(ls -1 "$SRC_DIR")
  if [ -d "$SRC_DIR/$SUBFOLDER/app" ]; then
    SRC_DIR="$SRC_DIR/$SUBFOLDER"
  fi
fi

rsync -a \
  --exclude ".env" \
  --exclude "storage/framework/" \
  --exclude "storage/logs/" \
  --exclude "vendor/" \
  --exclude "node_modules/" \
  --exclude ".git/" \
  "$SRC_DIR/" "$PANEL_DIR/" || fail "Gagal menyalin file tema"
echo "  OK."

echo ""
echo "[5/7] Fix & patch file migration..."
# users.id di Pterodactyl adalah INT UNSIGNED (bukan BIGINT), jadi kolom FK harus
# unsignedInteger + foreign() biasa. Pakai foreignId()/foreignIdFor() akan bikin
# BIGINT UNSIGNED dan gagal (errno 150) karena tipe tidak cocok dengan users.id.
REG_MIGRATION=$(find "$PANEL_DIR/database/migrations" -type f -name "*create_registration_codes_table.php" | head -n1)
if [ -n "$REG_MIGRATION" ]; then
  # Ganti foreignId('xxx')->...->constrained('users')->yyy()  ->  unsignedInteger + foreign() terpisah
  perl -0pi -e "s/\\\$table->foreignId\('(\w+)'\)((?:->\w+\([^)]*\))*)->constrained\('users'\)((?:->\w+\([^)]*\))*);/\\\$table->unsignedInteger('\1')\2;/g" "$REG_MIGRATION"
  # Normalisasi jika sebelumnya sempat ke-set sebagai bigint
  sed -i "s/unsignedBigInteger('used_by_user_id')/unsignedInteger('used_by_user_id')/g" "$REG_MIGRATION"
  sed -i "s/unsignedBigInteger('created_by_user_id')/unsignedInteger('created_by_user_id')/g" "$REG_MIGRATION"
  # Pastikan constraint foreign key ke users.id ditambahkan (idempotent)
  for COL in used_by_user_id created_by_user_id; do
    if ! grep -q "foreign('$COL')" "$REG_MIGRATION"; then
      sed -i "/\$table->timestamps();/i\\            \$table->foreign('$COL')->references('id')->on('users')->nullOnDelete();" "$REG_MIGRATION"
    fi
  done
fi
echo "  OK."

echo ""
echo "[6/7] Install dependency PHP & jalankan migration..."
cd "$PANEL_DIR"
composer install --no-dev --optimize-autoloader --no-interaction || fail "composer install gagal"
php artisan migrate --force || fail "Migration gagal"
php artisan optimize:clear
echo "  OK."

echo ""
echo "[7/7] Build frontend & fix permission..."
if command -v yarn >/dev/null 2>&1; then
  yarn install --silent && yarn build:production || fail "yarn build gagal"
elif command -v npm >/dev/null 2>&1; then
  npm install --silent && npm run build:production || fail "npm build gagal"
else
  fail "Gagal menemukan yarn/npm untuk build frontend."
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
