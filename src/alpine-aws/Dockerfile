FROM alpine:3.8

ENV AWS_CLI_VERSION=1.16.1
ENV AWS_S3CMD_VERSION=2.0.2

RUN apk -v --update add \
      py-pip \
      python \
      && \
    pip install --upgrade awscli==${AWS_CLI_VERSION} s3cmd==${AWS_S3CMD_VERSION} && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/*
