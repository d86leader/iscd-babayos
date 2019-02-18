; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 32]

global idt_descriptor

section .text

;; defines interrupt handler with offset %1 and privilege %2
%macro def_int_gate 1
  dw (%1 & 0xffff) ;; offset lower bytes
  dw 0x8           ;; code gdt segment
  db 10001110b | (%2 << 5) ;; present, %2 privelege, 0, gate size 32, 110
  db 00000000b
  db (%1 >> 16)
%endmacro

;; defines trap handler with offset %1 and privilege %2
%macro def_trap_gate 2
  dw (%1 & 0xffff) ;; offset lower bytes
  dw 0x8           ;; code gdt segment
  db 10001111b | (%2 << 5) ;; present, %2 privelege, 0, gate size 32, 111
  db 00000000b
  db (%1 >> 16)
%endmacro


all_int_handler:
  mov eax, 228
  iret


section .data

idt_descriptor:
  dw plain_idt.size
  dd plain_idt

;; align idt on 8 byte boundary
align 8,db 0

plain_idt:
%rep 64
  def_int_gate all_int_handler
%endrep
.size equ $ - plain_idt
