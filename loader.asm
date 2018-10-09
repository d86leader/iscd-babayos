; vim: set ft=nasm ts=2 sw=2 expandtab
[BITS 16]

org 0x7c00

;; reset segment registers
mov ax, 0x0
mov ds, ax
mov fs, ax
mov gs, ax
mov ss, ax
;; es will point to screen
mov ax, 0xb800
mov es, ax
jmp 0x0:start

;; ----- DATA SECTION ----- ;;

message:
  db "trying to read sector...", 0
success:
  db "all sectors read", 0
a20_error_string:
  db "error calling bios a20 enable",0

;; ----- START ----- ;;

start:

;; ----- Fill screen with spaces ----- ;;

;; es:di points to screen memory start
mov di, 0x0
;; load space to ax
mov ax, 0x0720

;; char printing loop
spaces:
 stosw
 cmp di, 80*25*2
 jb spaces

;; ----- Put greeting ----- ;;
mov si, message
call putstr

;; ----- Read next sector ----- ;;

;; load_sector uses es for loading destination
xor ax, ax
mov es, ax
mov di, 0x7c00 + 512
xor cx, cx
mov cl, 2
mov al, 2
call load_sector ;; load sectors 2-3
;; restore es pointing to video memory
mov ax, 0xb800
mov es, ax

;; print the string in loaded segment
mov si, 0x7c00 + 512
call putstr
mov si, 0x7c00 + 1024
call putstr

;; ----- Put success message ----- ;;
mov si, success
call putstr

;; ----- enable A20 line ----- ;;

mov ax, 0x2401
int 0x15
jc a20_error



loop_mark:
jmp loop_mark

a20_error:
mov si, a20_error_string
call putstr
jmp loop_mark

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
