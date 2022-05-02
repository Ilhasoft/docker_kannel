FROM debian:bullseye-slim as base

ARG APP_UID=1000
ARG APP_GID=500

ARG BUILD_DEPS="\
  build-essential subversion ntp nano wget cvs subversion curl git-core unzip autoconf \
  automake1.11 libtool flex debhelper pkg-config libpam0g-dev intltool docbook docbook-xsl \
  build-essential libpcre3 libpcre3-dev libc6-dev g++ gcc autotools-dev libncurses-dev \
  texi2html texinfo libxml2-dev ca-certificates byacc bison m4 tex-common \
  openssl libssl-dev locales default-libmysqlclient-dev  libmysqlcppconn-dev supervisor libtool-bin"
ARG RUNTIME_DEPS="\
  curl unzip libxml2 libmariadb3 gettext-base \
  libpcre3 openssl supervisor bash netcat ca-certificates \
"

ARG VERSION="0.1"

# set environment variables
ENV VERSION=${VERSION} \
  RUNTIME_DEPS=${RUNTIME_DEPS} \
  BUILD_DEPS=${BUILD_DEPS} \
  PATH="/install/bin:${PATH}"

LABEL version=${VERSION} \
  os="Debian" \
  os.version="10" \
  name="Kannel ${VERSION}" \
  description="Kannel image" \
  maintainer="Weni Team"

RUN addgroup --gid "${APP_GID}" app_group \
  && useradd --system -m -d / -u "${APP_UID}" -g "${APP_GID}" app_user

WORKDIR /

FROM base AS build

RUN if [ ! "x${BUILD_DEPS}" = "x" ] ; then apt-get update \
  && apt-get install -y --no-install-recommends ${BUILD_DEPS} ; fi

RUN locale-gen en_US && \
    locale-gen en_US.UTF-8

#!/bin/bash

#  apt-get install ca-certificates -y
#  sed -i -e 's|mozilla/DST_Root_CA_X3.crt|#mozilla/DST_Root_CA_X3.crt|g' /etc/ca-certificates.conf
#  sed -i -e 's|mozilla/ISRG_Root_X1.crt|#mozilla/ISRG_Root_X1.crt|g' /etc/ca-certificates.conf
#  wget https://raw.githubusercontent.com/xenetis/letsencrypt-expiration/main/certificates/isrgrootx1.crt -P /usr/local/share/ca-certificates/
#  wget https://raw.githubusercontent.com/xenetis/letsencrypt-expiration/main/certificates/lets-encrypt-r3.crt -P /usr/local/share/ca-certificates/
#  update-ca-certificates -f -v
#

COPY gateway-1.4.5.patch /

RUN svn checkout --trust-server-cert --non-interactive https://svn.kannel.org/gateway/tags/version_1_4_5 /gateway-1.4.5 \
  && export CFLAGS="-fcommon" && cd /gateway-1.4.5 \
  && cat /gateway-1.4.5.patch | patch -p1 \
  && ./configure --prefix=/usr --enable-pcre \
  --sysconfdir=/etc/kannel --localstatedir=/var \
  --enable-docs=no --enable-start-stop-daemon=no \
  --without-sdb --without-oracle --without-sqlite2  \
  --with-mysql --with-mysql-dir=/usr/lib/mysql/ \
  --enable-debug --enable-assertions --with-defaults=speed \
  --enable-localtime \
  && touch .depend \
  && make depend \
  && make \
  && make DESTDIR=/install install \
  && make install \
  && cp test/fakesmsc /install/usr/bin/ \
  && cd addons/sqlbox \
  && ./bootstrap \
  && ./configure --prefix=/usr --sysconfdir=/etc/kannel --localstatedir=/var \
  && make \
  && make DESTDIR=/install install \
  && cd ../opensmppbox \
#  && ./bootstrap \
  && ./configure --prefix=/usr --sysconfdir=/etc/kannel --localstatedir=/var \
  && make \
  && make DESTDIR=/install install

FROM base

COPY --from=build --chown=app_user:app_group /install/usr /usr

#  && SUDO_FORCE_REMOVE=yes apt-get remove --purge -y sudo ${BUILD_DEPS} \
RUN apt-get update \
  && SUDO_FORCE_REMOVE=yes apt-get remove --purge -y sudo \
  && apt-get autoremove -y \
  && apt-get install -y --no-install-recommends ${RUNTIME_DEPS} \
  && rm -rf /usr/share/man \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/*
  && chown app_user:app_group -Rv /var/log/supervisor/

COPY --chown=app_user:app_group docker-entrypoint.sh /
COPY --chown=app_user:app_group kannel.conf.template /etc/kannel/
COPY --chown=app_user:app_group opensmppbox.conf.template /etc/kannel/
COPY --chown=app_user:app_group supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 13013 13000 2346 13015

VOLUME ["/var/spool/kannel", "/etc/kannel", "/var/log/kannel"]

CMD ["/usr/bin/supervisord"]

HEALTHCHECK --interval=1m --retries=5 --start-period=15s \
  CMD /docker-entrypoint.sh healthcheck

#fakesmsc -H localhost  -r 13014 -m 0 foo

