; vim: ft=nasm ts=2 sw=2 expandtab

[BITS 32]

global set_paging
global pml4


;; ----- data sections ----- ;;

;; these sections are used to store paging tables. They are aligned by 4kb by
;; linker. The three tables: pml4, pdpt and pd - have only one entry present,
;; and they point at the next table. The last one, pt, maps all 4kb pages as
;; present. I use 32Mb of memory, and it gives me only 2Mb, but that should be
;; ok

section .pml4
pml4: resq 1

section .pdpt_0
pdpt: resq 1

section .pd_0
pd: resq 1

section .pt_0
pt: resq 1


section .text

;; ----- table initialization ----- ;;

set_paging:

;; zero out all the sections, which should be at least a kb long

xor eax, eax
mov edi, 1024

mov edi, pml4
mov ecx, edi
rep stosd
mov edi, pdpt
mov ecx, edi
rep stosd
mov edi, pd
mov ecx, edi
rep stosd
mov edi, pt
mov ecx, edi
rep stosd


;; set the first entry of pml4 to pdpt_0
mov eax, pdpt
or eax, 11b ;; flags: present | write
mov [pml4], eax

;; set the first entry of pdpt_0 to pd_0
mov eax, pd
or eax, 11b ;; flags: present | write
mov [pdpt], eax

;; set the first entry of pd_0 to pt_0
mov eax, pt
or eax, 11b ;; flags: present | write
mov [pd], eax


;; set all page table entries to indentity mapping

mov edi, pt
mov eax, 11b ;; set flags, and only increment page offset

.set_entry_loop:
 mov [edi], eax
 add eax, 0x1000
 add edi, 8
 cmp eax, 1024*1024*32 ;; 32 MiB
 jb .set_entry_loop


;; ---- Paging done ----- ;;

ret
