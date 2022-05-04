FROM alpine:3.15

ARG PG_DATANYMIZER_VERSION

COPY ["docker-entrypoint.sh", "/usr/local/bin"]

RUN apk update && apk add --no-cache --virtual .build-deps curl \
    && apk add --no-cache bash aws-cli postgresql14-client \
    && curl -sSfL https://git.io/pg_datanymizer | sh -s -- -b /usr/local/bin ${PG_DATANYMIZER_VERSION}  \
    && apk del .build-deps && rm -rf /var/cache/apk/* \
    && adduser -D datanymizer && chmod +x /usr/local/bin/docker-entrypoint.sh

USER 1000

ENTRYPOINT ["docker-entrypoint.sh"]
