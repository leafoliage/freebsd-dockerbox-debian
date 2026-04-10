#!/bin/sh
taps=$(ifconfig | grep -Eo "^tap(0|[1-9][0-9]*)")
for tap in ${taps}; do
	if [ -z "$(ifconfig ${tap} | grep 'status: active' )" ]; then
		echo ${tap}
		exit
	fi
done
ifconfig tap create up
