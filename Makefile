DISKNAME = build/disk.img
LOADERNAME = build/loader.o
MAGICNUMBERFILE = misc/magic_number


all: $(DISKNAME) run


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

build/%.o: %.asm
	$(ASM) $(ASMFLAGS) $^ -o $@


#making a bootable disk with loader

$(DISKNAME): $(LOADERNAME)
	dd if=$< of=$@ bs=1 count=512 conv=notrunc
	#copy magic number to the end
	dd if=$(MAGICNUMBERFILE) of=$@ bs=1 oflag=seek_bytes seek=510 conv=notrunc
