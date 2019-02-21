; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 64]

global idt_descriptor
global set_int_handler

section .text

;; sets the handler for n-th interrupt to given address
; set_int_handler {{{
;; ARGS
;;    rsi - address of handler
;;    rdi - number of handler
;; modifies eax
set_int_handler:
 shl rdi, 4
 add rdi, plain_idt

 mov rax, rsi
 and rax, 0xffff
 mov [rdi + idt_entry.offset16], ax

 shr rsi, 16
 mov [rdi + idt_entry.offset32], si

 shr rsi, 16
 mov [rdi + idt_entry.offset64], esi

 ret
; }}}


section .data

idt_descriptor:
  dw plain_idt.size - 1
  dq plain_idt


; struc idt_entry {{{
struc idt_entry
  .offset16: resw 1
  .segment:  resw 1
  .ist:      resb 1
  .flags:    resb 1
  .offset32: resw 1
  .offset64: resd 1
  .zero:     resd 1
endstruc
; }}}


;; defines interrupt handler with privilege %1
; macro def_int_gate {{{
%macro def_int_gate 1
istruc idt_entry
  at idt_entry.offset16, dw 0    ;; offset lower bytes
  at idt_entry.segment,  dw 0x8  ;; code gdt segment
  at idt_entry.ist,      db 0    ;; don't use ist
  ;; present, %1 privelege, 0, gate size 32, 110
  at idt_entry.flags,    db 10001110b | (%1 << 5)
  at idt_entry.offset32, dw 0    ;; offset higher bytes
  at idt_entry.offset64, dd 0
  at idt_entry.zero,     dd 0    ;; reserved padding
iend
%endmacro
; }}}

;; defines trap handler with offset %1 and privilege %2
; macro def_trap_gate {{{
%macro def_trap_gate 1
istruc idt_entry
  at idt_entry.offset16, dw 0    ;; offset lower bytes
  at idt_entry.segment,  dw 0x8  ;; code gdt segment
  at idt_entryidt_entry.ist,      db 0    ;; don't use ist
  ;; present, %1 privelege, 0, gate size 32, 111
  at idt_entry.flags,    db 10001111b | (%1 << 5)
  at idt_entry.offset32, dw 0    ;; offset higher bytes
  at idt_entry.offset64, dd 0
  at idt_entry.zero,     dd 0
iend
%endmacro
; }}}



section .idt

;; this section is aligned on 16 byte boundary in linker script

plain_idt:
%rep 64
  align 16, db 0
  def_int_gate 00b
%endrep
.size equ $ - plain_idt
