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

;; ----- DATA SECTION ----- ;;

message:
  db "trying to read sector...", 0

;; ----- START ----- ;;

start:

;; ----- Fill screen with spaces ----- ;;

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

;; char printing loop
xor cx, cx
spaces:
  mov al, 0x20
  mov ah, 0xe
  int 0x10
  inc cx
  cmp cx, 80*25 - 1
  jb spaces

;; ----- Put greeting ----- ;;
mov si, message
call putstr

jmp loop_mark

;; ----- Read next sector ----- ;;

;; read first
;; from:
xor cx, cx ;; cylinder 0, sector 0
inc cl
inc cl     ;; sector 2. Starting sector is probably one
xor dh, dh ;; head 0
mov dl, 0x80 ;; first disk drive
;; to:
;; es already set to 0
mov bx, 0x7c00 + 512 ;; just after this code
;; amount to load
mov al, 1
;; perform
mov ah, 2
int 0x13

;; print the string in loaded segment

mov si, 0x7c00 + 512
call putstr

loop_mark:
jmp loop_mark

exit:
xor al, al
out 0xf4, al


;; ARGS
;;    ds:si - string to put, 0-terminated
;;  NO regs preserved
last_cursor_pos: db -1
putstr:
;; set cursor to position:
  mov dh, [last_cursor_pos]
  inc dh
  mov [last_cursor_pos], dh
  xor bh, bh ;; page 0
  xor dl, dl ;; col 0
  mov ah, 0x2
  int 0x10

 .putchar
  lodsb
  test al, al
  jnz .exit
  mov ah, 0xe
  int 0x10
  jmp .putchar

 .exit: ret

