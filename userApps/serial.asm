[org 0x0000]
bits 16

start:
    ; Save segment registers
    push ds
    push es

    ; App runs at segment where it was loaded (CS)
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; Print welcome message
    mov ah, 0
    mov si, welcome_msg
    int 0x30

.loop:
    ; Check for keyboard input (async)
    mov ah, 6
    int 0x30
    
    cmp al, 0
    je .check_serial
    
    cmp al, 27 ; ESC key
    je .exit
    
    ; Send character over serial
    mov ah, 13
    int 0x30
    
    ; Print local echo
    mov ah, 0
    mov byte [char_buf], al
    mov byte [char_buf+1], 0
    mov si, char_buf
    int 0x30

.check_serial:
    ; Check for serial data
    mov ah, 14
    int 0x30
    
    cmp al, 0
    je .loop
    
    ; Print received character
    mov ah, 0
    mov byte [char_buf], al
    mov byte [char_buf+1], 0
    mov si, char_buf
    int 0x30
    
    jmp .loop

.exit:
    ; Print exit message
    mov ah, 0
    mov si, exit_msg
    int 0x30

    ; Restore segment registers
    pop es
    pop ds
    
    ; Return to OS via FAR RET
    retf

welcome_msg db "Serial Client Started! Press ESC to exit.", 13, 10, 0
exit_msg db 13, 10, "Exiting Serial Client...", 13, 10, 0
char_buf db 0, 0
