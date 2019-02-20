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

startup_msg:
  db "Booting up...", 0
system_load_success:
  db "Loaded system memory", 0
a20_error_string:
  db "Error calling bios a20 enable",0

gdt_descriptor:
  dw plain_gdt.size
  dd plain_gdt


%define system_start 0x7e00
%ifndef system_sectors
  %define system_sectors 1
%endif

;; ----- GDT Section ----- ;;

%include "gdt.asmh"

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

;; print success message
mov si, startup_msg
call putstr

;; ----- Read system sectors ----- ;;

;; this syscall uses es for loading destination
xor ax, ax
mov es, ax
mov bx, system_start ;; load to system start address
xor cx, cx
mov cl, 2 ;; cylinder 0, sector 1
mov al, system_sectors ;; the correct amount of sectors
xor dh, dh ;; head 0
mov dl, 0x80 ;; first disk drive

mov ah, 2
int 0x13 ;; execute sector loading

;; restore es pointing to video memory
mov ax, 0xb800
mov es, ax

;; ----- Put success message ----- ;;

mov si, system_load_success
call putstr

;; ----- Enable A20 line ----- ;;

mov ax, 0x2401
int 0x15
jc a20_error

;; ----- Enter protected mode ----- ;;

;; save current screen offset
mov cx, [current_line]
;; perform entering
cli
lgdt [gdt_descriptor]
mov eax, cr0
or al, 1
mov cr0, eax

jmp 0x8:system_start

;; protected mode comes after this


loop_mark:
jmp loop_mark

a20_error:
mov si, a20_error_string
call putstr
jmp loop_mark


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
