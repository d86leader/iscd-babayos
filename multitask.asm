; vim: ft=nasm ts=2 sw=2 expandtab

;; stuffs relating to multitasking, like process data structures, timer
;; bahaviours, and sleep routines

global pit_handler
global add_counter
global setup_init

%include "headers/putstr.asmh"
%include "headers/interrupts.asmh"
%include "headers/pages.asmh"


%define max_process_amount 16


;; Set appropriate values to the process structure of init
; setup_init {{{
;; ARGS
;;    r8 - stack page address
setup_init:
  ;; add init to queue
  mov qword [pid_queue], qword 1

  ;; add process structure
  mov qword [processes + process_info.id], qword 1
  mov [processes + process_info.stack_page], r8

  ret
; }}}


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
  call proc_struc_find

  mov ax, ss
  mov [rdi + process_info.ss], ax
  mov [rdi + process_info.sp], rsp

  jmp thread_switcher
; }}}


; enter_thread {{{
;; ARGS:
;;    rax - pid to enter
enter_thread:
  call proc_struc_find

  mov ax, [rdi + process_info.ss],
  mov ss, ax
  mov rsp, [rdi + process_info.sp]

  mov r8, [rdi + process_info.stack_page]
  mov rax, .finalize
  jmp change_stack_page

 .finalize:

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
;; round-robin thread switcher
thread_switcher:
  call pid_queue_get_next
;  xor rax, rax
;  inc rax
  mov [current_pid], rax
  jmp enter_thread
; }}}


; ll_fork {{{
ll_fork:
  pushfq
  cli
; }}}


; proc_struc_find {{{
;; ARGS:
;;    rax - pid
;; RETURNS:
;;    rdi - pointer to structure
proc_struc_find:
  mov rdi, processes
  .loop:
    cmp [rdi], rax
    je .ret
    add rdi, process_info.size
    jmp .loop
  .ret:
  ret
; }}}


; proc_struc_add {{{
;; ARGS:
;;    r8 - pid
;;    r9 - stack page
;; MODIFIES rdi, rax
proc_struc_add:
  mov rdi, [processes] ;; we know that anything before is already filled

  .loop:
    add rdi, process_info.size
    mov rax, [rdi]
    test rax, rax
    jnz .loop
    ;; no bound check because ehhhh

  mov [rdi + process_info.id], r8
  mov [rdi + process_info.stack_page], r9
  ret
; }}}


; proc_struc_remove {{{
;; ARGS:
;;    r8 - pid
;; MODIFIES rax, rdi, rsi
proc_struc_remove:
  mov rax, r8
  call proc_struc_find

  mov rsi, rdi
  add rsi, process_info.size
  .loop:
    mov rcx, process_info.size
    rep movsb

    mov rax, [rdi + process_info.id] ;; which is id of newly copied struct
    test rax, rax
    jnz .loop

  ret
; }}}


; pid_queue_get_next {{{
;; FUNCTION
;; MODIFIES rax
;; RETURNS: rax - nex pid in queue
pid_queue_get_next:
  push rsi
  mov rsi, [pid_queue_position]
  add rsi, 8
  mov rax, [rsi]
  test rax, rax
  jnz .ret
    ;; go to start of queue
    mov rsi, pid_queue
    mov rax, [rsi]

  .ret:
  mov [pid_queue_position], rsi
  pop rsi
  ret
; }}}


; pid_queue_add {{{
;; ARGS:
;;    r8 - pid to add
;; MODIFIES rdi, rax
pid_queue_add:
  mov rdi, [pid_queue_position] ;; we know that anything before is already filled

  .loop:
    add rdi, 8
    mov rax, [rdi]
    test rax, rax
    jnz .loop
    ;; no bound check because ehhhh

  mov [rdi], r8
  ret
; }}}


; pid_queue_remove {{{
;; ARGS:
;;    r8 - pid to remove
;; MODIFIES rsi, rdi, rcx
pid_queue_remove:
  mov rdi, [pid_queue]
  sub rdi, 8 ;; for more pretty loop
  mov rcx, max_process_amount + 1 ;; same

  .loop:
    add rdi, 8
    dec rcx
    cmp [rdi], r8
    jne .loop
    ;; again no bounds check. As everywhere here

  mov rsi, rdi
  add rsi, 8
  rep movsq ;; easy to prove correctness when you take proc_amount = 2

  ret
; }}}


proc_struc_


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
%rep max_process_amount
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
current_pid: dq 1

processes:
;; reserve space for other processes
%rep max_process_amount
  %rep process_info.size
    db 0
  %endrep
%endrep

pid_queue:
           %rep max_process_amount
            dq 0
           %endrep
           dq 0
.end:
pid_queue_position: dq pid_queue
; }}}
