#!/bin/sh
. /usr/local/etc/dockerbox/dockerbox.conf
mkdir -p "${shared_folder}"
systemd-mount --collect \
  --type=9p \
  --options=trans=virtio,version=9p2000.L,cache=mmap,posixacl \
  shared_folder "${shared_folder}"
