; vim: ft=nasm ts=2 sw=2 expandtab
[BITS 16]
[ORG 0x500]

;; ----- GDT Section ----- ;;

gdt_descriptor:
  dw plain_gdt.size
  dd plain_gdt

functions:
  dd exit        ;; +0
  dd putstr      ;; +4
  dd load_sector ;; +8

; struc gdt_entry {{{
struc gdt_entry
  .limit16: resw 1
  .base16:  resw 1
  .base24:  resb 1
  .access:  resb 1
  .limit20_flags: resb 1
  .base32:  resb 1
  .size:
endstruc
; }}}

; plain_gdt {{{
plain_gdt:
.size equ .end - $ - 1
;; zero entry
istruc gdt_entry
  at gdt_entry.limit16, dw 0
  at gdt_entry.base16,  dw 0
  at gdt_entry.base24,  db 0
  at gdt_entry.access,  db 0
  at gdt_entry.limit20_flags, db 0
  at gdt_entry.base32,  db 0
iend
;; code sector, 0x8
istruc gdt_entry
  at gdt_entry.limit16, dw 0xffff
  at gdt_entry.base16,  dw 0
  at gdt_entry.base24,  db 0
  at gdt_entry.access,  db 10011010b
  at gdt_entry.limit20_flags, db (1100b << 4) | 0xff
  at gdt_entry.base32,  db 0
iend
;; data sector, 0x10
istruc gdt_entry
  at gdt_entry.limit16, dw 0xffff
  at gdt_entry.base16,  dw 0
  at gdt_entry.base24,  db 0
  at gdt_entry.access,  db 10010010b
  at gdt_entry.limit20_flags, db (1100b << 4) | 0xff
  at gdt_entry.base32,  db 0
iend
.end:
; }}}


;; ----- Functions ----- ;;

; exit {{{
exit:
  xor al, al
  out 0xf4, al
; }}}

; putstr {{{
;; ARGS
;;    ds:si - string to put, 0-terminated
;;  NO regs preserved
current_line: dw 0
putstr:
 ;; assuming es points to video memory
 ;; load current line address to di
 mov di, [current_line]

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
 mov ax, [current_line]
 add ax, 80*2
 mov [current_line], ax
 cmp ax, 25*80*2
 jb .exit
 ;; was too big, put zero there
 xor ax, ax
 mov [current_line], ax

 .exit:
 ret
; }}}

; load_sector {{{
;; ARGS:
;;    es:di - destination
;;    cx - cylinder:sector (ch:cl)
;;    al - amount of sectors to load
load_sector:
  ;; from:
  xor dh, dh ;; head 0
  mov dl, 0x80 ;; first disk drive
  ;; to:
  mov bx, di ;; just after this code
  ;; perform
  mov ah, 2
  int 0x13

  ret
; }}}
