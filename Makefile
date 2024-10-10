OFFICIAL_ISO=debian.iso
ISO_NAME=dockerbox-debian.iso

isofiles:
	if [ ! -f ${OFFICIAL_ISO} ]; then exit 1; fi
	mkdir isofiles
	xorriso -osirrox on -indev ${OFFICIAL_ISO} -extract / isofiles/
	dd if=${OFFICIAL_ISO} bs=1 count=432 of=isohdpfx.bin
	chmod -R +w isofiles/install.amd/
	gunzip isofiles/install.amd/initrd.gz
	echo preseed.cfg | gcpio -H newc -o -A -F isofiles/install.amd/initrd
	gzip isofiles/install.amd/initrd
	chmod -R -w isofiles/install.amd/

iso: isofiles
	cp preseed.cfg isofiles
	chmod +w isofiles/boot/grub/grub.cfg
	cat grub.cfg > isofiles/boot/grub/grub.cfg
	chmod -w isofiles/boot/grub/grub.cfg
	
	chmod +w isofiles/md5sum.txt
	find -L isofiles -type f ! -name isofiles/md5sum.txt -print0 | xargs -0 md5 | tee isofiles/md5sum.txt
	chmod -w isofiles/md5sum.txt
	
	xorriso -as mkisofs -o ${ISO_NAME} \
		-isohybrid-mbr isohdpfx.bin \
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
		isofiles/

clean:
	if [ -d isofiles ]; then rm -rf isofiles; fi
