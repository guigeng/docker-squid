#!/bin/bash
set -e

SQUID_VERSION=$(/usr/sbin/squid -v | grep Version | awk '{print $4}')

SQUID_CONFIG_FILE=/etc/squid/squid.conf

sed -i "s/^workers.*$/workers $(nproc --all)/g" ${SQUID_CONFIG_FILE}

exec /usr/sbin/squid -f ${SQUID_CONFIG_FILE} --foreground -sYC
