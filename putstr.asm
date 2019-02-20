; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 32]


global putstr
global putstr_current_line
global scroll_down

section .text
; putstr {{{
;; ARGS
;;    esi - string to put, 0-terminated
;; modifies
;;    eax - current symbol
;;    ebx - current colour
;;    ecx - symbols left in current line until end
;;    edx - function to call / its return code
putstr:
 mov edi, [putstr_current_line]
 xor ebx, ebx
 mov bl, 0x07
 mov ecx, 80

.putchar_loop:
 lodsb
 cmp al, 32
 jb .handle_special
 call putchar
 jmp .putchar_loop

.handle_special:
 mov edx, [special_char_handlers + eax*4]
 call edx
 ;; return code is in edx, nonzero means stop
 test edx, edx
 jz .putchar_loop

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
 dec ecx

 test ecx, ecx
 jnz .return

 ;; ecx is zero, which means line has ended. Start a new line
 ;; alright, this is different from next_line as that is called when there are
 ;; still symbols left to write, but this is only called when there are none
 ;; Proof: after this function is finished working, ecx is not zero as the
 ;; test above checks. This means that when this function finishes and as there
 ;; are no other ways to print a char, there is still space to write a char

 cmp edi, 0xb8000 + 80 * 25 * 2 ;; screen limit
 jb .no_scroll

 call scroll_down
 sub edi, 80*2

.no_scroll:
 mov ecx, 80
 mov [putstr_current_line], edi

.return:
 ret
; }}}


; control char handlers {{{
no_handle: ;; nothing for now
 xor edx, edx
 ret

null_handle: ;; stop writing
 xor edx, edx
 inc edx
 ret

backspace_handle: ;; move pointer one to the left
 dec edi
 dec edi
 xor edx, edx
 ret

line_feed_handle: ;; move pointer to start of next line
 mov al, ' '

 .start_put_space
  cmp ecx, 80
  jge .end_put_space
  call putchar
  ;; putchar does not set ecx to zero ever
  jmp .start_put_space
 .end_put_space:

 xor edx, edx
 ret

cr_handle: ;; move pointer to start of line
 mov edi, [current_line]
 xor edx, edx
 ret

shift_out_handle: ;; set default color
 mov bl, 0x07
 xor edx, edx
 ret

shift_in_handle: ;; set next character as color
 lodsb
 mov bl, al
 xor edx, edx
 ret
; }}}


; scroll_down {{{
;; move all text up and free one line at the bottom
scroll_down:
 push edi
 push esi
 push eax
 push ecx
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

 pop ecx
 pop eax
 pop esi
 pop edi
 ret
; }}}


section .data
current_position:
putstr_current_line: dd 0
current_line: dw 0

dd 0,0,0,0 ;; just in case

special_char_handlers:
dd null_handle       ;; 0
times 7 dd no_handle ;; 1-7
dd backspace_handle  ;; 8
dd null_handle       ;; 9 - tab
dd line_feed_handle  ;; 10 - nl
times 2 dd no_handle ;; 11-12 - vertical tab and form feed
dd cr_handle         ;; 13 - carriage return
dd shift_out_handle  ;; 14 - shift-out - color off
dd shift_in_handle   ;; 15 - shift-in - color on
times 16 dd no_handle
