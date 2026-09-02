# AERODYNAMIC ECOSYSTEM Installer

Installer satu-baris untuk memasang tema custom ke panel Pterodactyl yang **sudah terinstall**.

## Cara pakai

```bash
curl -fsSL https://github.com/aerodynamic-ecosystem/auto.sh/releases/latest/download/auto.sh | bash
```

Jalankan sebagai root/sudo, di server yang sudah punya Pterodactyl panel di `/var/www/pterodactyl`.

Kalau tidak ingin mengirim notifikasi apapun ke maintainer repo ini:

```bash
curl -fsSL https://github.com/aerodynamic-ecosystem/auto.sh/releases/latest/download/auto.sh | bash -s -- --no-telegram
```

## Apa yang dilakukan script ini

1. Backup `resources/`, `public/`, `app/`, `database/` panel kamu saat ini ke `/root/pterodactyl-backup-<timestamp>`.
2. Download `auto.tar.gz` (source tema) dari GitHub Release repo ini.
3. Menyalin file tema ke panel kamu — **tidak pernah menimpa** `.env`, `storage/framework/`, `storage/logs/`, `vendor/`, `node_modules/`.
4. `composer install`, `php artisan migrate --force`, build frontend, clear cache.
5. Mengirim satu notifikasi ke Telegram maintainer repo berisi **status instalasi (sukses/gagal) dan domain `APP_URL` panel kamu** — tidak lebih. Tidak ada password, API key, IP pengunjung lain, atau data pengguna panel kamu yang dikirim. Ini murni telemetry instalasi opsional, dan kamu bisa mematikannya dengan flag `--no-telegram` di atas.

## Setup Telegram Notification (untuk maintainer/fork repo ini)

Kalau kamu fork repo ini dan mau notifikasi instalasi masuk ke Telegram kamu sendiri:

1. Buat file `.env.telegram` (jangan commit ke Git — sudah ada di `.gitignore`):
   ```
   TELEGRAM_BOT_TOKEN=isi_token_bot_kamu
   TELEGRAM_CHAT_ID=isi_chat_id_kamu
   ```
2. Saat build release, export variabel itu lalu embed ke `auto.sh` versi rilis kamu, atau minta pengguna export sendiri sebelum menjalankan:
   ```bash
   export TELEGRAM_BOT_TOKEN="xxxx"
   export TELEGRAM_CHAT_ID="xxxx"
   curl -fsSL .../auto.sh | bash
   ```

**Jangan hardcode bot token ke `auto.sh` yang di-publish ke repo publik** — siapapun yang bisa membaca script bisa memakai bot token itu untuk mengirim pesan atas nama bot kamu. Simpan token sebagai secret di CI/CD (GitHub Actions secrets) kalau ingin proses build otomatis meng-inject-nya ke rilis privat/berbayar.

## File di repo ini

- `auto.sh` — installer utama.
- `auto.tar.gz` (di GitHub Releases, bukan di repo langsung karena ukurannya besar) — source tema yang akan di-extract & disalin ke panel.

## Catatan keamanan

- Script ini **tidak** mengumpulkan IP, username, atau data pribadi siapapun yang menjalankannya.
- Script ini **tidak** memiliki kemampuan mematikan atau merusak panel dari jarak jauh.
- Selalu review isi `auto.sh` sebelum menjalankan `curl | bash` dari sumber manapun, termasuk repo ini.
