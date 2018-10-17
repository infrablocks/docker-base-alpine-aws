FROM infrablocks/alpine-aws:0.3.0

RUN apk -v --update add \
      bash \
      sed \
      && \
    rm /var/cache/apk/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN ["chmod", "+x", "/usr/local/bin/docker-entrypoint.sh"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
