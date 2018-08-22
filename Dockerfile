FROM alpine:3.7 as build

RUN set -x \
	&& apk add --no-cache gcc g++ libc-dev curl gnupg libressl-dev perl-dev autoconf automake make pkgconfig heimdal-dev libtool libcap-dev 	linux-headers \
	&& mkdir -p /tmp/build \
	&& cd /tmp/build \
	&& curl -SsL http://www.squid-cache.org/Versions/v4//squid-4.2.tar.gz -o squid-4.2.tar.gz \
	&& tar --strip 1 -xzf squid-4.2.tar.gz \
	&& \
	CFLAGS="-g0 -O2" \
	CXXFLAGS="-g0 -O2" \
	LDFLAGS="-s" \
	\
	./configure \
		--build="$(uname -m)" \
		--host="$(uname -m)" \
		--prefix=/usr \
		--datadir=/usr/share/squid \
		--sysconfdir=/etc/squid \
		--libexecdir=/usr/lib/squid \
		--localstatedir=/var \
		--with-logdir=/var/log/squid \
		--disable-strict-error-checking \
		--disable-arch-native \
		--enable-removal-policies="lru,heap" \
		--enable-auth-digest \
		--enable-auth-basic \
		--enable-external-acl-helpers \
		--enable-auth-ntlm \
		--enable-auth-negotiate \
		--enable-silent-rules \
		--disable-mit \
		--enable-heimdal \
		--enable-delay-pools \
		--enable-openssl \
		--enable-ssl-crtd \
		--enable-security-cert-generators="file" \
		--enable-ident-lookups \
		--enable-cache-digests \
		--enable-referer-log \
		--enable-async-io \
		--enable-truncate \
		--enable-eui \
		--enable-htcp \
		--enable-carp \
		--enable-epoll \
		--enable-follow-x-forwarded-for \
		--enable-storeio="diskd,rock" \
		--enable-ipv6 \
		--enable-translation \
		--disable-snmp \
		--disable-dependency-tracking \
		--with-dl \
		--with-pthreads \
		--with-large-files \
		--with-default-user=squid \
		--with-openssl \
		--with-pidfile=/var/run/squid/squid.pid \
	&& cd /tmp/build \
	&& make -j $(grep -cs ^processor /proc/cpuinfo) \
	&& make install

FROM alpine:3.7
	
ENV SQUID_CONFIG_FILE=/etc/squid/squid.conf \
    TZ=Asia/Shanghai

RUN set -x \
    && deluser squid 2>/dev/null; delgroup squid 2>/dev/null; \
	addgroup -S squid -g 3128 && adduser -S -u 3128 -G squid -g squid -H -D -s /bin/false -h /var/cache/squid squid \
	&& apk add --no-cache libstdc++ heimdal-libs libcap libressl2.6-libcrypto libressl2.6-libssl libltdl 

COPY --from=build /etc/squid/ /etc/squid/
COPY --from=build /usr/lib/squid/ /usr/lib/squid/
COPY --from=build /usr/share/squid/ /usr/share/squid/
COPY --from=build /usr/sbin/squid /usr/sbin/squid
		
RUN install -d -o squid -g squid \
		/var/cache/squid \
		/var/log/squid \
		/var/run/squid \
	&& chmod +x /usr/lib/squid/* \
	&& echo 'include /etc/squid/conf.d/*.conf' >> "$SQUID_CONFIG_FILE" \
	&& install -d -m 755 -o squid -g squid /etc/squid/conf.d
	
COPY squid-log.conf /etc/squid/conf.d/

RUN	set -x \
    && apk add --no-cache --virtual .tz alpine-conf tzdata \
	&& /sbin/setup-timezone -z $TZ \
	&& apk del .tz 	
	
VOLUME ["/var/cache/squid"]	

EXPOSE 3128/tcp

USER squid

CMD ["sh", "-c", "/usr/sbin/squid -f ${SQUID_CONFIG_FILE} --foreground -z && exec /usr/sbin/squid -f ${SQUID_CONFIG_FILE} --foreground -YCd 1"]
