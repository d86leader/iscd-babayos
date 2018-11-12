; vim: ft=nasm ts=2 sw=2 expandtab

global putstr
global putstr_current_line
global scroll_down

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

; scroll_down {{{
;; move all text up and free one line at the bottom
scroll_down:
 ;; move 24 lines of 80 words up
 mov edi, 0xb8000
 mov esi, edi
 add esi, 80*2 ;; one line
 mov ecx, 80*24 ;; screen without one line
 rep movsw

 ;; fill bottom line with spaces
 mov ax, 0x0720
 mov ecx, 80
 rep stosw

 ;; decrement current line
 mov cx, [current_line]
 sub ecx, 80*2
 mov [current_line], cx

 ret

; }}}

section .data
current_line:
putstr_current_line: dw 0
