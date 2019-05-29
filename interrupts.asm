; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 64]

global idt_descriptor
global set_int_handler
global initialize_pic
global setup_handlers

%include "headers/devices.asmh"
%include "headers/multitask.asmh"

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


;; Put all handlers into idt
; setup_handlers {{{
;; SUBROUTINE
;; modifies rax, rcx, rdi, rsi
setup_handlers:
  mov rcx, 256
  handler_set_loop:
   mov rsi, stub_handler
   mov rdi, rcx
   call set_int_handler
   loop handler_set_loop

 call setup_device_handlers

 mov rsi, fork_handler
 mov rdi, 100
 call set_int_handler

 ret
; }}}


; stub_handler {{{
stub_handler:
  iretq
; }}}


; fork_handler {{{
fork_handler:
  jmp ll_fork_handler
; }}}


;; initialize pic8259 and its slave to specified offset with specified
;; interrupt masks
; initialize_pic {{{
;; ARGS
;;    rsi - first interrupt vector to be used by pics
;;    r9  - mask for first pic
;;    r10 - mask for second pic
;; modifies rax
%push pic
%define PIC1_COMMAND 0x20
%define PIC1_DATA    0x21
%define PIC2_COMMAND 0xa0
%define PIC2_DATA    0xa1
initialize_pic:

 ;; start initialization sequence in cascade with 4-th step
 mov al, 00010001b
 out PIC1_COMMAND, al
 out PIC2_COMMAND, al

 ;; tell desired offsets
 mov ax, si
 out PIC1_DATA, al
 add al, 8
 out PIC2_DATA, al

 ;; tell pics about each other
 mov al, 100b ;; bit mask for 2-nd pin
 out PIC1_DATA, al
 mov al, 2 ;; second pin
 out PIC2_DATA, al

 ;; use 8086 mode
 mov al, 1
 out PIC1_DATA, al
 out PIC2_DATA, al

 ;; set masks
 mov al, r9b
 out PIC1_DATA, al
 mov al, r10b
 out PIC2_DATA, al

 ret
%pop pic
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

;; this section is aligned on page boundary in linker script
;; and it uses exactly a page of space

plain_idt:
%rep 256
  def_int_gate 00b
%endrep
.size equ $ - plain_idt
