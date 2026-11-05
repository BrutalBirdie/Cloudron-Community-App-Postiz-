# renovate: datasource=docker depName=ghcr.io/gitroomhq/postiz-app extractVersion=^v(?<version>.+)$
ARG POSTIZ_VERSION=2.25.3

FROM ghcr.io/gitroomhq/postiz-app:v${POSTIZ_VERSION} AS postiz

FROM cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee

RUN mkdir -p /app/pkg /app/code
WORKDIR /app/code

# must match engines.node - https://github.com/gitroomhq/postiz-app/blob/main/package.json
# renovate: datasource=node-version depName=node
ARG NODE_VERSION=22.23.4
RUN mkdir -p /usr/local/node-${NODE_VERSION} && curl -L https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz | tar zxf - --strip-components 1 -C /usr/local/node-${NODE_VERSION}
ENV PATH=/usr/local/node-${NODE_VERSION}/bin:$PATH

# renovate: datasource=github-releases depName=temporalio/cli versioning=semver extractVersion=^v(?<version>.+)$
ARG TEMPORAL_CLI_VERSION=1.9.1
RUN curl -L https://github.com/temporalio/cli/releases/download/v${TEMPORAL_CLI_VERSION}/temporal_cli_${TEMPORAL_CLI_VERSION}_linux_amd64.tar.gz | tar zxf - -C /usr/local/bin temporal

COPY --from=postiz /app /app/code

# upstream runs "pnpm dlx prisma" on every start, which downloads the schema engine at runtime
RUN node_modules/.bin/prisma --version

RUN rm -rf /app/code/apps/frontend/.next/cache /app/code/node-compile-cache && \
    ln -sf /run/postiz/next-cache /app/code/apps/frontend/.next/cache

RUN rm /etc/nginx/sites-enabled/* && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log
COPY nginx/postiz.conf /etc/nginx/sites-enabled/postiz.conf
COPY nginx/readonlyrootfs.conf /etc/nginx/conf.d/readonlyrootfs.conf

RUN sed -e 's,^logfile=.*$,logfile=/run/postiz/supervisord.log,' -i /etc/supervisor/supervisord.conf
COPY supervisor/* /etc/supervisor/conf.d/

COPY start.sh temporal.sh /app/pkg/

CMD [ "/app/pkg/start.sh" ]
