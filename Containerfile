FROM quay.io/centos/centos:stream9 AS builder
ENV SEARCHD_REF=6.2.12 \
    SEARCHD_REPO=https://github.com/manticoresoftware/manticoresearch.git \
    CC=clang \
    CXX=clang++ \
    BUILD_PATH=/tmp/manticore_uselessly_long_path_to_prevent_rpm_build_issues \
    BUILD_FLAGS="-DUSE_SYSLOG=0 -DWITH_GALERA=0 -DWITH_RE2=0 -DWITH_STEMMER=0 -DWITH_ICU_FORCE_STATIC=0 -DWITH_SSL=1 -DWITH_ZLIB=1 -DWITH_ODBC=0 -DWITH_EXPAT=0 -DWITH_ICONV=1 -DWITH_POSTGRESQL=0 -DWITH_MYSQL=0 -DBUILD_TESTING=0"
WORKDIR $BUILD_PATH

SHELL ["/bin/bash", "-x", "-o", "pipefail", "-c"]
# clang is broken on s390x (RHEL-15874), to use gcc remove CC and CXX variables,
#   also replace llvm-toolset with make automake gcc gcc-c++ kernel-devel
# hadolint ignore=DL3003,DL3032,SC2046
RUN yum install -y --setopt=skip_missing_names_on_install=False,tsflags=nodocs llvm-toolset mysql cmake boost-devel openssl-devel zlib-devel libicu-devel bison flex systemd-units rpm-build git && \
      git clone --depth=1 --branch=$SEARCHD_REF $SEARCHD_REPO . && \
      # boost lib in RHEL9 comes dynamic only so enable its use \
      sed -i -e 's/Boost_USE_STATIC_LIBS ON/Boost_USE_STATIC_LIBS OFF/' src/CMakeLists.txt && \
      mkdir build && cd build && \
      cmake $BUILD_FLAGS .. && \
      cmake --build . --target package --config RelWithDebInfo

FROM quay.io/centos/centos:stream9-minimal

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
COPY --from=builder /tmp/manticore_uselessly_long_path_to_prevent_rpm_build_issues/build/*.rpm /tmp/rpms/
COPY --from=$PORTA_IMAGE /opt/system/config/standalone.sphinx.conf "/etc/manticoresearch/manticore.conf"
ENV MANTICORE_RPMS="manticore-converter* manticore-common* manticore-server-core* manticore-server*"
RUN microdnf install -y --nodocs mysql openssl boost-context boost-filesystem zlib libicu && \
    cd /tmp/rpms && ls -l && \
    rpm -iv --excludedocs $MANTICORE_RPMS && \
    cd - && rm -rf /tmp/rpms && \
    microdnf clean all && \
    # TODO: once in production, update porta to generate config with the correct path \
    sed -i -e 's#/var/run/sphinx/#/var/run/manticore/#' /etc/manticoresearch/manticore.conf && \
    mkdir /var/lib/searchd && \
    chmod g+w /var/lib/searchd /var/run/manticore /var/log/manticore && \
    chgrp 0 /var/lib/searchd /var/run/manticore /var/log/manticore

WORKDIR /var/lib/manticore
ENTRYPOINT ["/bin/env", "searchd", "--pidfile", "--config", "/etc/manticoresearch/manticore.conf", "--nodetach"]
EXPOSE 9306/tcp
