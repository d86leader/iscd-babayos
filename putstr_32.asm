; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 32]


global putstr_32
global putstr_current_line

section .text
; putstr {{{
;; ARGS
;;    esi - string to put, 0-terminated
;; modifies
;;    eax - current symbol
;;    ebx - current colour
;;    ecx - symbols left in current line until end
putstr_32:
 mov edi, [putstr_current_line]
 xor ebx, ebx
 mov bl, 0x07
 mov ecx, 80
 xor eax, eax

.putchar_loop:
 lodsb
 cmp al, 32
 jb .handle_special
 call putchar
 jmp .putchar_loop

.handle_special:
 ;; just finish writing when encountered special char

 ;; go to next line
 shl ecx, 1
 add edi, ecx
 mov [putstr_current_line], edi

 ret
; }}}

; putchar {{{
;; not so much a procedure, but a subroutine to many procedures here
;; registers meaning - same as putstr
;; puts a symbol and corrects current line as needed. Maybe redraws the screen
putchar:
 stosb
 mov al, bl
 stosb
 dec ecx

 test ecx, ecx
 jnz .return
 ;; ecx is zero, which means line has ended. Start a new line.
 mov ecx, 80
 mov [putstr_current_line], edi

.return:
 ret
; }}}



section .data
putstr_current_line: dd 0
