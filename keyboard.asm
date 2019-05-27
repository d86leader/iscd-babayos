; vim: ft=nasm ts=2 sw=2 expandtab

;; Keyboard related routines

global initialize_ps2
global keyboard_handler

%include "headers/putstr.asmh"
%include "headers/fail.asmh"


%define PS_STATUS 0x64
%define PS_COMMAND 0x64
%define PS_DATA 0x60


;; Write a command to keyboard buffer
; kb_write {{{
;; ARGS
;;  rsi - command byte
;; MODIFIES rax
kb_write:
 .wait:
  in al, PS_STATUS
  test al, (1 << 5)
  jnz .timeout
  test al, 1 ;; flag: output buffer full
  jnz .wait

 xchg rax, rsi
 out PS_DATA, al
 xchg rax, rsi

 ret

 .timeout:
  PUTS "timeout when sending command to keyboard"
  ret
; }}}


;; Write a command to keyboard buffer
; kb_read {{{
;; RETURNS rax - data read
kb_read:
 .wait:
  in al, PS_STATUS
  test al, (1 << 5)
  jnz .timeout
  test al, 10b ;; flag: input buffer full
  jnz .wait

 in al, PS_DATA

 ret

 .timeout:
  PUTS "timeout when sending command to keyboard"
  ret
; }}}


; initialize_ps2 {{{
initialize_ps2:
 ;; enable keyboard
 mov al, 0xae
 out PS_COMMAND, al
 ;; disable mouse
 mov al, 0xa7
 out PS_COMMAND, al

 ret
 ;; disable leds
 mov si, 0xed
 call kb_write
 mov si, 111b
 call kb_write

 call kb_read
 push rax
 mov rbp, rsp
 PUTS "Got keyboard response: 0xx"
 add rsp, 8

 ;; set scan code set

 ;; enable scanning
; }}}


; keyboard_handler {{{
keyboard_handler:
 push rax
 push rbx
 push rcx
 push rdx
 push rsi
 push rdi
 push rbp

 xor rax, rax

 in al, PS_STATUS
 push rax
 in al, PS_DATA
 push rax
 mov rbp, rsp

 call nr2char
 cmp al, 255
 je .unrecognized_char

  mov [.char], al
  mov rsi, .good_char_str
  jmp .do_print

 .unrecognized_char
  mov rsi, .unrecognized_str

 .do_print
 call putstr_64
 add rsp, 16

 pop rbp
 pop rdi
 pop rsi
 pop rdx
 pop rcx
 pop rbx
 pop rax
 ret

 section .data
  .good_char_str: db "pressed "
  .char: db "#"
  db 0
  .unrecognized_str: db "urecognized char",0

 section .text
; }}}


; nr2char {{{
;; ARGS
;;    rax - keycode
;; RETURNS rax - char
nr2char:

 section .data
  .keycodes:
  .digits: db 255, "1234567890-="
  .upper:  db "	qwertyuiop[]", 10
  .middle: db 255, "asdfghjkl;'`"
  .lower:  db 255, "\\zxcvbnm,./", 255
  .lowest: db 255, " ", 255
  .mapped equ $ - .keycodes

 section .text
  cmp rax, .mapped
  jg .bad_code
  mov al, [.keycodes + rax]
  ret

  .bad_code:
  mov al, 255
  ret
; }}}
