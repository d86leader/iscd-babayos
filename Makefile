DISKNAME = build/disk.img
LOADERNAME = build/loader.o
LOADERCODE = loader.asm
KERNELNAME = build/kernel
KERNELSYMBOLS = build/kernel.elf
KERNELBINARIES = build/kernel.o build/putstr_32.o build/putstr_64.o build/interrupts.o build/pages.o build/runtime_memory.o build/devices.o
MAGICNUMBERFILE = misc/magic_number


all: disk run
server: disk elf run-server
disk: $(DISKNAME)
elf: $(KERNELSYMBOLS)

clean:
	rm build/*


# running qemu (optionally server)

QEMU = qemu-system-x86_64
QEMUFLAGS = -monitor stdio -m 32M -device isa-debug-exit,iobase=0xf4,iosize=0x04
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
ASMFLAGS = -f elf64 -F dwarf -g
LDFILE = misc/linker.ld
LDFLAGS = -m elf_x86_64 -T $(LDFILE)

$(LOADERNAME): $(LOADERCODE) $(KERNELNAME)
	$(eval SECS := $(shell bash misc/tell_sectors.sh $(KERNELNAME)))
	$(ASM) -f bin $< -dsystem_sectors=$(SECS) -o $@

build/%.o: %.asm headers/*.asmh
	$(ASM) $(ASMFLAGS) $< -o $@

$(KERNELNAME): $(KERNELBINARIES) $(LDFILE)
	ld --oformat=binary $(LDFLAGS) -o $@ $^

$(KERNELSYMBOLS): $(KERNELBINARIES) $(LDFILE)
	ld $(LDFLAGS) -o $@ $^


#making a bootable disk with loader

$(DISKNAME): $(LOADERNAME) $(KERNELNAME)
	[ `du -b $(LOADERNAME) | cut -f1` -le 510 ] #loader too large
	#overwrite junk left from previous compiles with zeroes
	dd if=/dev/zero of=$@ bs=1M count=1 >/dev/null 2>/dev/null
	#write my sectors
	dd if=$(LOADERNAME) of=$@ bs=1 count=512 conv=notrunc >/dev/null 2>/dev/null
	dd if=$(KERNELNAME) of=$@ bs=1 conv=notrunc oflag=seek_bytes seek=512 >/dev/null 2>/dev/null
	#copy magic number to the end
	dd if=$(MAGICNUMBERFILE) of=$@ bs=1 oflag=seek_bytes seek=510 conv=notrunc >/dev/null 2>/dev/null
