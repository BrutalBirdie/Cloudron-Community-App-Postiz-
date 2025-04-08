#!/bin/bash

set -eu

mkdir -p /run/postiz/npm

# https://github.com/gitroomhq/postiz-app/blob/main/.env.example
if [[ ! -f /app/data/env.sh ]]; then
    echo "==> First run. Creating env"

    jwt_secret=$(pwgen -1s 64)
    cat > /app/data/env.sh <<EOT
export DISABLE_REGISTRATION=false
export JWT_SECRET="${jwt_secret}"

# set EMAIL_PROVIDER="nodemailer" to enable user activation, set it blank to disable
export EMAIL_PROVIDER="nodemailer"

export OPENAI_API_KEY=""

# Social Media API Settings
export X_API_KEY=""
export X_API_SECRET=""
export X_CLIENT=""
export X_SECRET=""
export LINKEDIN_CLIENT_ID=""
export LINKEDIN_CLIENT_SECRET=""
export REDDIT_CLIENT_ID=""
export REDDIT_CLIENT_SECRET=""
export GITHUB_CLIENT_ID=""
export GITHUB_CLIENT_SECRET=""
export BEEHIIVE_API_KEY=""
export BEEHIIVE_PUBLICATION_ID=""
export THREADS_APP_ID=""
export THREADS_APP_SECRET=""
export FACEBOOK_APP_ID=""
export FACEBOOK_APP_SECRET=""
export YOUTUBE_CLIENT_ID=""
export YOUTUBE_CLIENT_SECRET=""
export TIKTOK_CLIENT_ID=""
export TIKTOK_CLIENT_SECRET=""
export PINTEREST_CLIENT_ID=""
export PINTEREST_CLIENT_SECRET=""
export DRIBBBLE_CLIENT_ID=""
export DRIBBBLE_CLIENT_SECRET=""
export DISCORD_CLIENT_ID=""
export DISCORD_CLIENT_SECRET=""
export DISCORD_BOT_TOKEN_ID=""
export SLACK_ID=""
export SLACK_SECRET=""
export SLACK_SIGNING_SECRET=""
export MASTODON_CLIENT_ID=""
export MASTODON_CLIENT_SECRET=""
EOT
fi

cat /app/data/env.sh > /run/postiz/env.sh
cat >> /run/postiz/env.sh <<EOT

export DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}"
export REDIS_URL="redis://default:${CLOUDRON_REDIS_PASSWORD}@${CLOUDRON_REDIS_HOST}:${CLOUDRON_REDIS_PORT}"

export MAIN_URL="${CLOUDRON_APP_ORIGIN}"
export FRONTEND_URL="${CLOUDRON_APP_ORIGIN}"
export NEXT_PUBLIC_BACKEND_URL="${CLOUDRON_APP_ORIGIN}/api"
export BACKEND_INTERNAL_URL="http://localhost:3000"

# Where will social media icons be saved - local or cloudflare.
export STORAGE_PROVIDER="local" 

export UPLOAD_DIRECTORY="/app/data/data"

export NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY="/app/data/data"

export NOT_SECURED=false

export NX_ADD_PLUGINS=false
export IS_GENERAL="true"

export EMAIL_HOST="${CLOUDRON_MAIL_SMTP_SERVER}"
export EMAIL_PORT=${CLOUDRON_MAIL_SMTP_PORT}
export EMAIL_SECURE=false
export EMAIL_USER="${CLOUDRON_MAIL_SMTP_USERNAME}"
export EMAIL_PASS="${CLOUDRON_MAIL_SMTP_PASSWORD}"
export EMAIL_FROM_NAME="${CLOUDRON_MAIL_FROM_DISPLAY_NAME:-Postiz}"
export EMAIL_FROM_ADDRESS="${CLOUDRON_MAIL_FROM}"
EOT
source /run/postiz/env.sh

export POSTIZ_APPS="frontend workers cron backend"

echo "==> Changing ownership"
chown -R cloudron:cloudron /app/data /run/postiz

echo "==> Running database migrations"
gosu cloudron:cloudron npm run prisma-db-push

echo "==> Starting Postiz"
cd /app/code
exec /usr/bin/supervisord --configuration /etc/supervisor/supervisord.conf --nodaemon -i postiz
