; vim: ft=nasm ts=2 sw=2 expandtab

;; stuffs relating to multitasking, like process data structures, timer
;; bahaviours, and sleep routines

global pit_handler
global add_counter
global setup_init
global ll_fork_handler
global ll_kill

%include "headers/putstr.asmh"
%include "headers/interrupts.asmh"
%include "headers/pages.asmh"
%include "headers/fail.asmh"


%define max_process_amount 16


;; Set appropriate values to the process structure of init
; setup_init {{{
;; ARGS
;;    r8 - stack page address
setup_init:
  ;; add init to queue
  mov qword [pid_queue], qword 1
  add qword [last_queue_pos], qword 8

  ;; add process structure
  mov qword [processes + process_info.id], qword 1
  mov [processes + process_info.stack_page], r8
  add qword [last_proc_pos], qword process_info.size

  ;; make 1 the current and latest pid
  mov qword [current_pid], qword 1
  mov qword [last_pid], qword 1

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
  jnz .counter_not_zero ;; if counter flag is nonzero, do nothing
    ;; when counted to zero:
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
  .counter_not_zero:

  ;; leave current thread

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

  mov r8, [current_pid]
  call proc_struc_find

  mov rdi, rax
  mov ax, ss
  mov [rdi + process_info.ss], ax
  mov [rdi + process_info.sp], rsp

  jmp thread_switcher
; }}}


; enter_thread {{{
;; ARGS:
;;    r8 - pid to enter
enter_thread:
  call proc_struc_find

  mov rdi, rax
  mov ax, [rdi + process_info.ss],
  mov ss, ax
  mov rsp, [rdi + process_info.sp]

;  mov r8, [rdi + process_info.stack_page]
;  mov rax, .finalize
;  jmp change_stack_page

 .finalize:

  ;; possibly a bug?
  ;; display/x *(long*)($rsp + 0x2000)
  ;; display/x *(long*)($rsp + 0x3000)
  ;; display/x *(long*)$rsp
  ;; b *0x8693
  ;; b *0x8698
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
  mov [current_pid], rax
  mov r8, rax
  jmp enter_thread
; }}}


; ll_fork_handler {{{
;; this function is jumped into when an interrupt occurs
;; MODIFIES: r15
;; RETURNS r15 - 0 or new pid
ll_fork_handler:
  ;; the new process created should have such a stack layout that enter_thread
  ;; would work correctly. That means we have to enter via interrupt and push
  ;; all registers
  pushfq
  cli
  push rax
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
  ;; don't push r15 yet

  mov r8, [last_pid]
  inc r8
  mov [last_pid], r8
  call pid_queue_add
  mov r15, r8
  push r15 ;; push a new pid instead of what was in it

  ;; now test if there was error when adding
  test rax, rax
  jz .no_fork


  ;; get stack page of current proc
  mov r8, [current_pid]
  call proc_struc_find
  ;; and create a new page with it
  mov r8, [rax + process_info.stack_page]
  call create_stack_page
  mov r9, rax ;; address of new page

  call proc_struc_add
  test rax, rax
  jz .no_fork

  mov rdi, rax
  mov [rdi + process_info.id], r15 ;; new pid is still kept here
  mov [rdi + process_info.stack_page], r9
  mov ax, ss
  mov [rdi + process_info.ss], ax
  mov rax, rsp
  sub rax, r8
  add rax, r9 ;; rax now should point to stack head of the copy of page, not the original
  mov [rdi + process_info.sp], rax

  ;; also tweak the rsp that's held on stack of new process
  mov rbx, [rax + (8*15) + 8 + 32 - 8] ;; regs, flags, offset from manual, - as no errcode
  sub rbx, r8
  add rbx, r9
  mov [rax + (8*15) + 8 + 32 - 8], rbx

  add rsp, 8 ;; don't pop r15
  xor r15, r15
 .common_ret:
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

  .no_fork:
    add rsp, 8
    mov r15, -1
    jmp .common_ret
; }}}


; ll_kill {{{
ll_kill:
  mov r8, [current_pid]
  call proc_struc_remove
  call pid_queue_remove
  jmp thread_switcher
; }}}


; proc_struc_find {{{
;; ARGS:
;;    r8 - pid
;; RETURNS:
;;    rax - pointer to structure
proc_struc_find:
  mov rax, processes
  .loop:
    cmp [rax + process_info.id], r8
    je .ret

    add rax, process_info.size
    ;; bounds check
    cmp rax, [last_proc_pos]
    jl .loop

      ;; bounds check failed, struc not found
      fail_with "Failed to find a struc for pid"

  .ret:
  ret
; }}}


; proc_struc_add {{{
;; ARGS: none
;; MODIFIES rdi, rax
;; RETURNS rax - address of process struct added or zero if no space left
proc_struc_add:
  mov rdi, [last_proc_pos]
  ;; test bounds
  cmp rdi, processes.end
  jge .no_space

  mov rax, rdi ;; return value

  add rdi, process_info.size
  mov [last_proc_pos], rdi
  ret

  .no_space:
    xor rax, rax
    ret
; }}}


; proc_struc_remove {{{
;; ARGS:
;;    r8 - pid
;; MODIFIES rax, rdi, rsi
proc_struc_remove:
  mov rax, [last_proc_pos]
  cmp rax, processes
  jle .empty_list

  call proc_struc_find

  mov rdi, rax
  mov rsi, rdi
  add rsi, process_info.size
  .loop:
    mov rcx, process_info.size
    rep movsb

    mov rax, [rdi + process_info.id] ;; which is id of newly copied struct
    test rax, rax
    jnz .loop

  sub qword [last_proc_pos], qword process_info.size
  ret

  .empty_list:
    fail_with "Attempting to delete a proc struc when none exist"
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
;; RETURNS rax - 0 if error, any nonzero if ok
pid_queue_add:
  mov rdi, [last_queue_pos]
  cmp rdi, pid_queue.end
  jge .no_space

  mov [rdi], r8 ;; put pid supplied into first free space
  add rdi, 8
  mov [last_queue_pos], rdi

  xor rax, rax
  inc rax
  ret

  .no_space:
    xor rax, rax
    ret
; }}}


; pid_queue_remove {{{
;; ARGS:
;;    r8 - pid to remove
;; MODIFIES rsi, rdi, rcx
pid_queue_remove:
  mov rax, [last_queue_pos]
  cmp rax, pid_queue
  jle .not_found

  mov rdi, pid_queue
  sub rdi, 8 ;; for more pretty loop
  mov rcx, max_process_amount + 1 ;; same

  .loop:
    add rdi, 8
    dec rcx

    ;; bounds check
    test rcx, rcx
    jz .not_found

    cmp [rdi], r8
    jne .loop
    ;; again no bounds check. As everywhere here

  mov rsi, rdi
  add rsi, 8
  rep movsq ;; easy to prove correctness when you take proc_amount = 2

  sub qword [last_queue_pos], qword 8
  ret

  .not_found:
    fail_with "Attempting to delete a pid which does not exist"
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
  .zero: resw 3 ;; 4 words = qword
  .sp: resq 1
  .stack_page: resq 1
  .size:
endstruc
; }}}


; processes {{{
align 8
current_pid: dq 0
last_pid: dq 0

;; positions for quick adding and bound checking
last_proc_pos: dq processes
last_queue_pos: dq pid_queue

processes:
;; reserve space for other processes
%rep max_process_amount
  %rep process_info.size
    db 0
  %endrep
%endrep
.end: dq 0 ;; rezerve a zero id

pid_queue:
%rep max_process_amount
 dq 0
%endrep
.end: dq 0 ;; rezerve zero for checking
pid_queue_position: dq pid_queue
; }}}
