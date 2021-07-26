#!/bin/bash

FILES=( "/etc/kannel/kannel.conf" "/etc/kannel/opensmppbox.conf" )

for f in "${FILES[@]}" ; do
	if [ -r "${f}.template" ] ; then
		envsubst < "${f}.template" > "${f}"
	fi
done

exec "$@"

