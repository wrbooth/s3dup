FROM python:alpine

RUN apk add --update \
      bash \
      build-base \
      curl \
      gettext \
      gnupg \
      librsync \
      librsync-dev && \

    pip install \
      boto3 \
      setuptools_scm && \

    pip install \
      duplicity && \

    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" && \
    unzip awscli-bundle.zip && \
    ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && \
    rm -rf ./awscli-bundle && \

    apk del build-base curl

COPY backup.sh /opt

ENTRYPOINT ["/opt/backup.sh"]
