.PHONY: run
run: OVMF_CODE.fd OVMF_VARS.fd
	# Based on https://wiki.osdev.org/UEFI#Emulation_with_QEMU_and_OVMF
	qemu-system-x86_64 -cpu qemu64 \
		-drive if=pflash,format=raw,unit=0,file=OVMF_CODE.fd,readonly=on \
		-drive if=pflash,format=raw,unit=1,file=OVMF_VARS.fd \
		-net none

# Assuming 'ovmf' package on Arch Linux is installed.
OVMF_CODE.fd: /usr/share/ovmf/x64/OVMF_CODE.fd
	cp $< $@
OVMF_VARS.fd: /usr/share/ovmf/x64/OVMF_VARS.fd
	cp $< $@

.PHONY: clean
clean:
	rm -f main
