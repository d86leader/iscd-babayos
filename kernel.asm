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
add ecx, 0xb8000
mov [putstr_current_line], ecx

jmp real_start

section .data
protected_entered_msg:
  db "Succesfully entered protected mode", 0
special_char_test:
  db "I'm usig", 8, "ng special characters!", 10, "on new line too!"
  db 15, 0x26, "in color now,", 14, " without color now", 0
scroll_down_test:
  times 18 db 10
  db 0


section .text
;; ----- Real start ----- ;;
real_start:
mov esi, scroll_down_test
call putstr
mov esi, protected_entered_msg
call putstr
mov esi, special_char_test
call putstr
mov esi, protected_entered_msg
call putstr


hang_machine:
 jmp hang_machine

extern putstr
extern putstr_current_line
extern scroll_down
