; vim: ft=nasm ts=2 sw=2 expandtab

;; Interrupt handlers for various devices
;; And subroutines to initialize them

global initialize_pit
global pit_handler
global page_fault_handler
global gp_handler
global setup_handlers

%include "headers/interrupts.asmh"
%include "headers/putstr.asmh"


;; Initializes timer to send irq0 at desired rate
; initialize_pit {{{
;; ARGS
;;    r8 - timer rate
;; modifies rax
initialize_pit:
%push pit
%define PIT_C0 0x40
%define PIT_COMMAND 0x43
 ;; disable interrupts
 pushfq
 cli

 ;; channel 0, lobyte/hibyte, rate generator
 mov al, 00110100b
 out PIT_COMMAND, al

 ;; low byte of reload value
 mov al, r8b
 out PIT_C0, al
 ;; high byte of reload value
 shr r8, 8
 mov al, r8b
 out PIT_C0, al

 popfq
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

  mov rsi, pit_handler
  mov rdi, 32
  call set_int_handler

  mov rsi, page_fault_handler
  mov rdi, 14
  call set_int_handler

  mov rsi, gp_handler
  mov rdi, 13
  call set_int_handler

  ret
; }}}

;;;;; Interrupt handlers ;;;;;


; stub_handler {{{
stub_handler:
  iretq
; }}}


; pit_handler {{{
pit_handler:

section .data
 .pit_counter: dq 1

section .text
 cmp qword [.pit_counter], qword 32
 jb .ret

 mov qword [.pit_counter], qword 0
 SAFE_PUTS "Itervalled out"

.ret:
 inc qword [.pit_counter]
 end_of_interrupt 0
 iretq
 ; }}}


; page_fault_handler {{{
page_fault_handler:
section .data
 .msg: db "Caught page fault with errcode 0x", 27, 'x'
       db " with instruction at address 0x", 27, 'x'
       db ". Stopping", 0
section .text
 cli
 mov rbp, rsp ;; we have error code and rip saved on stack already. Pass them
              ;; to putstr
 mov rsi, .msg
 call putstr_64
 .hang: jmp .hang
 ; }}}


; gp_handler {{{
gp_handler:
section .data
 .msg: db "Caught general protection failure with errcode 0x", 27, 'x'
       db " with instruction at address 0x", 27, 'x'
       db ". Stopping", 0
section .text
 cli
 mov rbp, rsp ;; we have error code and rip saved on stack already. Pass them
              ;; to putstr
 mov rsi, .msg
 call putstr_64
 .hang: jmp .hang
 ; }}}
