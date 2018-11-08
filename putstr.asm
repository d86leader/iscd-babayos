; vim: ft=nasm ts=2 sw=2 expandtab

global putstr
global putstr_current_line

section .text
; putstr {{{
;; ARGS
;;    esi - string to put, 0-terminated
;;  modifies edi, esi, eax, ecx
putstr:
 mov edi, 0xb8000
 ;; load current line offset in symbol pairs to cx
 xor ecx, ecx
 mov cx, [putstr_current_line]
 add edi, ecx

 .putchar:
  lodsb
  test al, al
  jz .inc_line
  stosb
  mov al, 0x07
  stosb
  jmp .putchar

 .inc_line:
  ;; increment current line, loop to start if too big
  add cx, 80*2
  mov [putstr_current_line], cx
  cmp cx, 25*80*2
  jb .exit
  ;; was too big, put zero there
  xor cx, cx
  mov [putstr_current_line], cx

 .exit:
 ret
; }}}

section .data
putstr_current_line: dw 0
