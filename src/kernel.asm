[org 0x0000]
bits 16

kernel_start:
    ; Synchronize data segments with code segment (0x1000)
    mov ax, cs
    mov ds, ax
    mov es, ax
    
    ; Print status
    mov si, KERNEL_MSG
    call kernel_print

    ; Initialize custom system calls interface
    call setup_syscalls
    mov si, SYSCALL_MSG
    call kernel_print

    ; Prepare data segments for user land environment execution
    mov si, RUNNING_CMD_MSG
    call kernel_print

    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    
    ; Jump to the command binary loaded at 0x2000:0000
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
    ; The program safely returns here via Syscall 1 (sys_exit)
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov si, EXIT_MSG
    call kernel_print

kernel_halt:
    cli
    hlt
    jmp kernel_halt

KERNEL_MSG      db "Welcome to flowop Kernel!", 13, 10, 0
SYSCALL_MSG     db "Syscalls initialized safely (Int 0x30)...", 13, 10, 0
RUNNING_CMD_MSG db "Launching auto-run user binary application...", 13, 10, 0
EXIT_MSG        db "Command exited. Kernel regained control. Halting.", 13, 10, 0

; Merges the system calls code completely inside the kernel binary
%include "syscalls.asm"

; Pad out the binary to exactly 2 full sectors (1024 bytes)
times 1024-($-$$) db 0