; vim: ft=nasm ts=2 sw=2 expandtab

;; stuffs relating to multitasking, like process data structures, timer
;; bahaviours, and sleep routines

global pit_handler
global add_counter

%include "headers/putstr.asmh"


; pit_handler {{{
;; MODIFIES rsi, rdi
pit_handler:

;; decrement all counters
 mov rsi, pit_counters
 .loop:
    cmp qword [rsi + pit_counter.count], qword 0
    je .notify

    dec qword [rsi + pit_counter.count]
    jmp .next

    .notify:
      mov rdi, [rsi + pit_counter.addr]
      test rdi, rdi
      jz .next
      mov byte [rdi], byte 0
      mov qword [rsi + pit_counter.addr], qword 0

    .next:
    add rsi, pit_counter.size
    cmp rsi, pit_counters.end
    jb .loop


  ;; print a message eaxh 32 ticks of counter
  section .data
    .own_counter: dw 0
  section .text
  mov si, [.own_counter]
  test si, si
  jz .counted_to_zero
    ;; if counter flag is nonzero, do nothing
    jmp .ret
  .counted_to_zero:
    SAFE_PUTS "pit handler's own 32 tick timeout"
    mov byte [.own_counter], byte 0xff
    ;; start new countdown
    push r9
    push r10
    push rax
    push rdi

    mov r9, 32
    mov r10, .own_counter
    call add_counter

    pop rdi
    pop rax
    pop r10
    pop r9

  .ret:
  ret
; }}}


; add_counter {{{
;; ARGS
;;    r9 - amount of ticks
;;    r10 - pointer to byte to overwrite with zero on end
;; MODIFIES rax, rdi
;; RETURNS rax = 0 on success, other value for error
add_counter:
  pushfq
  cli

  mov rdi, pit_counters
  .loop:
    mov rax, [rdi + pit_counter.addr]
    test rax, rax
    jz .add
      add rdi, pit_counter.size
      cmp rdi, pit_counters.end
      jb .loop
      ;; no more counters left, can't add
      ;; and rax already contains nonzero value
      popfq
      ret
  .add:
  mov [rdi + pit_counter.count], r9
  mov [rdi + pit_counter.addr], r10

  xor rax, rax
  popfq
  ret
; }}}


section .data

struc pit_counter
  .count: resq 1
  .addr:  resq 1
  .size:
endstruc

pit_counters:
%rep 16
  istruc pit_counter
    at pit_counter.count, dq 0
    at pit_counter.addr,  dq 0
  iend
%endrep
 .end:
