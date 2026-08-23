# Bagisto for Railway.
#
# Upstream image, pinned by digest. The wrapper adds:
#   - a boot sequence that seeds the demo store exactly once instead of on every
#     boot (upstream's installer seeders begin with DELETE and destroy store
#     configuration on a redeploy),
#   - an administrator seeded from the deployment's own credentials rather than
#     the upstream default admin@example.com / admin123,
#   - a valid APP_KEY generated once onto the volume,
#   - nginx bound to Railway's injected $PORT.
FROM webkul/bagisto:2.4.3@sha256:e0f910c7c52ea7616c6f73fdf3307416039c5c676399933043fc63f89514bc13

# Literals a Railway template variable cannot carry: templateGenerate drops a
# literal defaultValue and publishes the variable as a blank required field.
ENV APP_ENV=production \
    APP_DEBUG=false \
    DB_PORT=3306 \
    DB_DATABASE=bagisto \
    DB_USERNAME=root \
    TRUSTED_PROXIES=* \
    QUEUE_CONNECTION=sync \
    SESSION_DRIVER=file \
    CACHE_STORE=file \
    CACHE_DRIVER=file

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY railway-admin.php /usr/local/bin/railway-admin.php
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
