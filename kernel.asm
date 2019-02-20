; vim: ft=nasm ts=2 sw=2 expandtab
[BITS 32]

%include "fail.asmh"
%include "putstr.asmh"
%include "interrupts.asmh"

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


;; ----- Real start ----- ;;


real_start:
PUTS "Succesfully entered protected mode"


;; -- Test if A20 line is enabled -- ;;

mov edi, 0x112345
mov esi, 0x012345
mov [esi], esi
mov [edi], edi
cmpsd
jne A20_set
PUTS "A20 line was not set. Stopping"
jmp hang_machine

A20_set:


;; ----- Test if long mode supported ----- ;;

mov eax, 0x80000000
cpuid
cmp eax, 0x80000001
jb hang_machine

PUTS "Extended functions are availible"

mov eax, 0x80000001
cpuid
test edx, 1 << 29
jz hang_machine

PUTS "Long mode is availible"


;; ----- Entering long mode ----- ;;

extern set_paging
extern pml4
call set_paging

mov eax, 10100000b ;; PAE and PGE bits
mov cr4, eax
mov eax, pml4
mov cr3, eax

mov ecx, 0xC0000080
rdmsr
or eax, (1 << 8) ;; long mode enable
wrmsr

mov eax, cr0
or eax, (1 << 31) ;; protection and paging bits
mov cr0, eax

PUTS "Entered long mode (32-bit)"

jmp hang_machine

;; -- Load interrupt routines to idt -- ;;

mov ecx, 64
handler_set_loop:
  mov esi, all_int_handler
  mov edi, ecx
  call set_int_handler
  loop handler_set_loop

lidt [idt_descriptor]
PUTS "Succesfully loaded idtd"

;; Test if interrupts work

int 48

cmp eax, 228
jne hang_machine
PUTS "Interrupt executed successfully"
jmp hang_machine


hang_machine:
 jmp hang_machine
