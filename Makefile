.PHONY: qemu
qemu: out/main out/startup.nsh OVMF_CODE.fd OVMF_VARS.fd
	# Based on https://wiki.osdev.org/UEFI#Emulation_with_QEMU_and_OVMF
	qemu-system-x86_64 -cpu qemu64 \
		-drive if=pflash,format=raw,unit=0,file=OVMF_CODE.fd,readonly=on \
		-drive if=pflash,format=raw,unit=1,file=OVMF_VARS.fd \
		-net none \
		-drive format=raw,file=fat:rw:out \
		-display type=gtk,zoom-to-fit=on

# Assuming 'ovmf' package on Arch Linux is installed.
OVMF_CODE.fd: /usr/share/ovmf/x64/OVMF_CODE.fd
	cp $< $@
OVMF_VARS.fd: /usr/share/ovmf/x64/OVMF_VARS.fd
	cp $< $@

out/main: src/main.asm src/impl.asm src/bootstrap.asm src/uefi.asm init/sys.f init/uefi.f
	mkdir -p out
	fasm $< $@

out/startup.nsh:
	mkdir -p out
	echo 'fs0:main' >out/startup.nsh

.PHONY: clean
clean:
	rm -rf out OVMF_CODE.fd OVMF_VARS.fd
