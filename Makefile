DEBIAN_MIRROR=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
REMOTE_ISO!=fetch -qo - ${DEBIAN_MIRROR}/ \
		| grep -Eom 1 'debian-(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-amd64-netinst\.iso' \
		| head -1

BUILD_DIR=build
INSTALL_DIR=/usr/local/share/dockerbox
OFFICIAL_ISO=${BUILD_DIR}/${REMOTE_ISO}
DOCKERBOX_ISO=${BUILD_DIR}/dockerbox-${REMOTE_ISO}
ISOFILES=${BUILD_DIR}/isofiles
DEVICE_MAP=${BUILD_DIR}/device.map

ROOT_DISK=${BUILD_DIR}/disk.img
ROOT_SIZE=3G
DOCKER_DISK=${BUILD_DIR}/docker.img
DOCKER_SIZE=20G
TAP_INTF!=./get-tap.sh
GUEST_NAME=dockerbox-install
VERSION=0.3.0
PACKAGE_DIR=dockerbox-img-${VERSION}


all: ${DOCKERBOX_ISO} build

${OFFICIAL_ISO}:
	@echo "Fetching latest Debian DVD-1 ISO name..."
	@if [ -z "$(REMOTE_ISO)" ]; then echo "ERROR: Could not determine ISO filename"; exit 1; fi
	@mkdir -p build
	@echo "Downloading $(REMOTE_ISO)..."
	fetch -o ${OFFICIAL_ISO} ${DEBIAN_MIRROR}/$(REMOTE_ISO)
	@echo "Downloading SHA512SUMS..."
	fetch -o build/SHA512SUMS.tmp ${DEBIAN_MIRROR}/SHA512SUMS
	@echo "Verifying checksum..."
	grep "$(OFFICIAL_ISO)" build/SHA512SUMS.tmp | sed 's/$(REMOTE_ISO)/debian.iso/' | sha512sum -c -
	@rm -f build/SHA512SUMS.tmp
	@echo "Verification passed."

${ISOFILES}: ${OFFICIAL_ISO}
	mkdir -p ${ISOFILES}
	xorriso -osirrox on -indev ${OFFICIAL_ISO} -extract / ${ISOFILES}/
	dd if=${OFFICIAL_ISO} bs=1 count=432 of=build/isohdpfx.bin
	chmod -R +w ${ISOFILES}/install.amd/
	gunzip ${ISOFILES}/install.amd/initrd.gz
	echo preseed.cfg | gcpio -H newc -o -A -F ${ISOFILES}/install.amd/initrd
	gzip ${ISOFILES}/install.amd/initrd
	chmod -R -w ${ISOFILES}/install.amd/

${DOCKERBOX_ISO}: ${ISOFILES}
	cp preseed.cfg ${ISOFILES}
	chmod +w ${ISOFILES}/boot/grub/grub.cfg
	cat grub.cfg > ${ISOFILES}/boot/grub/grub.cfg
	chmod -w ${ISOFILES}/boot/grub/grub.cfg

	chmod +w ${ISOFILES}/md5sum.txt
	find -L ${ISOFILES} -type f ! -name md5sum.txt -print0 | xargs -0 md5sum | tee ${ISOFILES}/md5sum.txt
	chmod -w ${ISOFILES}/md5sum.txt

	xorriso -as mkisofs -o ${DOCKERBOX_ISO} \
		-isohybrid-mbr build/isohdpfx.bin \
		-b isolinux/isolinux.bin \
		-c isolinux/boot.cat \
		-boot-load-size 4 \
		-boot-info-table \
		-no-emul-boot \
		-eltorito-alt-boot \
		-e boot/grub/efi.img \
		-no-emul-boot \
		-isohybrid-gpt-basdat \
		-isohybrid-apm-hfsplus \
		${ISOFILES}/

${DOCKER_DISK}:
	truncate -s ${DOCKER_SIZE} ${DOCKER_DISK}

${DEVICE_MAP}:
	echo "(cd0) ${DOCKERBOX_ISO}" > ${DEVICE_MAP}

${ROOT_DISK}:
	truncate -s ${ROOT_SIZE} ${ROOT_DISK}

build: ${DEVICE_MAP} ${DOCKER_DISK} ${ROOT_DISK}
	grub-bhyve -m ${DEVICE_MAP} -r cd0 -M 1024M ${GUEST_NAME}
	bhyve -A -H -P -s 0:0,hostbridge -s 1:0,lpc \
		-s 2:0,virtio-net,${TAP_INTF} \
		-s 3:0,virtio-blk,./${ROOT_DISK} \
		-s 4:0,virtio-blk,./${DOCKER_DISK} \
		-s 5:0,ahci-cd,./${DOCKERBOX_ISO} \
		-l com1,stdio -c 4 -m 1024M ${GUEST_NAME}
	bhyvectl --destroy --vm=${GUEST_NAME}

install:
	install -m 0744 ${ROOT_DISK} ${INSTALL_DIR}
	install -m 0644 ${DOCKER_DISK} ${INSTALL_DIR}

test-run:
	echo "(hd0) ${ROOT_DISK}" > ${BUILD_DIR}/device.test-run
	grub-bhyve -m ${BUILD_DIR}/device -r hd0,msdos1 -M 1024M ${GUEST_NAME}
	bhyve -A -H -P -s 0:0,hostbridge -s 1:0,lpc \
		-s 2:0,virtio-net,${TAP_INTF} \
		-s 3:0,virtio-blk,./${ROOT_DISK} \
		-s 4:0,virtio-blk,./${DOCKER_DISK} \
		-s 5:0,ahci-cd,./${DOCKERBOX_ISO} \
		-l com1,stdio -c 4 -m 1024M ${GUEST_NAME}
	bhyvectl --destroy --vm=${GUEST_NAME}
	rm ${BUILD_DIR}/device

pack:
	mkdir ${PACKAGE_DIR}
	chown 0:0 ${ROOT_DISK}
	mv ${ROOT_DISK} ${PACKAGE_DIR}
	tar czf ${PACKAGE_DIR}.tar.zstd ${PACKAGE_DIR}/disk.img
	mv ${PACKAGE_DIR}/disk.img ${BUILD_DIR}
	rmdir ${PACKAGE_DIR}

clean:
	rm -rf build
	if [ -e /dev/vmm/${GUEST_NAME} ]; then bhyvectl --destroy --vm=${GUEST_NAME}; fi
	rm -f dockerbox-img*.tar.zstd

clean-keep-remote-iso:
	mv ${OFFICIAL_ISO} .
	rm -rf ${BUILD_DIR}/*
	mv ${REMOTE_ISO} ${BUILD_DIR}
	if [ -e /dev/vmm/${GUEST_NAME} ]; then bhyvectl --destroy --vm=${GUEST_NAME}; fi
	rm -f dockerbox-img*.tar.zstd
