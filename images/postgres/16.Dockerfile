ARG IMAGE_REPO
FROM ${IMAGE_REPO:-lagoon}/commons as commons
FROM postgres:16.1-alpine3.18

LABEL org.opencontainers.image.authors="The Lagoon Authors" maintainer="The Lagoon Authors"
LABEL org.opencontainers.image.source="https://github.com/uselagoon/lagoon-images" repository="https://github.com/uselagoon/lagoon-images"

ARG LAGOON_VERSION
ENV LAGOON_VERSION=$LAGOON_VERSION

# Copy commons files
COPY --from=commons /lagoon /lagoon
COPY --from=commons /bin/fix-permissions /bin/ep /bin/docker-sleep /bin/wait-for /bin/
COPY --from=commons /sbin/tini /sbin/
COPY --from=commons /home /home

ENV TMPDIR=/tmp \
    TMP=/tmp \
    HOME=/home \
    # When Bash is invoked via `sh` it behaves like the old Bourne Shell and sources a file that is given in `ENV`
    ENV=/home/.bashrc \
    # When Bash is invoked as non-interactive (like `bash -c command`) it sources a file that is given in `BASH_ENV`
    BASH_ENV=/home/.bashrc

RUN apk update \
    && apk add --no-cache \
        rsync \
        tar \
    && rm -rf /var/cache/apk/*

RUN fix-permissions /etc/passwd \
    && mkdir -p /home

ENV LAGOON=postgres

COPY postgres-backup.sh /lagoon/

RUN echo -e "local all all md5\nhost  all  all 0.0.0.0/0 md5" >> /usr/local/share/postgresql/pg_hba.conf

ENV PGUSER=postgres \
    POSTGRES_PASSWORD=lagoon \
    POSTGRES_USER=lagoon \
    POSTGRES_DB=lagoon \
    PGDATA=/var/lib/postgresql/data/pgdata

# Postgresql entrypoint file needs bash, so start the entrypoints with bash
ENTRYPOINT ["/sbin/tini", "--", "/lagoon/entrypoints.bash"]
CMD ["/usr/local/bin/docker-entrypoint.sh", "postgres"]
