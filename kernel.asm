; vim: ft=nasm ts=2 sw=2 expandtab
[BITS 32]
[ORG 0x7e00]

system_start: ;; 0x7e00
mov ax, 0x10 ;; data segment
mov ds, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov es, ax
;; restore current screen offset
mov [current_line], cx

jmp real_start

;; ----- DATA SECTION ----- ;;

protected_entered_msg:
  db "Succesfully entered protected mode", 0

;; ----- Functions ----- ;;

; putstr {{{
;; ARGS
;;    esi - string to put, 0-terminated
;;  modifies edi, esi, eax, ecx
current_line: dw 0
putstr:
 mov edi, 0xb8000
 ;; load current line offset in symbol pairs to cx
 xor ecx, ecx
 mov cx, [current_line]
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
  mov [current_line], cx
  cmp cx, 25*80*2
  jb .exit
  ;; was too big, put zero there
  xor cx, cx
  mov [current_line], cx

 .exit:
 ret
; }}}

;; ----- Real start ----- ;;
real_start:
mov esi, protected_entered_msg
call putstr


hang_machine:
 jmp hang_machine
