; vim: ft=nasm ts=2 sw=2 expandtab

%include "headers/fail.asmh"
%include "headers/putstr.asmh"
%include "headers/interrupts.asmh"
%include "headers/pages.asmh"
%include "headers/runtime_memory.asmh"
%include "headers/devices.asmh"
%include "headers/keyboard.asmh"
%include "headers/multitask.asmh"


[BITS 32]


;; ----- Initialization after real mode ----- ;;


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


;; -- Test if long mode supported -- ;;

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

mov ebp, esp
_constexpr_alloc_page ebx
push ebx ;; pml4
_constexpr_alloc_page eax
push eax ;; pdpt_0
_constexpr_alloc_page eax
push eax ;; pd_0
_constexpr_alloc_page eax
push eax ;; pt_0

call set_paging
paging_set:
pop ecx
pop ecx ;; get pointer to pd_0
mov esp, ebp

;; save the first unmapped address
and eax, 0xfffffff0
push dword 0
push eax

;; allocate a new page for stack page descriptors
_constexpr_alloc_page eax
push dword 0
push eax

;; save pointer to pd_0
push dword 0
push ecx


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


;; ----- Inititalization after short mode ----- ;;


long_mode_start:
mov ax, 0x10
mov ds, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov es, ax

PUTS "Succesfully entered 64-bit long mode"

pop r8 ;; pointer to pd_0
pop r9 ;; pointer to new page
pop r10 ;; pointer to first unmapped memory

push r10
push r10
mov rbp, rsp
PUTS "Mapped d (0xx) bytes of memory for kernel"
add rsp, 16

call set_stack_pages
mov rsp, rax
PUTS "Switched to a new stack"

mov r8, r10
call setup_init


;; Load interrupt routines to idt

call setup_handlers
lidt [idt_descriptor]
PUTS "Succesfully loaded idtd"

;; PIC initialization

;; irqs start at 0x20 = 32
mov rsi, 32
;; ignore all interrupts
mov r9, 0xff
mov r10, 0xff
call initialize_pic
;; enable maskable interrupts
sti

PUTS "PIC set up successfully"

;; once a second
mov r8, 0xffff
call initialize_pit

;; enable timer interrupts
pic_unmask 0

;; enable keyboard interrupts
call initialize_ps2
PUTS "Keyaboard set up successfully"
pic_unmask 1




hang_machine:
 hlt
 jmp hang_machine
