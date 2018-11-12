; vim: ft=nasm ts=2 sw=2 expandtab

global putstr
global putstr_current_line
global scroll_down

section .text
; putstr {{{
;; ARGS
;;    esi - string to put, 0-terminated
;;  modifies edi, esi, eax, ebx, ecx, edx

;; register meaning:
;; eax - current character
;; ebx - current line offset from screen start
;; ecx - general purpose
;; edx - current color
;; edi - current screen place
putstr:
 mov edi, 0xb8000
 ;; load current cursor position in bx
 xor ebx, ebx
 mov bx, [current_position]
 add edi, ebx
 ;; now load current line offset in bx
 mov bx, [current_line]
 ;; load default color in edx
 mov dl, 0x07
 xor eax, eax

 .putchar:
  lodsb
  cmp al, 32
  jb .handle_special
  stosb
  mov al, dl
  stosb
  jmp .putchar

 .handle_special:
  mov ecx, [special_char_handlers + eax*4]
  jmp ecx

 .string_end:
  ;; save current position
  sub edi, 0xb8000
  mov [current_position], di

 .exit:
 ret
; }}}


; inc_line {{{
inc_line:
 push edi
 sub edi, 0xb8000

 ;; find first position that is after current position
 .find_next_line:
  add bx, 80*2
  cmp bx, di
  jbe .find_next_line
 
 pop edi
 
 mov [current_line], bx
 mov [current_position], bx
 cmp bx, 25*80*2
 jb .end
 call scroll_down
 .end: ret
; }}}


; control char handlers {{{
no_handle: ;; nothing for now
 jmp putstr.putchar

null_handle: ;; stop writing
 jmp putstr.string_end

backspace_handle: ;; move pointer one to the left
 dec edi
 dec edi
 jmp putstr.putchar

line_feed_handle: ;; move pointer to next line
 call inc_line
 jmp cr_handle

cr_handle: ;; move pointer to start of line
 mov edi, 0xb8000
 add edi, ebx
 jmp putstr.putchar
 
shift_out_handle: ;; set default color
 mov dl, 0x07
 jmp putstr.putchar

shift_in_handle: ;; set next character as color
 lodsb
 mov dl, al
 jmp putstr.putchar
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

 ;; decrement current line
 mov cx, [current_line]
 sub ecx, 80*2
 mov [current_line], cx
 mov cx, [current_position]
 sub ecx, 80*2
 mov [current_position], cx

 pop ecx
 pop eax
 pop esi
 pop edi
 ret
; }}}


section .data
current_position:
putstr_current_line: dw 0
current_line: dw 0

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
