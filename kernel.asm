; vim: ft=nasm ts=2 sw=2 expandtab
[BITS 32]

system_start: ;; 0x7e00
mov ax, 0x10 ;; data segment
mov ds, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov es, ax
;; restore current screen offset
mov [putstr_current_line], cx

jmp real_start

section .data
protected_entered_msg:
  db "Succesfully entered protected mode", 10, 0
special_char_test:
  db "I'm usig", 8, "ng special characters!", 10, "on new line too!", 10
  db 15, 0x26, "in color now,", 14, " without color now", 10, 0


section .text
;; ----- Real start ----- ;;
real_start:
mov esi, protected_entered_msg
call putstr
mov esi, protected_entered_msg
call putstr
mov esi, special_char_test
call putstr


hang_machine:
 jmp hang_machine

extern putstr
extern putstr_current_line
extern scroll_down
