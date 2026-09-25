ARG IRIS_IMAGE=intersystemsdc/irishealth-community:2026.2

FROM node:22-alpine AS ui
WORKDIR /ui
COPY package.json package-lock.json ./
RUN npm ci
COPY index.html vite.config.js ./
COPY src ./src
# Copied verbatim into dist/ by Vite. It is the standalone chain verifier
COPY public ./public
RUN npm run build

FROM ${IRIS_IMAGE}

ARG IRIS_PASSWORD=12345
# The least-privilege account the portal runs as (the password is the same knob as above unless it is given its own)
ARG IRIS_ADMIN_USER=docket
ARG IRIS_ADMIN_PASSWORD=

USER root
# jsonschema validates tool arguments, so the portal carries no validator of its own
RUN /usr/irissys/bin/irispython -m pip install --no-cache-dir \
        --target /usr/irissys/mgr/python jsonschema==4.26.0 \
 && chown -R irisowner:irisowner /usr/irissys/mgr/python
USER irisowner

ENV PYTHONPATH=/usr/irissys/mgr/python

COPY --chown=irisowner:irisowner src/App /opt/portal/src/App
# Compiled into USER, not %SYS
COPY --chown=irisowner:irisowner src/Demo/App /opt/portal/demo/App
COPY --chown=irisowner:irisowner docker/init.script /opt/portal/init.script
COPY --from=ui --chown=irisowner:irisowner /ui/dist /opt/portal/www

RUN set -eu; \
    iris start IRIS quietly; \
    IRIS_PASSWORD="${IRIS_PASSWORD}" \
    IRIS_ADMIN_USER="${IRIS_ADMIN_USER}" \
    IRIS_ADMIN_PASSWORD="${IRIS_ADMIN_PASSWORD:-$IRIS_PASSWORD}" \
    iris session IRIS -U%SYS < /opt/portal/init.script; \
    iris stop IRIS quietly
