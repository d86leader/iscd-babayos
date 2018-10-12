DISKNAME = build/disk.img
LOADERNAME = build/loader.o
LOADERCODE = loader.asm
KERNELNAME = build/kernel.o
MAGICNUMBERFILE = misc/magic_number


all: disk run
disk: $(DISKNAME)


# running qemu (optionally server)

QEMU = qemu-system-i386
QEMUFLAGS = -monitor stdio -m 32 -device isa-debug-exit,iobase=0xf4,iosize=0x04
QEMUSERVER = -s -S
QEMUDISK = -drive file=$(DISKNAME),format=raw

run:
	$(QEMU) $(QEMUFLAGS) $(QEMUDISK)

run-server:
	$(QEMU) $(QEMUSERVER) $(QEMUFLAGS) $(QEMUDISK)


# running gdb connected to qemu server

GDB = gdb -q
GDBCONFIG = -x misc/gdb-config

gdb:
	$(GDB) $(GDBCONFIG)


#compiling asm files

ASM = nasm
ASMFLAGS = -f bin

$(LOADERNAME): $(LOADERCODE) $(KERNELNAME)
	$(eval SECS := $(shell sh misc/tell_sectors.sh $(KERNELNAME)))
	$(ASM) $(ASMFLAGS) $< -dsystem_sectors=$(SECS) -o $@

build/%.o: %.asm
	$(ASM) $(ASMFLAGS) $^ -o $@


#making a bootable disk with loader

$(DISKNAME): $(LOADERNAME) $(KERNELNAME)
	[ `du -b $(LOADERNAME) | cut -f1` -le 510 ] #loader too large
	#overwrite junk left from previous compiles with zeroes
	dd if=/dev/zero of=$@ bs=1M count=1 >/dev/null 2>/dev/null
	#write my sectors
	bash misc/write_sectors.sh $@ $^
	#copy magic number to the end
	dd if=$(MAGICNUMBERFILE) of=$@ bs=1 oflag=seek_bytes seek=510 conv=notrunc >/dev/null 2>/dev/null
