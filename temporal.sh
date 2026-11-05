#!/bin/bash

set -eu

if [[ "${TEMPORAL_ADDRESS}" != "127.0.0.1:7233" ]]; then
    echo "==> TEMPORAL_ADDRESS is ${TEMPORAL_ADDRESS}, not starting the bundled Temporal server"
    exec sleep infinity
fi

# limit.maxIDLength matches upstream dynamicconfig - https://github.com/gitroomhq/postiz-app/blob/main/dynamicconfig/development-sql.yaml
exec /usr/local/bin/temporal server start-dev \
    --disable-config-env \
    --headless \
    --ip 127.0.0.1 \
    --port 7233 \
    --http-port 7243 \
    --metrics-port 7244 \
    --db-filename /app/data/temporal/temporal.db \
    --namespace default \
    --search-attribute organizationId=Text \
    --search-attribute postId=Text \
    --dynamic-config-value limit.maxIDLength=255 \
    --log-level warn
