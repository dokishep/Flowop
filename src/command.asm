[org 0x0000]
bits 16

command_start:
    ; Syscall ID 0: Print String
    mov ah, 0
    mov si, CMD_HELLO
    int 0x30

    ; Syscall ID 1: Terminate Process / Return to Kernel
    mov ah, 1
    int 0x30

CMD_HELLO db " -> [App] Hello from the separate auto-run command binary!", 13, 10, 0

; Pad process to exactly 1 full sector (512 bytes)
times 512-($-$$) db 0