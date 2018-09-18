; vim: set ft=nasm ts=2 sw=2 expandtab
[BITS 16]

org 0x7c00

;; reset segment registers
mov ax, 0x0
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax
jmp 0x0:start

start:

;; set es to be video memory segment
mov ax, 0xb800
mov es, ax
mov di, 0x0

;;;;;; STRING MACRO SECTION ;;;;;
%macro putwhitechar 1
  mov [es:di], word ((0x07 << 8) + %1)
  inc di
  inc di
%endmacro
%macro putwhitestring 1-*
  %rep %0
    putwhitechar %1
    %rotate 1
  %endrep
%endmacro
;;;;;; END STRING MACRO SECTION ;;;;;

fill_screen:
putwhitestring "H", "e", "l", "l", "o", ",", " ", "w", "o", "r", "l", "d"


spaces:
mov [es:di], word 0x0720 ;; <space>
inc di
inc di
cmp di, 80*25*2
jb spaces


loop_mark:
jmp loop_mark
