/* vim: ts=2 sw=2 expandtab */
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

  .idt : ALIGN(0x1000)
  {
    build/interrupts.o(.idt)
  }
}
