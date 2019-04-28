; vim: ft=nasm ts=2 sw=2 expandtab

;; This file is a layout for memory (for pages) used during kernel runtime,
;; but which are mostly allocated at compile time

global base_page_addr

[BITS 64]

section .kernel_runtime
base_page_addr: resq 1
