; vim: ft=nasm ts=2 sw=2 expandtab

;; stuffs relating to multitasking, like process data structures, timer
;; bahaviours, and sleep routines

global pit_handler
global add_counter

%include "headers/putstr.asmh"
%include "headers/interrupts.asmh"


; pit_handler {{{
;; MODIFIES rsi, rdi
pit_handler:
 push rsi
 push rdi

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


  ;; print a message each 32 ticks of counter
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

    mov r8, 32
    mov r9, .own_counter
    call add_counter

    pop rax
    pop r10
    pop r9

    jmp .leave_thread

  .ret:
  pop rdi
  pop rsi
  ret

  .leave_thread:
  pop rdi
  pop rsi
  add rsp, 8 ;; account for own return address
  pushfq
  cli
  push rax
  end_of_interrupt 0
  jmp leave_thread_from_pit
; }}}


; add_counter {{{
;; ARGS
;;    r8 - amount of ticks
;;    r9 - pointer to byte to overwrite with zero on end
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
  mov [rdi + pit_counter.count], r8
  mov [rdi + pit_counter.addr], r9

  xor rax, rax
  popfq
  ret
; }}}


; leave_thread {{{
leave_thread:
  pushfq
  cli
  push rax
leave_thread_from_pit:
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  push rbp
  push r8
  push r9
  push r10
  push r11
  push r12
  push r13
  push r14
  push r15

  mov rax, [current_pid]
  call find_proc_struc

  mov ax, ss
  mov [rdi + process_info.ss], ax
  mov [rdi + process_info.sp], rsp

  jmp thread_switcher
; }}}


; enter_thread {{{
;; ARGS:
;;    rax - pid to enter
enter_thread:
  call find_proc_struc

  mov ax, [rdi + process_info.ss],
  mov ax, ss
  mov rsp, [rdi + process_info.sp]

  pop r15
  pop r14
  pop r13
  pop r12
  pop r11
  pop r10
  pop r9
  pop r8
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  popfq
  iretq
; }}}


; thread_switcher {{{
thread_switcher:
  xor rax, rax
  mov [current_pid], rax
  jmp enter_thread
; }}}


; find_struc {{{
;; ARGS:
;;    rax - pid
;; RETURNS:
;;    rdi - pointer to structure
find_proc_struc:
  mov rdi, processes
  .loop:
    cmp [rdi], rax
    je .ret
    add rdi, process_info.size
    jmp .loop
  .ret:
  ret
; }}}


section .data

; pit_counter {{{
struc pit_counter
  .count: resq 1
  .addr:  resq 1
  .size:
endstruc
; }}}

; pit_counters {{{
pit_counters:
%rep 16
  istruc pit_counter
    at pit_counter.count, dq 0
    at pit_counter.addr,  dq 0
  iend
%endrep
 .end:
 ; }}}


; proc_struc {{{
struc process_info
  .id: resq 1
  .ss: resw 1
  .sp: resq 1
  .stack_page: resq 1
  .size:
endstruc
; }}}


; processes {{{
current_pid: dq 0
processes:
%rep 16
  resq process_info.size
%endrep
; }}}
