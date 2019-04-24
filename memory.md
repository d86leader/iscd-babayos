# Memory layout

My loader is loaded, as per bios, at 0x7c00 and uses 512 bytes

My kernel is loaded at 0x7e00.

My stack is located at range from 0x7bf0 to 0x7000, which is almost 3KiB.
Going lower than that would overwrite some kernel internal memory.

Kernel internal memory is located at range 0x0 to 0x7000, and from kernel code end onwards.
The pages for internal memory are allocated via macros defined in runtime_memory.asm
