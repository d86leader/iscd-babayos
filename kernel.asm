; vim: ft=nasm ts=2 sw=2 expandtab
[BITS 32]

%include "fail.asmh"

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
idt_loaded_nsg:
  db "Successfully loaded idtd", 0
int_success_msg:
  db "Interrupt execute successfully", 0
int_fail_msg:
  db "Interrupt returned but did not work", 0


section .text
;; ----- Real start ----- ;;
real_start:
mov esi, protected_entered_msg
call putstr

mov ecx, 64
handler_set_loop:
  mov esi, all_int_handler
  mov edi, ecx
  call set_int_handler
  loop handler_set_loop

lidt [idt_descriptor]

mov esi, idt_loaded_nsg
call putstr

int 48

cmp eax, 228
je good

  mov esi, [int_fail_msg]
  call putstr
  jmp hang_machine

good:
  mov esi, [int_success_msg]
  call putstr
  jmp hang_machine


hang_machine:
 jmp hang_machine

extern putstr
extern putstr_current_line
extern scroll_down
extern idt_descriptor
extern set_int_handler
extern all_int_handler
