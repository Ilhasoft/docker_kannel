FROM debian:jessie-slim as base

ARG APP_UID=1000
ARG APP_GID=500

ARG BUILD_DEPS="\
  build-essential subversion ntp nano wget cvs subversion curl git-core unzip autoconf \
  automake1.11 libtool flex debhelper pkg-config libpam0g-dev intltool checkinstall docbook docbook-xsl \
  build-essential libpcre3 libpcre3-dev libc6-dev g++ gcc autotools-dev libncurses5-dev m4 tex-common \
  texi2html texinfo libxml2-dev \
  openssl libssl-dev locales libmysqlclient-dev libmysql++-dev supervisor libtool-bin"
ARG RUNTIME_DEPS="\
  curl unzip libxml2 libmysqlclient18 gettext-base \
  libpcre3 openssl supervisor bash netcat curl"

ARG VERSION="0.1"

# set environment variables
ENV VERSION=${VERSION} \
  RUNTIME_DEPS=${RUNTIME_DEPS} \
  BUILD_DEPS=${BUILD_DEPS} \
  PATH="/install/bin:${PATH}"

LABEL version=${VERSION} \
  os="Debina" \
  os.version="9" \
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

RUN wget -c "https://snapshot.debian.org/archive/debian/20130517T034320Z/pool/main/b/bison/bison_2.7.1.dfsg-1_amd64.deb" "https://snapshot.debian.org/archive/debian/20130517T034320Z/pool/main/b/bison/libbison-dev_2.7.1.dfsg-1_amd64.deb" \
  && dpkg -i *.deb

#RUN cd /usr/local && \
#	mkdir /usr/local/src/kannel && \
#	cd /usr/local/src/kannel && \
#	svn checkout --trust-server-cert --non-interactive -r 5173 https://svn.kannel.org/gateway/trunk && \
#	mv trunk gateway && \
#	cd /usr/local/src/kannel/gateway && \
#	./configure -prefix=/usr/local/kannel -with-mysql -with-mysql-dir=/usr/lib/mysql/ -enable-debug -enable-assertions -with-defaults=speed \
#	-enable-localtime -enable-start-stop-daemon -enable-pam && \
#	touch .depend && \
#	make depend && \
#	make && \
#	make bindir=/usr/local/kannel install && \
#	cd /usr/local/src/kannel/gateway/addons/sqlbox && \
#    ./bootstrap && \
#    ./configure -prefix=/usr/local/kannel -with-kannel-dir=/usr/local/kannel && \
#    make && make bindir=/usr/local/kannel/sqlbox install && \
#    cd /usr/local/src/kannel/gateway/addons/opensmppbox && \
#    ./configure -prefix=/usr/local/kannel -with-kannel-dir=/usr/local/kannel && \
#    make && make bindir=/usr/local/kannel/smppbox install && \
#	mkdir /etc/kannel && \
#	mkdir /var/log/kannel && \
#	mkdir /var/log/kannel/gateway && \
#	mkdir /var/log/kannel/smsbox && \
#	mkdir /var/log/kannel/wapbox && \
#	mkdir /var/log/kannel/smsc && \
#	mkdir /var/log/kannel/sqlbox && \
#	mkdir /var/log/kannel/smppbox && \
#	mkdir /var/spool/kannel && \
#	chmod -R 755 /var/spool/kannel && \
#	chmod -R 755 /var/log/kannel && \
#	cp /usr/local/src/kannel/gateway/gw/smskannel.conf /etc/kannel/kannel.conf && \
#	cp /usr/local/src/kannel/gateway/debian/kannel.default /etc/default/kannel && \
#	cp /usr/local/src/kannel/gateway/addons/sqlbox/example/sqlbox.conf.example /etc/kannel/sqlbox.conf && \
#	cp /usr/local/src/kannel/gateway/addons/opensmppbox/example/opensmppbox.conf.example /etc/kannel/opensmppbox.conf && \
#	cp /usr/local/src/kannel/gateway/addons/opensmppbox/example/smpplogins.txt.example /etc/kannel/smpplogins.txt && \
#	rm -rf /usr/local/src/kannel/gateway && \
#	apt-get -y clean
RUN svn checkout --trust-server-cert --non-interactive https://svn.kannel.org/gateway/tags/version_1_4_5 /build && cd /build \
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
  && rm -rf /var/lib/apt/lists/*

COPY --chown=app_user:app_group docker-entrypoint.sh /
COPY --chown=app_user:app_group kannel.conf.template /etc/kannel/
COPY --chown=app_user:app_group opensmppbox.conf.template /etc/kannel/
COPY --chown=app_user:app_group supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 13013 13000 2346 13015

VOLUME ["/var/spool/kannel", "/etc/kannel", "/var/log/kannel"]

CMD ["/usr/bin/supervisord"]

HEALTHCHECK --interval=1m --retries=10 --start-period=1m \
  CMD /docker-entrypoint.sh healthcheck

