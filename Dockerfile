FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c AS base

WORKDIR /app/code

RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

RUN apt-get update && \
    apt-get install -y caddy && \
    rm -r /var/cache/apt /var/lib/apt/lists

# wants node 20 - https://github.com/gitroomhq/postiz-app/blob/main/Dockerfile.dev#L7
ARG NODE_VERSION=20.18.2
RUN mkdir -p /usr/local/node-${NODE_VERSION} && curl -L https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz | tar zxf - --strip-components 1 -C /usr/local/node-${NODE_VERSION}
RUN ln -sf /usr/local/node-${NODE_VERSION}/bin/node /usr/bin/node
ENV PATH="/usr/local/node-${NODE_VERSION}/bin:$PATH"

ENV NEXT_TELEMETRY_DISABLED=1

# https://github.com/gitroomhq/postiz-app/blob/main/Dockerfile.dev#L3
RUN npm --no-update-notifier --no-fund --global install pnpm@10.6.1 pm2

FROM base AS builder

WORKDIR /app/code

# renovate: datasource=github-releases depName=gitroomhq/postiz-app versioning=semver extractVersion=^v(?<version>.+)$
ARG POSTIZ_VERSION=1.43.2
RUN curl -L "https://github.com/gitroomhq/postiz-app/archive/refs/tags/v${POSTIZ_VERSION}.tar.gz" | tar -xzf - --strip 1 -C /app/code

RUN pnpm install
RUN pnpm run build

FROM base AS runner

WORKDIR /app/code
COPY --from=builder --chown=cloudron:cloudron /app/code/apps /app/code/apps
COPY --from=builder --chown=cloudron:cloudron /app/code/.env.example /app/code/
COPY --from=builder --chown=cloudron:cloudron /app/code/var/docker/Caddyfile /app/code/
COPY --from=builder --chown=cloudron:cloudron /app/code/libraries /app/code/libraries
COPY --from=builder --chown=cloudron:cloudron /app/code/node_modules /app/code/node_modules
COPY --from=builder --chown=cloudron:cloudron /app/code/package.json /app/code/

COPY supervisor/* /etc/supervisor/conf.d/
RUN ln -sf /run/postiz/supervisord.log /var/log/supervisor/supervisord.log

COPY Caddyfile /app/code/Caddyfile

COPY start.sh /app/pkg/

CMD [ "/app/pkg/start.sh" ]
