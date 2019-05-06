; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 32]

global set_paging
global set_gdt
global gdt_descriptor

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
