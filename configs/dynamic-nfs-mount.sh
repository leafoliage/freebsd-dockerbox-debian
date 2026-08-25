#!/bin/sh
. /usr/local/etc/dockerbox/dockerbox.conf
if [ -n "${nfs_folder}" ]; then
  mkdir -p "${nfs_folder}"
  ip=$(ip -br -4 addr show dev enp0s2 | awk '{ print $3 }' | cut -d/ -f1)
  server=$(ip route show default | awk '{ print $3 }')
  if $(/sbin/showmount -e ${server} | grep -q "${nfs_folder} ${ip}"); then
    systemd-mount --collect \
      --type=nfs \
      "${server}:${nfs_folder}" "${nfs_folder}"
  fi
fi
