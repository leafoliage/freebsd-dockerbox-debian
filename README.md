# FreeBSD Dockerbox Debian

This is the repository for building the disk image for [FreeBSD Dockerbox](https://github.com/leafoliage/freebsd-dockerbox).

## Build ISO

If you haven't prepared a bridge and a tap interface, use the following command to create one, as internet would be needed during installation.

```sh
ifconfig bridge create up
ifconfig tap create up
ifconfig <bridge_intf> addm <your_main_external_intf> addm <tap_intf>
```

> Note: get-tap.sh automatically chooses the first unused tap interface to use

Install xorriso and gcpio.

```sh
pkg install xorriso gcpio
```

Build dockerbox debian ISO.

```sh
make
```

Install built image

```sh
make install

# Alternatively
make install-root-disk
```

Clean build or clean build while keeping downloaded Debian official ISO.

```sh
make clean
make clean-keep-remote-iso
```
