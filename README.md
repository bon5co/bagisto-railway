# bagisto-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/bagisto-or-just-updated-shopify-alternat?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Bagisto template](https://railway.com/deploy/bagisto-or-just-updated-shopify-alternat?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

Wrapper image for deploying [Bagisto](https://bagisto.com) 2.4.3 on Railway.

Upstream's `webkul/bagisto` image is pinned by digest. The wrapper adds four things
a Railway deployment needs:

1. **An administrator seeded from the deployment's own credentials.** Bagisto's
   installer seeder creates `admin@example.com` with the password `admin123`,
   which is published in the upstream source. The container refuses to boot
   unless `BAGISTO_ADMIN_EMAIL` and `BAGISTO_ADMIN_PASSWORD` are set, seeds that
   account instead, and removes the default row. The password is re-applied on
   every boot, so a redeploy is a working password reset — Bagisto has no
   non-interactive way to change one, and its own reset path needs SMTP.
2. **The demo store is seeded exactly once.** `Webkul\Installer`'s seeders begin
   with `DELETE`, so running `db:seed` on every boot destroys locales,
   currencies, channels, attributes, categories and CMS pages, then aborts
   part-way through on a duplicate key. A marker on the volume records the first
   seed and later boots skip it.
3. **A valid `APP_KEY`.** Laravel requires a key that decodes to 32 bytes. One is
   generated onto the volume on first boot and reused afterwards, so sessions and
   encrypted settings survive a redeploy.
4. **nginx bound to Railway's injected `$PORT`**, plus `fastcgi_param HTTPS on`
   because the platform terminates TLS at the edge.

## Environment

| Variable | Required | Purpose |
| --- | --- | --- |
| `BAGISTO_ADMIN_EMAIL` | yes | Administrator account created/updated on boot |
| `BAGISTO_ADMIN_PASSWORD` | yes | Administrator password, re-applied every boot |
| `DB_HOST` `DB_PORT` `DB_DATABASE` `DB_USERNAME` `DB_PASSWORD` | yes | External MySQL |
| `PORT` | injected | Port nginx listens on |

Mount a volume at `/var/www/bagisto/storage`.
