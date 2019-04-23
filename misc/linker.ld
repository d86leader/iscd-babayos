/* vim: ts=2 sw=2 expandtab
*/
SECTIONS
{
  . = 0x7e00;
  .text :
  {
    build/kernel.o(.text)
    *(.text)
  }

  .data : { *(.data) }
  .rodata : { *(.rodata) }
  .bss : { *(.bss) }

  .idt : ALIGN(0x10)
  {
    build/interrupts.o(.idt)
  }

  .pml4   : ALIGN(0x1000) {}
  .pdpt_0 : ALIGN(0x1000) {}
  .pd_0   : ALIGN(0x1000) {}
  .pt_0   : ALIGN(0x1000) {}

  .kernel_runtime : ALIGN(0x1000) {build/runtime_memory.o(.kernel_runtime)}
}
