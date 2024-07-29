FROM alpine:3.20.2

ENV AWS_CLI_VERSION=1.18.124

RUN apk \
      --verbose \
      --no-cache \
      add \
          py3-pip \
      && \
    pip install \
      awscli==${AWS_CLI_VERSION}
