FROM quay.io/centos/centos:stream9 AS builder

# this is 6.3.8 + big endian fixes and a few other patches
ENV SEARCHD_REF=de6e35e2e233a012c5a7ed60675d15620234fad3 \
    SEARCHD_REPO=https://github.com/manticoresoftware/manticoresearch.git \
    # CC=clang-16 \
    # CXX=clang++-16 \
    BUILD_PATH=/tmp/manticore_uselessly_very_long_path_to_prevent_rpm_build_issues \
    BUILD_FLAGS="-DUSE_SYSLOG=0 -DWITH_GALERA=0 -DWITH_RE2=0 -DWITH_STEMMER=0 -DWITH_ICU_FORCE_STATIC=0 -DWITH_SSL=1 -DWITH_ZLIB=1 -DWITH_ODBC=0 -DWITH_EXPAT=0 -DWITH_ICONV=1 -DWITH_POSTGRESQL=0 -DWITH_MYSQL=0 -DBUILD_TESTING=0 -DDISTR=rhel9" \
    DEPS_CLANG_RHEL9="llvm-toolset-16.0.6-4.el9" \
    DEPS_GCC_UBI9="make automake gcc-toolset-13 gcc gcc-c++" \
    DEPS_NON_UBI="boost-devel bison flex" \
    DEPS_NON_UBI_RUNTIME="boost-context boost-filesystem boost-system"

WORKDIR $BUILD_PATH

SHELL ["/bin/bash", "-x", "-o", "pipefail", "-c"]
# to use clang, adjust CC and CXX variables and dependencies
# hadolint ignore=DL3040
RUN dnf install -y --setopt=strict=True --setopt=tsflags=nodocs mysql cmake $DEPS_GCC_UBI9 $DEPS_NON_UBI openssl-devel zlib-devel libicu-devel systemd-units rpm-build git 'dnf-command(download)'

# RUN dnf install -y --setopt=strict=True --setopt=tsflags=nodocs xz gcc-c++
#    curl -sSL https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/llvm-project-16.0.6.src.tar.xz -o llvm-project-16.0.6.src.tar.xz && \
#    tar xvfJ llvm-project-16.0.6.src.tar.xz && \
#    cd llvm-project-16.0.6.src && \
#    cmake -S llvm -B build -G "Unix Makefiles" -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_BUILD_TYPE=MinSizeRel && \
#    cmake --build build && \
#    cmake --install build

RUN git init . && \
      git remote add origin $SEARCHD_REPO && \
      git fetch --depth=1 origin $SEARCHD_REF && \
      git reset --hard FETCH_HEAD && \
      # boost lib in RHEL9 comes dynamic only so enable its use \
      sed -i -e 's/Boost_USE_STATIC_LIBS ON/Boost_USE_STATIC_LIBS OFF/' src/CMakeLists.txt && \
      mkdir build && cd build && \
      cmake $BUILD_FLAGS .. && \
      cmake --build . --target package --config RelWithDebInfo # Debug

# Build the tzdata RPM
COPY --chown=adm rpmbuild/ /var/adm/rpmbuild/
RUN chown -R adm /var/adm
WORKDIR /var/adm
USER adm
RUN rpmbuild -bb rpmbuild/SPECS/manticore-tzdata.spec

# Download boost RPMs for runtime
WORKDIR /tmp/boost_rpms
RUN dnf download --arch `uname -m` $DEPS_NON_UBI_RUNTIME

# it is ok not to tag ubi image as it is stable enough
# hadolint ignore=DL3006
FROM registry.access.redhat.com/ubi9-minimal

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
COPY --from=builder /tmp/manticore_uselessly_very_long_path_to_prevent_rpm_build_issues/build/*.rpm /tmp/rpms/
COPY --from=builder /var/adm/rpmbuild/RPMS/noarch/manticore-tzdata-1.1-1.noarch.rpm /tmp/rpms/
COPY --from=builder /tmp/boost_rpms/ /tmp/boost_rpms/
COPY --from=$PORTA_IMAGE /opt/system/config/standalone.sphinx.conf "/etc/manticoresearch/manticore.conf"
ENV MANTICORE_RPMS="manticore-converter* manticore-common* manticore-server-core* manticore-server* manticore-tzdata-1.1-1.noarch.rpm"

# hadolint ignore=DL3040
RUN microdnf install -y --nodocs mysql openssl zlib libicu

RUN cd /tmp/rpms && ls -l && \
    rpm -iv --excludedocs /tmp/boost_rpms/* $MANTICORE_RPMS && \
    cd - && rm -rf /tmp/rpms /tmp/boost_rpms && \
    microdnf clean all && \
    # TODO: once in production, update porta to generate config with the correct path \
    sed -i -e 's#/var/run/sphinx/#/var/run/manticore/#' /etc/manticoresearch/manticore.conf && \
    mkdir /var/lib/searchd && \
    chmod g+w /var/lib/searchd /var/run/manticore /var/log/manticore && \
    chgrp 0 /var/lib/searchd /var/run/manticore /var/log/manticore

WORKDIR /var/lib/manticore
ENTRYPOINT ["/bin/searchd", "--pidfile", "--config", "/etc/manticoresearch/manticore.conf", "--nodetach"]
USER 1001
EXPOSE 9306/tcp
