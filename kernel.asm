; vim: ft=nasm ts=2 sw=2 expandtab
[BITS 32]

%include "headers/fail.asmh"
%include "headers/putstr.asmh"
%include "headers/interrupts.asmh"
%include "headers/pages.asmh"
%include "headers/alloc_page.asmh"

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
jmp hang_machine_32

A20_set:


;; ----- Test if long mode supported ----- ;;

mov eax, 0x80000000
cpuid
cmp eax, 0x80000001
jb hang_machine_32

PUTS "Extended functions are availible"

mov eax, 0x80000001
cpuid
test edx, 1 << 29
jz hang_machine_32

PUTS "Long mode is availible"


;; ----- Entering long mode ----- ;;

call set_paging

mov eax, 10100000b ;; PAE and PGE bits
mov cr4, eax
mov eax, ebx       ;; pointer to pml4
mov cr3, eax

mov ecx, 0xC0000080
rdmsr
or eax, (1 << 8) ;; long mode enable
wrmsr

mov eax, cr0
or eax, (1 << 31) ;; protection and paging bits
mov cr0, eax

PUTS "Entered long mode (32-bit)"

;; set long mode gdt
call set_gdt
lgdt [gdt_descriptor]
jmp 0x8:long_mode_start

hang_machine_32:
 jmp hang_machine_32

[BITS 64]
long_mode_start:
mov ax, 0x10
mov ds, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov es, ax

PUTS "Succesfully entered 64-bit long mode"


;; -- Load interrupt routines to idt -- ;;

mov rcx, 64
handler_set_loop:
  mov rsi, all_int_handler
  mov rdi, rcx
  call set_int_handler
  loop handler_set_loop

mov rsi, some_special_handler
mov rdi, 50
call set_int_handler

lidt [idt_descriptor]
PUTS "Succesfully loaded idtd"

;; Test if interrupts work

int 50
cmp rax, 1488
jne hang_machine
int 49
cmp rax, 228
jne hang_machine

PUTS "Interrupts executed successfully"

;; Test compile-time page allocation

alloc_test:
alloc_page rax
alloc_page rax


hang_machine:
 jmp hang_machine


;; -- Test interrupt handlers -- ;;

all_int_handler:
  mov rax, 228
  iretq
some_special_handler:
 mov rax, 1488
 iretq
