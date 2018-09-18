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

;; DATA SECTION

message:
  db "hello BIOS world", 0

;; START

start:
;; select active page
xor al, al ;; page 0
mov ah, 0x5
int 0x10

;; set cursor to position:
xor bh, bh ;; page 0
xor dh, dh ;; row 0
xor dl, dl ;; col 0
mov ah, 0x2
int 0x10


;; load pointer to source text
mov si, message
;; reset symbol counter
xor cx, cx

print_char:
;; load char, quit if zero
lodsb
test al, al
jz spaces

mov ah, 0xe ;; print char
int 0x10

inc cx
jmp print_char


spaces:
mov al, 0x20
mov ah, 0xe
int 0x10
inc cx
cmp cx, 80*25 - 1
jb spaces


loop_mark:
jmp loop_mark
