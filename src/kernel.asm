[org 0x0000]
bits 16

kernel_start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    
    mov si, KERNEL_MSG
    call kernel_print

    call setup_syscalls
    mov si, SYSCALL_MSG
    call kernel_print

    mov si, RUNNING_CMD_MSG
    call kernel_print

    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    
    jmp 0x2000:0000

kernel_print:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp kernel_print
.done:
    ret

kernel_end:
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov si, EXIT_MSG
    call kernel_print

kernel_halt:
    cli
    hlt
    jmp kernel_halt

KERNEL_MSG      db "Flowop Kernel Loaded.", 13, 10, 0
SYSCALL_MSG     db "Syscalls expanded (Modes, Draw, I/O).", 13, 10, 0
RUNNING_CMD_MSG db "Transferring to BASIC Shell...", 13, 10, 0
EXIT_MSG        db "Shell Terminated. Kernel Halting.", 13, 10, 0

%include "syscalls.asm"

; Pad to exactly 4 sectors (2048 bytes)
times 2048-($-$$) db 0