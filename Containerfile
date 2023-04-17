FROM registry.access.redhat.com/ubi7/ubi AS builder
ENV SEARCHD_RPM=sphinx-2.2.11-1.rhel7.x86_64.rpm \
    SEARCHD_RPM_SHA=959b04eb3f7fb2314d7a2702b61e9b3e627b66b1a8574dece21c0592be1b90e2 \
    SEARCHD_SRC=sphinx-2.2.11-release.tar.gz \
    SEARCHD_SRC_DIR=sphinx-2.2.11-release \
    SEARCHD_SRC_SHA=6662039f093314f896950519fa781bc87610f926f64b3d349229002f06ac41a9
SHELL ["/bin/bash", "-x", "-o", "pipefail", "-c"]
# hadolint ignore=DL3003,DL3032,SC2046
RUN if [ "$(uname -m)" == "x86_64" ]; then \
      yumdownloader --downloadonly --destdir=/home/rpms mariadb-libs.$(uname -m) postgresql-libs.$(uname -m) unixODBC.$(uname -m) --resolve && \
      curl -sSL https://sphinxsearch.com/files/$SEARCHD_RPM -o /home/rpms/$SEARCHD_RPM && \
     sha256sum -c - <<< "$SEARCHD_RPM_SHA /home/rpms/$SEARCHD_RPM" && \
     mkdir /home/searchd ; \
    else \
      yumdownloader --downloadonly --destdir=/home/rpms mariadb-libs.$(uname -m) --resolve && \
      yum install -y gcc-c++ mysql-devel make  && \
      curl -sSL http://sphinxsearch.com/files/$SEARCHD_SRC -o /tmp/$SEARCHD_SRC && \
      sha256sum -c - <<< "$SEARCHD_SRC_SHA /tmp/$SEARCHD_SRC" && \
      tar xzf /tmp/$SEARCHD_SRC -C /tmp && \
      cd /tmp/$SEARCHD_SRC_DIR && ./configure && DESTDIR=/home/searchd make install && \
      rm -rf /tmp/sphinx* ; \
    fi


FROM registry.access.redhat.com/ubi7-minimal

LABEL org.opencontainers.image.authors="https://issues.redhat.com/browse/THREESCALE" \
      org.opencontainers.image.title="3scale searchd" \
      org.opencontainers.image.vendor="Red Hat, Inc." \
      org.opencontainers.image.url="https://github.com/3scale/searchd" \
      org.opencontainers.image.documentation="https://github.com/3scale/searchd" \
      org.opencontainers.image.description="Searchd to be used in a 3scale installation" \
      org.opencontainers.image.licenses="Apache-2.0"
      # org.opencontainers.image.version="nightly"
      # org.opencontainers.image.ref.name="" \
      # org.opencontainers.image.revision="" \
      # org.opencontainers.image.created=""

ARG PORTA_IMAGE=quay.io/3scale/porta:nightly
COPY --from=builder /home/rpms /tmp/rpms
COPY --from=builder /home/searchd /
COPY --from=$PORTA_IMAGE /opt/system/config/standalone.sphinx.conf "/etc/sphinx/system.sphinx.conf"
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release && \
    rpm -iv --excludedocs /tmp/rpms/* && \
    rm -rf /tmp/rpms && \
    mkdir -p /var/lib/searchd /var/run/sphinx && \
    chmod 770 /var/lib/searchd /var/run/sphinx

ENTRYPOINT ["/bin/env", "searchd", "--pidfile", "--config", "/etc/sphinx/system.sphinx.conf", "--nodetach"]
EXPOSE 9306/tcp
