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
  jz .wait

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

 ;; TODO set scan code set

 ;; TODO enable scanning
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
 test al, 1
 jz .return

 in al, PS_DATA
 call nr2char
 cmp al, 255
 je .return

 mov [.char], al
 mov rsi, .good_char_str
 call putstr_64

 .return:
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
  .char: db "#", 0
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
