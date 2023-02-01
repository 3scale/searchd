FROM registry.access.redhat.com/ubi7/ubi AS builder
SHELL ["/bin/bash", "-x", "-o", "pipefail", "-c"]
# hadolint ignore=DL3003,DL3032,SC2046
RUN if [ "$(uname -m)" == "x86_64" ]; then \
      yumdownloader --downloadonly --destdir=/home/rpms mariadb-libs.$(uname -m) postgresql-libs.$(uname -m) unixODBC.$(uname -m) --resolve && \
      curl https://sphinxsearch.com/files/sphinx-2.2.11-1.rhel7.x86_64.rpm -o /home/rpms/sphinx-2.2.11-1.rhel7.x86_64.rpm && \
     mkdir /home/searchd ; \
    else \
      yumdownloader --downloadonly --destdir=/home/rpms mariadb-libs.$(uname -m) --resolve && \
      yum install -y gcc-c++ mysql-devel make  && \
      curl -sSL http://sphinxsearch.com/files/sphinx-2.2.11-release.tar.gz | tar xz -C /tmp && \
      cd /tmp/sphinx-2.2.11-release && ./configure && DESTDIR=/home/searchd make install && \
      rm -rf /tmp/sphinx* ; \
    fi


FROM registry.access.redhat.com/ubi7-minimal
COPY --from=builder /home/rpms /tmp/rpms
COPY --from=builder /home/searchd /
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release && \
    rpm -iv --excludedocs /tmp/rpms/* && \
    rm -rf /tmp/rpms
