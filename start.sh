#!/bin/bash

set -eu

mkdir -p /run/postiz/npm

export NPM_CONFIG_CACHE=/run/postiz/npm
export NPM_CONFIG_USERCONFIG=/run/postiz/npm/npmrc

# migration to .env
if [[ -f /app/data/env.sh ]]; then
    sed -e 's/export //' /app/data/env.sh > /app/data/env
    rm /app/data/env.sh
fi

# https://github.com/gitroomhq/postiz-app/blob/main/.env.example
if [[ ! -f /app/data/env ]]; then
    echo "==> First run. Creating env"

    jwt_secret=$(pwgen -1s 64)
    cat > /app/data/env <<EOT
# See all settings at https://github.com/gitroomhq/postiz-app/blob/main/.env.example
DISABLE_REGISTRATION=some-nonempty-value
JWT_SECRET="${jwt_secret}"
EMAIL_PROVIDER="nodemailer"
EOT
fi

cat /app/data/env > /run/postiz/env
cat >> /run/postiz/env <<EOT

POSTIZ_APPS="frontend workers cron backend"

DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
REDIS_URL="redis://default:${CLOUDRON_REDIS_PASSWORD}@${CLOUDRON_REDIS_HOST}:${CLOUDRON_REDIS_PORT}"

MAIN_URL="${CLOUDRON_APP_ORIGIN}"
FRONTEND_URL="${CLOUDRON_APP_ORIGIN}"
NEXT_PUBLIC_BACKEND_URL="${CLOUDRON_APP_ORIGIN}/api"
BACKEND_INTERNAL_URL="http://localhost:3000"

# Where will social media icons be saved - local or cloudflare.
STORAGE_PROVIDER="local"

UPLOAD_DIRECTORY="/app/data/data"

NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY="/app/data/data"
NEXT_PUBLIC_UPLOAD_DIRECTORY="/app/data/data"

NX_ADD_PLUGINS=false
IS_GENERAL="true"

EMAIL_HOST="${CLOUDRON_MAIL_SMTP_SERVER}"
EMAIL_PORT=${CLOUDRON_MAIL_SMTP_PORT}
EMAIL_SECURE=false
EMAIL_USER="${CLOUDRON_MAIL_SMTP_USERNAME}"
EMAIL_PASS="${CLOUDRON_MAIL_SMTP_PASSWORD}"
EMAIL_FROM_NAME="${CLOUDRON_MAIL_FROM_DISPLAY_NAME:-Postiz}"
EMAIL_FROM_ADDRESS="${CLOUDRON_MAIL_FROM}"
EOT
set -o allexport && source /run/postiz/env && set +o allexport


echo "==> Changing ownership"
chown -R cloudron:cloudron /app/data /run/postiz

# Set npm config to use temporary directories
gosu cloudron:cloudron bash -c "pnpm config set cache ${NPM_CONFIG_CACHE} && pnpm config set userconfig ${NPM_CONFIG_USERCONFIG}"

echo "==> Running database migrations"
gosu cloudron:cloudron npm run prisma-db-push

echo "==> Starting Postiz"
cd /app/code
exec /usr/bin/supervisord --configuration /etc/supervisor/supervisord.conf --nodaemon -i postiz
