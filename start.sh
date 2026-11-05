#!/bin/bash

set -eu

mkdir -p /run/postiz/next-cache /app/data/temporal /app/data/uploads

# https://github.com/gitroomhq/postiz-app/blob/main/.env.example
if [[ ! -f /app/data/env ]]; then
    echo "==> First run. Creating env"

    cat > /app/data/env <<EOT
# See all settings at https://github.com/gitroomhq/postiz-app/blob/main/.env.example
JWT_SECRET="$(pwgen -1s 64)"
# only the first account can sign up with a password, Cloudron users can always log in
DISABLE_REGISTRATION=true
EMAIL_PROVIDER="nodemailer"

# point these at an external Temporal (e.g. Temporal Cloud) to stop using the bundled one
#TEMPORAL_ADDRESS="127.0.0.1:7233"
#TEMPORAL_NAMESPACE="default"
#TEMPORAL_TLS="true"
#TEMPORAL_API_KEY=""
EOT
fi

# echo guards against /app/data/env without a trailing newline
{
    echo 'TEMPORAL_ADDRESS="127.0.0.1:7233"'
    cat /app/data/env
    echo
} > /run/postiz/env

cat >> /run/postiz/env <<EOT
DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
REDIS_URL="${CLOUDRON_REDIS_URL}"

MAIN_URL="${CLOUDRON_APP_ORIGIN}"
FRONTEND_URL="${CLOUDRON_APP_ORIGIN}"
NEXT_PUBLIC_BACKEND_URL="${CLOUDRON_APP_ORIGIN}/api"
BACKEND_INTERNAL_URL="http://127.0.0.1:3000"

# re-queues posts that missed their slot - https://github.com/gitroomhq/postiz-app/blob/main/libraries/nestjs-libraries/src/temporal/infinite.workflow.register.ts
RUN_CRON=true

STORAGE_PROVIDER="local"
UPLOAD_DIRECTORY="/app/data/uploads"
NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY="/app/data/uploads"

NX_ADD_PLUGINS=false
IS_GENERAL="true"
NEXT_TELEMETRY_DISABLED=1

EMAIL_HOST="${CLOUDRON_MAIL_SMTP_SERVER}"
EMAIL_PORT=${CLOUDRON_MAIL_SMTP_PORT}
EMAIL_SECURE=false
EMAIL_USER="${CLOUDRON_MAIL_SMTP_USERNAME}"
EMAIL_PASS="${CLOUDRON_MAIL_SMTP_PASSWORD}"
EMAIL_FROM_NAME="${CLOUDRON_MAIL_FROM_DISPLAY_NAME:-Postiz}"
EMAIL_FROM_ADDRESS="${CLOUDRON_MAIL_FROM}"
EOT

if [[ -n "${CLOUDRON_OIDC_ISSUER:-}" ]]; then
    echo "==> Ensure OIDC settings"

    cat >> /run/postiz/env <<EOT
POSTIZ_GENERIC_OAUTH="true"
POSTIZ_OAUTH_URL="${CLOUDRON_OIDC_ISSUER}"
NEXT_PUBLIC_POSTIZ_OAUTH_DISPLAY_NAME="${CLOUDRON_OIDC_PROVIDER_NAME:-Cloudron}"
POSTIZ_OAUTH_AUTH_URL="${CLOUDRON_OIDC_AUTH_ENDPOINT}"
POSTIZ_OAUTH_TOKEN_URL="${CLOUDRON_OIDC_TOKEN_ENDPOINT}"
POSTIZ_OAUTH_USERINFO_URL="${CLOUDRON_OIDC_PROFILE_ENDPOINT}"
POSTIZ_OAUTH_CLIENT_ID="${CLOUDRON_OIDC_CLIENT_ID}"
POSTIZ_OAUTH_CLIENT_SECRET="${CLOUDRON_OIDC_CLIENT_SECRET}"
POSTIZ_OAUTH_SCOPE="openid profile email"
EOT
fi

set -o allexport && source /run/postiz/env && set +o allexport

echo "==> Changing ownership"
chown -R cloudron:cloudron /app/data /run/postiz

echo "==> Running database migrations"
cd /app/code
gosu cloudron:cloudron /app/code/node_modules/.bin/prisma db push --skip-generate --schema ./libraries/nestjs-libraries/src/database/prisma/schema.prisma

echo "==> Starting Postiz"
exec /usr/bin/supervisord --configuration /etc/supervisor/supervisord.conf --nodaemon -i postiz
