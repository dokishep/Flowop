bits 16

setup_syscalls:
    cli
    xor ax, ax
    mov es, ax
    ; Set up Interrupt Vector Table (IVT) entry for int 0x30
    ; Memory location: 0x30 * 4 = 0x00C0
    mov word [es:0x00C0], syscall_handler
    mov word [es:0x00C2], cs ; Set segment selector to kernel segment
    sti
    ret

syscall_handler:
    cmp ah, 0
    je .sys_print
    cmp ah, 1
    je .sys_exit
    iret

.sys_print:
    push ax
    push si
.print_loop:
    lodsb
    or al, al
    jz .print_done
    mov ah, 0x0e
    int 0x10
    jmp .print_loop
.print_done:
    pop si
    pop ax
    iret

.sys_exit:
    ; Cleanly break execution flow and jump back to kernel landing code
    jmp 0x1000:kernel_end