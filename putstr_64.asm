; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 64]


global putstr_64
extern putstr_current_line

section .text
; putstr {{{
;; ARGS
;;    r8 - string to put, 0-terminated
;;    r9 - any arguments to format
;; modifies
;;    rax - current symbol
;;    rbx - current colour
;;    rcx - symbols left in current line until end
;;    rdx - function to call / its return code
;;    rsi - pointer to source string
;;    rdi - pointer to destination screen
;;    rbp - format string args
putstr_64:
 ;; disable interrupts while printing to avoid bad state
 pushfq
 cli

 mov rsi, r8
 mov rbp, r9

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

 popfq
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


; basic_put {{{
;; put a string in rsi to screen
;; modifies same as putchar
basic_put:
  lodsb
  test al, al
  jz .end
  call putchar
  jmp basic_put
.end:
  ret
; }}}


; basic_put_reverse {{{
basic_put_reverse:
  std
  lodsb
  cld
  test al, al
  jz .end
  call putchar
  jmp basic_put_reverse
.end:
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

escape_seq: ;; parse the following escape sequence
 lodsb
 cmp al, 's'
 je escape_s
 cmp al, 'd'
 je escape_d
 cmp al, 'x'
 je escape_x

 xor rdx, rdx
 ret
; }}}


; escape sequence handlers {{{

;; append string to output
; escape_s {{{
escape_s:
 push rsi
 mov rsi, [rbp]
 call basic_put
 ;; cleaning up
 add rbp, 8
 pop rsi
 xor rdx, rdx
 ret
; }}}


;; append hexadecimal number
; escape_x {{{
escape_x:
 mov rdx, [rbp]
 push rdi
 mov rdi, number_to_str_rev

.div_loop:
 xor rax, rax
 mov al, dl
 and al, 0xf
 mov al, [hex_lookup_table + rax]
 stosb
 shr rdx, 4
 test rdx, rdx
 jz .end_div
 jmp .div_loop

.end_div:
 pop rdx
 xchg rdx, rdi ;; now rdi is restored and rdx is old rdi
 push rsi
 mov rsi, rdx  ;; and now rsi is saved and equal to old rdi
 dec rsi
 call basic_put_reverse

 ;; cleaning up
 add rbp, 8
 pop rsi
 xor rdx, rdx
 ret
; }}}


; escape_d {{{
escape_d:
 mov rax, [rbp]
 push r8
 mov r8, 10
 push rdi
 mov rdi, number_to_str_rev

.div_loop:
 xor rdx, rdx
 div r8
 add rdx, '0'
 xchg rax, rdx
 stosb
 xchg rax, rdx
 test rax, rax
 jz .end_div
 jmp .div_loop

.end_div:
 pop rdx
 xchg rdx, rdi ;; now rdi is restored and rdx is old rdi
 push rsi
 mov rsi, rdx  ;; and now rsi is saved and equal to old rdi
 dec rsi
 call basic_put_reverse

 ;; cleaning up
 add rbp, 8
 pop rsi
 pop r8
 xor rdx, rdx
 ret
; }}}

; }}}



section .data

special_char_handlers_64:
dq null_handle        ;; 0
times 7 dq no_handle  ;; 1-7
dq backspace_handle   ;; 8
dq null_handle        ;; 9 - tab
dq line_feed_handle   ;; 10 - nl
times 2 dq no_handle  ;; 11-12 - vertical tab and form feed
dq cr_handle          ;; 13 - carriage return
dq shift_out_handle   ;; 14 - shift-out - color off
dq shift_in_handle    ;; 15 - shift-in - color on
times 11 dq no_handle ;; 16-26
dq escape_seq         ;; 27 - escape sequences for diffrnt stuff, esp format
times 5 dq no_handle  ;; 28-32

;; Number printing functions first create a reversed string. They put it here
db 0
number_to_str_rev:
times 20 db 0 ;; maximum required by decimal representation

hex_lookup_table:
db "0123456789ABCDEF"
