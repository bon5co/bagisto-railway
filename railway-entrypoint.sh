#!/bin/bash
# Railway boot sequence for Bagisto.
set -euo pipefail

APP_DIR=/var/www/bagisto
STORAGE="$APP_DIR/storage"
STATE="$STORAGE/railway"

log() { echo "[railway] $*"; }

if [ -z "${BAGISTO_ADMIN_EMAIL:-}" ] || [ -z "${BAGISTO_ADMIN_PASSWORD:-}" ]; then
    log "FATAL: BAGISTO_ADMIN_EMAIL and BAGISTO_ADMIN_PASSWORD must be set."
    log "Refusing to boot: without them Bagisto seeds the publicly known"
    log "admin@example.com / admin123 account on a public URL."
    exit 1
fi

# Railway mounts the volume owned by uid 0; the application runs as www-data.
mkdir -p "$STORAGE"/framework/{sessions,views,cache/data} \
         "$STORAGE"/logs "$STORAGE"/app/public "$STATE"
chown -R www-data:www-data "$STORAGE"
chmod -R 775 "$STORAGE"

# A Laravel APP_KEY must decode to 32 bytes. Generate one once and keep it on
# the volume, so sessions, cookies and encrypted settings survive a redeploy.
KEY_FILE="$STATE/app_key"
if [ ! -s "$KEY_FILE" ]; then
    printf 'base64:%s\n' "$(openssl rand -base64 32)" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    log "generated a new APP_KEY on the volume."
fi
APP_KEY="$(cat "$KEY_FILE")"
export APP_KEY

if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    export APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

# nginx must answer on the port Railway injected: the platform's healthcheck
# dials that port, not the domain's target port.
LISTEN_PORT="${PORT:-80}"
NGINX_CONF=/etc/nginx/conf.d/bagisto.conf
sed -i "s/listen 80 default_server;/listen ${LISTEN_PORT} default_server;/" "$NGINX_CONF"
sed -i "s/listen \[::\]:80 default_server;/listen [::]:${LISTEN_PORT} default_server;/" "$NGINX_CONF"
rm -f /etc/nginx/sites-enabled/default
# Railway terminates TLS at the edge, so PHP must be told the request was HTTPS.
grep -q 'fastcgi_param HTTPS' "$NGINX_CONF" || \
    sed -i '/fastcgi_pass/a\        fastcgi_param HTTPS on;' "$NGINX_CONF"
log "nginx will listen on ${LISTEN_PORT}."

BOOT=$(cat <<'INNER'
set -euo pipefail
cd /var/www/bagisto

echo "[railway] running migrations..."
php artisan migrate --force

MARKER=/var/www/bagisto/storage/railway/seeded
if [ ! -f "$MARKER" ]; then
    echo "[railway] first boot: seeding the demo store..."
    php artisan db:seed --force
    date -u +%FT%TZ > "$MARKER"
else
    # Bagisto's installer seeders begin with DELETE. Re-running them on a
    # redeploy destroys locales, currencies, channels, attributes, categories
    # and CMS pages, and then dies on a duplicate key part-way through.
    echo "[railway] store already seeded; skipping installer seeders."
fi

php /usr/local/bin/railway-admin.php
php artisan storage:link --force >/dev/null 2>&1 || true
php artisan config:cache >/dev/null

chown -R www-data:www-data /var/www/bagisto/storage
exec supervisord -n -c /etc/supervisor/supervisord.conf
INNER
)

exec /usr/local/bin/entrypoint.sh /bin/bash -c "$BOOT"
