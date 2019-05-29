; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 32]

global set_paging
global set_gdt
global gdt_descriptor
global set_stack_pages
global create_stack_page
global change_stack_page

section .text

;; ----- table initialization ----- ;;

;; The three tables: pml4, pdpt and pd - have only one entry present,
;; and they point at the next table. The last one, pt, maps all 4kb pages as
;; present. I use 32Mb of memory and map all of it

; set_paging {{{
;; SUBROUTINE
;; ARGS
;;    esp - pointer to [pt_0, pd_0, pdpt_0, pml4]
;; modifies
;;    eax, ecx, edx, edi - junk in the end
set_paging:

%define pml4_ptr esp + 16
%define pdpt_ptr esp + 12
%define pd_ptr   esp + 8
%define pt_ptr   esp + 4

;; zero out all the sections

xor eax, eax
mov edx, 1024

mov edi, [pml4_ptr]
mov ecx, edx
rep stosd
mov edi, [pdpt_ptr]
mov ecx, edx
rep stosd
mov edi, [pd_ptr]
mov ecx, edx
rep stosd
mov edi, [pt_ptr]
mov ecx, edx
rep stosd


;; set the first entry of pml4 to pointer to pdpt
mov edi, [pml4_ptr]
mov eax, [pdpt_ptr]
or eax, 11b ;; flags: write | present
mov [edi], eax

;; set the first entry of pdpt to pointer to pd
mov edi, [pdpt_ptr]
mov eax, [pd_ptr]
or eax, 11b ;; flags: present | write
mov [edi], eax

;; set the first entry of pd_0 to pt_0
mov edi, [pd_ptr]
mov eax, [pt_ptr]
or eax, 11b ;; flags: present | write
mov [edi], eax


;; set all page table entries to indentity mapping

mov edi, [pt_ptr]
mov ecx, edi
add ecx, 0x1000 ;; limit for one page
mov eax, 11b ;; set flags, and only increment page offset

.set_entry_loop:
 mov [edi], eax
 add eax, 0x1000
 add edi, 8
 cmp edi, ecx
 jge .end
 cmp eax, 1024*1024*32 ;; 32 MiB
 jge .end
 jmp .set_entry_loop


;; Paging done

.end:
ret
; }}}


;; ----- Set long mode gdt ----- ;;

;; gdt descriptor obtained from existing gdt
section .data
gdt_descriptor:
resw 1
resd 1

%include "headers/gdt.asmh"

section .text
; set_gdt {{{
;; MODIFIES edi, eax
set_gdt:


;; obtain place of current loaded gdt

sgdt [gdt_descriptor]
mov edi, [gdt_descriptor + 2]


;; set existing gdt long and 32 bit flags to 1

add edi, 8
mov al, [edi + 6]
or  al, 00100000b
and al, 10111111b
mov [edi+6], al

add edi, 8

mov al, [edi + 6]
or  al, 00100000b
and al, 10111111b
mov [edi+6], al

;; gdt modified, return
ret
; }}}


;; ----- Setup pages for multitasking stack ----- ;;
[BITS 64]


section .data
stack_page_table: dq 0
last_page_addr: dq 0
stack_space_addr: dq 0

section .text

; set_stack_pages {{{
;; ARGS
;;    r8 - pointer to page directory
;;    r9 - pointer to empty page table
;;    r10 - pointer to an unmapped region
;; MODIFIES: rdi, rax
;; RETURNS rax - a place to put the stack tip onto
set_stack_pages:
  mov [stack_page_table], r9
  mov [last_page_addr], r10
  mov [stack_space_addr], r10

  ;; zero out an empty page table
  xor rax, rax
  mov rdi, r9
  mov ecx, (4096 / 8)
  rep stosq

  ;; put a mapping to the region into table
  mov rax, r10
  or rax, 11b ;; present | write
  mov [r9], rax

  ;; put a mapping to table into directory
  mov rax, r9
  mov rdi, r8
  add rdi, 8
  or rax, 11b ;; present | write
  mov [rdi], rax

  ;; FIXME remove this
  add rdi, 8
  mov qword [0x4010], qword 0x200003
  add rdi, 8
  mov qword [0x4018], qword 0x201003
  ;; now i can watch both stacks from debugger
  ;; at 0x202000 and 0x203000

  mov rax, r10
  add rax, (4096 - 8)

  ret
; }}}


;; create a copy of current page
; create_stack_page {{{
;; ARGS none
;; MODIFIES: rax, rcx, rsi, rdi
;; RETURNS
;;    rax - address of new page
create_stack_page:
  ;; allocate a page
  mov rsi, [last_page_addr]
  add rsi, 4096
  mov [last_page_addr], rsi
  mov rax, rsi ;; save addr to return
  ;; and create a mapping for it
  or rsi, 11b ;; present | write
  mov rdi, [stack_page_table]
  add rdi, 8
  mov [rdi], rsi

  ;; copy current page to newly mapped one
  mov rsi, [stack_space_addr]
  mov rdi, rsi
  add rdi, 4096
  mov rcx, (4096 / 8)
  rep movsq

  ;; clear the mapping
  xor rsi, rsi
  mov rdi, [stack_page_table]
  add rdi, 8
  mov [rdi], rsi

  ret
; }}}


; change_stack_page {{{
;; ARGS
;;    r8 - what address to put
;;    rax - where to return
;; MODIFIES: rdi, r8
change_stack_page:
  mov rdi, [stack_page_table]
  or r8, 11b ;; write | present
  mov [rdi], r8
  jmp rax
; }}}
