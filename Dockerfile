FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c AS base

WORKDIR /app/code

RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

RUN ln -sf /usr/local/node-${NODE_VERSION}/bin/node /usr/bin/node

RUN apt-get update && \
    apt-get install -y \
        caddy \
        musl-dev && \
    ln -s /usr/lib/x86_64-linux-musl/libc.so /lib/libc.musl-x86_64.so.1 && \
    rm -r /var/cache/apt /var/lib/apt/lists

# remove all nodejs versions
RUN find /usr/local -maxdepth 1 -name "node-*" -type d -exec rm -rf {} \;

# install node v20
ARG NODE_VERSION=20.18.2

RUN mkdir -p /usr/local/node-${NODE_VERSION} && curl -L https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz | tar zxf - --strip-components 1 -C /usr/local/node-${NODE_VERSION}
ENV PATH="/usr/local/node-${NODE_VERSION}/bin:$PATH"

ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NEXT_TELEMETRY_DISABLED=1

FROM base AS builder

WORKDIR /app/code

# renovate: datasource=github-releases depName=gitroomhq/postiz-app versioning=semver extractVersion=^v(?<version>.+)$
ARG POSTIZ_VERSION=1.36.1

#RUN curl -L "https://github.com/gitroomhq/postiz-app/archive/refs/tags/v${POSTIZ_VERSION}.tar.gz" | \
#    tar xzvf - -C /app/code/
RUN curl -L "https://github.com/gitroomhq/postiz-app/archive/refs/tags/v${POSTIZ_VERSION}.tar.gz" | \
    tar -xzf - --strip 1 -C /app/code

RUN npm ci --no-fund && npx nx run-many --target=build --projects=frontend,backend,workers,cron

FROM base AS runner

WORKDIR /app/code

COPY --from=builder --chown=cloudron:cloudron /app/code/.env.example /app/code/
COPY --from=builder --chown=cloudron:cloudron /app/code/var/docker/Caddyfile /app/code/
COPY --from=builder --chown=cloudron:cloudron /app/code/dist /app/code/dist
COPY --from=builder --chown=cloudron:cloudron /app/code/libraries /app/code/libraries
COPY --from=builder --chown=cloudron:cloudron /app/code/node_modules /app/code/node_modules
COPY --from=builder --chown=cloudron:cloudron /app/code/nx.json /app/code/
COPY --from=builder --chown=cloudron:cloudron /app/code/package.json /app/code/

# Add supervisor configs
COPY supervisor/* /etc/supervisor/conf.d/
RUN ln -sf /run/postiz/supervisord.log /var/log/supervisor/supervisord.log

#RUN chown -R cloudron:cloudron /app/code

COPY start.sh /app/pkg/

CMD [ "/app/pkg/start.sh" ]
