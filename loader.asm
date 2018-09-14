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

fill_screen:
mov [es:di], word 0x0748 ;; H
inc di
inc di
mov [es:di], word 0x0765 ;; e
inc di
inc di
mov [es:di], word 0x076c ;; l
inc di
inc di
mov [es:di], word 0x076c ;; l
inc di
inc di
mov [es:di], word 0x076f ;; o
inc di
inc di
mov [es:di], word 0x0720 ;; <space>
inc di
inc di
mov [es:di], word 0x0777 ;; w
inc di
inc di
mov [es:di], word 0x076f ;; o
inc di
inc di
mov [es:di], word 0x0772 ;; r
inc di
inc di
mov [es:di], word 0x076c ;; l
inc di
inc di
mov [es:di], word 0x0764 ;; d
inc di
inc di

spaces:
mov [es:di], word 0x0720 ;; <space>
inc di
inc di
cmp di, 80*20
jb spaces


loop_mark:
jmp loop_mark
