# FreeBSD Dockerbox Debian

This is the repository for building the disk image for [FreeBSD Dockerbox](https://github.com/leafoliage/freebsd-dockerbox).

## Build ISO

Install xorriso and gcpio.

```sh
pkg install xorriso gcpio
```

Build dockerbox debian ISO.

```sh
make
```
