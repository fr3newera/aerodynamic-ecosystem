# AERODYNAMIC ECOSYSTEM Installer

Installer satu-baris untuk memasang tema custom ke panel Pterodactyl yang sudah terinstall.

## Cara pakai

```bash
curl -fsSL https://github.com/aerodynamic-ecosystem/auto.sh/releases/latest/download/auto.sh | bash
```

Jalankan sebagai **root** di server yang sudah punya Pterodactyl panel di `/var/www/pterodactyl`.

## Yang dilakukan script ini

| Step | Aksi |
|------|------|
| 1 | Backup `resources/`, `public/`, `app/`, `database/` ke `/root/pterodactyl-backup-<timestamp>` |
| 2 | Download `auto.tar.gz` dari GitHub Releases repo ini |
| 3 | Copy file tema ke panel — **tanpa menimpa** `.env`, `storage/`, `vendor/`, `node_modules/` |
| 4 | `composer install --no-dev` |
| 5 | `php artisan migrate --force` + `optimize:clear` |
| 6 | Build frontend (yarn/npm) + fix permission |

## Syarat server

- Pterodactyl Panel sudah terinstall di `/var/www/pterodactyl`
- PHP 8.x + Composer
- Node.js + yarn atau npm
- Akses root/sudo

## Fitur tema

- Sistem registrasi dengan kode undangan
- Wallet & store (beli resource/server)
- Payment gateway terintegrasi
- AI Agent chat per server

## Setup GitHub Releases (untuk maintainer)

1. Push `auto.sh` dan `README.md` ke branch `main`.
2. Upload `auto.tar.gz` sebagai **Release Asset** (bukan file di repo langsung).
3. Pastikan URL `THEME_URL` di dalam `auto.sh` sesuai dengan link release terbaru.
