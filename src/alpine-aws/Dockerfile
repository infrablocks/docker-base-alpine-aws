FROM alpine:3.12

ENV AWS_CLI_VERSION=1.18.39
ENV AWS_S3CMD_VERSION=2.1.0

RUN apk -v --update add \
      py-pip \
      python3 \
      && \
    pip install --upgrade \
      awscli==${AWS_CLI_VERSION} \
      s3cmd==${AWS_S3CMD_VERSION} \
      && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/*
