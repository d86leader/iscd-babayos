; vim: ft=nasm ts=2 sw=2 expandtab
[BITS 16]
[ORG 0x7c00]

;; reset segment registers
mov ax, 0x0
mov ds, ax
mov fs, ax
mov gs, ax
mov ss, ax
;; es points to video memory
mov ax, 0xb800
mov es, ax
;; sp will point to end of chunk of convetional memory
mov sp, 0x00007BF0
;; initialize cs register
jmp 0x0:start

;; ----- DATA SECTION ----- ;;

util_load_success:
  db "loaded first sector..", 0
system_load_success:
  db "loaded system memory", 0
a20_error_string:
  db "error calling bios a20 enable",0

%define gdt_descriptor 0x500

%define functions gdt_descriptor + 6
%define load_sector_ptr functions + 8
%define putstr_ptr      functions + 4
%define exit_ptr        functions + 0

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

;; ----- Read sector with functions ----- ;;

;; this syscall uses es for loading destination
xor ax, ax
mov es, ax
mov bx, gdt_descriptor ;; load to gdt_descriptor address
xor cx, cx
mov cl, 2 ;; cylinder 0, sector 2
mov al, 1 ;; 1 sector
xor dh, dh ;; head 0
mov dl, 0x80 ;; first disk drive

mov ah, 2
int 0x13 ;; execute sector loading

;; restore es pointing to video memory
mov ax, 0xb800
mov es, ax

;; print success message
mov si, util_load_success
mov ax, [putstr_ptr]
call ax

;; ----- Read system sectors ----- ;;

jmp loop_mark

;; ----- Put success message ----- ;;

mov si, system_load_success
call putstr

;; ----- Enable A20 line ----- ;;

mov ax, 0x2401
int 0x15
jc a20_error

;; ----- Enter protected mode ----- ;;

cli
lgdt [gdt_descriptor]
mov eax, cr0
or al, 1
mov cr0, eax

jmp 0x8:0x7e00

;; protected mode comes after this


loop_mark:
jmp loop_mark

a20_error:
mov si, a20_error_string
call putstr
jmp loop_mark

; putstr {{{
;; ARGS
;;    ds:si - string to put, 0-terminated
;;  NO regs preserved
current_line: dw 0
putstr:
  mov ax, [putstr_ptr]
  call ax
  ret
; }}}

; load_sector {{{
;; ARGS:
;;    es:di - destination
;;    cx - cylinder:sector (ch:cl)
;;    al - amount of sectors to load
load_sector:
  mov bx, [load_sector_ptr]
  call bx
  ret
; }}}
