FROM alpine:3.12

ENV AWS_CLI_VERSION=1.18.124

RUN apk -v --update add \
      py-pip \
      python3 \
      && \
    pip install --upgrade \
      awscli==${AWS_CLI_VERSION} \
      && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/*
