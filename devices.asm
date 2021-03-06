; vim: ft=nasm ts=2 sw=2 expandtab

;; Interrupt handlers for various devices
;; And subroutines to initialize them

global initialize_pit
global setup_device_handlers

%include "headers/interrupts.asmh"
%include "headers/putstr.asmh"
%include "headers/keyboard.asmh"
%include "headers/multitask.asmh"


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


;; Put device handlers into idt
; setup_handlers {{{
;; SUBROUTINE
;; modifies rax, rdi, rsi
setup_device_handlers:
  push r8
  push r9

  mov r8, base_pit_handler
  mov r9, 32
  call set_int_handler

  mov r8, base_keyboard_handler
  mov r9, 33
  call set_int_handler

  mov r8, page_fault_handler
  mov r9, 14
  call set_int_handler

  mov r8, gp_handler
  mov r9, 13
  call set_int_handler

  pop r9
  pop r8
  ret
; }}}

;;;;; Interrupt handlers ;;;;;


; base_pit_handler {{{
base_pit_handler:
 call pit_handler
 push rax
 end_of_interrupt 0
 pop rax
 iretq
 ; }}}


; base_keyboard_handler {{{
base_keyboard_handler:
 call keyboard_handler
 push rax
 end_of_interrupt 1
 pop rax
 iretq
; }}}



; page_fault_handler {{{
page_fault_handler:
 cli
 mov r9, rsp ;; we have error code and rip saved on stack already. Pass them
             ;; to putstr
 mov r8, .msg
 call putstr_64
 .hang: jmp .hang

section .data
 .msg: db "Caught page fault with errcode 0x", 27, 'x'
       db " with instruction at address 0x", 27, 'x'
       db ". Stopping", 0
section .text
 ; }}}


; gp_handler {{{
gp_handler:
 cli
 mov r9, rsp ;; we have error code and rip saved on stack already. Pass them
             ;; to putstr
 mov r8, .msg
 call putstr_64
 .hang: jmp .hang

section .data
 .msg: db "Caught general protection failure with errcode 0x", 27, 'x'
       db " with instruction at address 0x", 27, 'x'
       db ". Stopping", 0
section .text
 ; }}}
