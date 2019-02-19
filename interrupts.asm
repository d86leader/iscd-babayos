; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 32]

global idt_descriptor
global set_int_handler
global all_int_handler

section .text

;; sets the handler for n-th interrupt to given address
; set_int_handler {{{
;; ARGS
;;    esi - address of handler
;;    edi - number of handler
;; modifies eax
set_int_handler:
 shl edi, 3
 add edi, plain_idt

 mov eax, esi
 and eax, 0xffff
 mov [edi + idt_entry.offset16], ax

 shr esi, 16
 mov [edi + idt_entry.offset32], si

 ret
; }}}


;; e05b ?
all_int_handler:
  mov eax, 228
  iret


section .data

idt_descriptor:
  dw plain_idt.size - 1
  dd plain_idt


; struc idt_entry {{{
struc idt_entry
  .offset16: resw 1
  .segment: resw 1
  .zero: resb 1
  .flags: resb 1
  .offset32: resw 1
endstruc
; }}}


;; defines interrupt handler with privilege %1
; macro def_int_gate {{{
%macro def_int_gate 1
istruc idt_entry
  at idt_entry.offset16, dw 0    ;; offset lower bytes
  at idt_entry.segment,  dw 0x8  ;; code gdt segment
  at idt_entry.zero,     db 00000000b
  ;; present, %1 privelege, 0, gate size 32, 110
  at idt_entry.flags,    db 10001110b | (%1 << 5)
  at idt_entry.offset32, dw 0    ;; offset higher bytes
iend
%endmacro
; }}}

;; defines trap handler with offset %1 and privilege %2
; macro def_trap_gate {{{
%macro def_trap_gate 1
istruc idt_entry
  at .offset16, dw 0    ;; offset lower bytes
  at .segment,  dw 0x8  ;; code gdt segment
  at .zero,     db 00000000b
  ;; present, %1 privelege, 0, gate size 32, 111
  at .flags,    db 10001111b | (%1 << 5)
  at .offset32, dw 0    ;; offset higher bytes
iend
%endmacro
; }}}



;; align idt on 8 byte boundary
align 8,db 0

plain_idt:
%rep 64
  def_int_gate 00b
%endrep
.size equ $ - plain_idt
