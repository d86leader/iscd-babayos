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

  .kernel_runtime : ALIGN(0x1000) {build/runtime_memory.o(.kernel_runtime)}
}
