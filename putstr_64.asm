; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 64]


global putstr_64
extern putstr_current_line

section .text
; putstr {{{
;; ARGS
;;    rsi - string to put, 0-terminated
;; modifies
;;    rax - current symbol
;;    rbx - current colour
;;    rcx - symbols left in current line until end
;;    rdx - function to call / its return code
;;    rsi - pointer to source string
;;    rdi - pointer to destination screen
putstr_64:
 xor rdi, rdi
 mov edi, [putstr_current_line]
 xor rbx, rbx
 mov bl, 0x07
 mov rcx, 80
 xor rax, rax

.putchar_loop:
 lodsb
 cmp al, 32
 jb .handle_special
 call putchar
 jmp .putchar_loop

.handle_special:
 mov rdx, [special_char_handlers_64 + rax*8]
 call rdx
 ;; return code is in rdx, nonzero means stop
 test rdx, rdx
 jz .putchar_loop

 call next_line

 ret
; }}}


; putchar {{{
;; not so much a procedure, but a subroutine to many procedures here
;; registers meaning - same as putstr
;; puts a symbol and corrects current line as needed. Maybe redraws the screen
putchar:
 stosb
 xchg al, bl
 stosb
 xchg al, bl
 dec rcx

 test rcx, rcx
 jnz .return
 ;; rcx is zero, which means line has ended. Start a new line.
 call scroll_if_end
 mov rcx, 80
 mov [putstr_current_line], edi

.return:
 ret
; }}}


; next_line {{{
next_line:
 shl rcx, 1
 add edi, ecx
 call scroll_if_end
 mov rcx, 80
 mov [putstr_current_line], edi

 ret
; }}}


; scroll_if_end {{{
;; scroll down if no more space left on screen
;; should only call this with rcx zero
scroll_if_end:
 cmp edi, 0xb8000 + 80 * 25 * 2 ;; screen limit
 jb .no_scroll

 call scroll_down
 sub edi, 80*2

.no_scroll:
 ret
; }}}



; scroll_down {{{
;; move all text up and free one line at the bottom
scroll_down:
 push rdi
 push rsi
 push rax
 push rcx
 ;; move 24 lines of 80 words up
 mov rdi, 0xb8000
 mov rsi, rdi
 add rsi, 80*2 ;; one line
 mov rcx, 80*24 ;; screen without one line
 rep movsw

 ;; fill bottom line with spaces
 mov ax, 0x0720
 mov rcx, 80
 rep stosw

 pop rcx
 pop rax
 pop rsi
 pop rdi
 ret
; }}}


; control char handlers {{{
no_handle: ;; nothing for now
 xor rdx, rdx
 ret

null_handle: ;; stop writing
 xor rdx, rdx
 inc rdx
 ret

backspace_handle: ;; move pointer one to the left
 dec edi
 dec edi
 inc rcx
 xor rdx, rdx
 ret

line_feed_handle: ;; move pointer to start of next line
 call next_line

 xor rdx, rdx
 ret

cr_handle: ;; move pointer to start of line
 mov edi, [putstr_current_line]
 xor rdx, rdx
 ret

shift_out_handle: ;; set default color
 mov bl, 0x07
 xor rdx, rdx
 ret

shift_in_handle: ;; set next character as color
 lodsb
 mov bl, al
 xor rdx, rdx
 ret
; }}}



section .data

special_char_handlers_64:
dq null_handle       ;; 0
times 7 dq no_handle ;; 1-7
dq backspace_handle  ;; 8
dq null_handle       ;; 9 - tab
dq line_feed_handle  ;; 10 - nl
times 2 dq no_handle ;; 11-12 - vertical tab and form feed
dq cr_handle         ;; 13 - carriage return
dq shift_out_handle  ;; 14 - shift-out - color off
dq shift_in_handle   ;; 15 - shift-in - color on
times 16 dq no_handle

