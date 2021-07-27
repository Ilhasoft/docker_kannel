#!/bin/bash

FILES=( "/etc/kannel/kannel.conf" "/etc/kannel/opensmppbox.conf" )

for f in "${FILES[@]}" ; do
	if [ -r "${f}.template" ] ; then
		envsubst < "${f}.template" > "${f}"
	fi
done

if [[ "healthcheck" == "$1" ]]; then
	if curl http://127.0.0.1:13000/status -sL | fgrep "${SMSC_ID}" | fgrep -qs '(online ' ; then
		echo "${SMSC_ID} not online"
		exit 1
	fi
	exit 0
fi

exec "$@"

