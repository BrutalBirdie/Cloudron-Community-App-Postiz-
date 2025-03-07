# renovate: datasource=github-releases depName=gitroomhq/postiz-app versioning=semver extractVersion=^v(?<version>.+)$
ARG POSTIZ_VERSION=1.36.1

FROM ghcr.io/gitroomhq/postiz-app:v${POSTIZ_VERSION}-amd64 AS postiz

FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c AS base

WORKDIR /app/code

RUN echo "deb [signed-by=/usr/share/keyrings/collaboraonline-release-keyring.gpg] https://collaboraoffice.com/repos/CollaboraOnline/CODE-ubuntu2204 /" > /etc/apt/sources.list.d/collabora.list
RUN curl https://www.collaboraoffice.com/downloads/gpg/collaboraonline-release-keyring.gpg --output /usr/share/keyrings/collaboraonline-release-keyring.gpg

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

#RUN curl -L "https://github.com/gitroomhq/postiz-app/archive/refs/tags/v${POSTIZ_VERSION}.tar.gz" | \
#    tar xzvf - -C /app/code/

ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=postiz --chown=cloudron:cloudron /config/postiz.env /app/code/
COPY --from=postiz --chown=cloudron:cloudron /app/dist /app/code/dist
COPY --from=postiz --chown=cloudron:cloudron /app/libraries /app/code/libraries
COPY --from=postiz --chown=cloudron:cloudron /app/node_modules /app/code/node_modules
COPY --from=postiz --chown=cloudron:cloudron /app/nx.json /app/code/
COPY --from=postiz --chown=cloudron:cloudron /app/package.json /app/code/
COPY --from=postiz --chown=cloudron:cloudron /app/Caddyfile /app/code/

# Add supervisor configs
COPY supervisor/* /etc/supervisor/conf.d/
RUN ln -sf /run/postiz/supervisord.log /var/log/supervisor/supervisord.log

#RUN chown -R cloudron:cloudron /app/code

COPY start.sh /app/pkg/

CMD [ "/app/pkg/start.sh" ]
