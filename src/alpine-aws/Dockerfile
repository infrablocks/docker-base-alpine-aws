FROM alpine:3.18.5

ENV AWS_CLI_VERSION=1.18.124

RUN apk \
      --verbose \
      --no-cache \
      add \
          py3-pip \
      && \
    pip install \
      awscli==${AWS_CLI_VERSION}
