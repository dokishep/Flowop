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

    ; Switch to VGA graphics mode (320x200, 256 colors)
    mov ah, 2
    mov al, 0x13
    int 0x30

    ; Init mouse
    mov ah, 12
    int 0x30

    ; Show mouse
    mov ah, 13
    int 0x30

game_loop:
    ; Read key async
    mov ah, 6
    int 0x30
    
    cmp al, 'q'
    je end_game
    cmp al, 'c'
    je clear_screen

    ; Get mouse pos
    mov ah, 15
    int 0x30

    ; CX = X, DX = Y, BX = buttons
    shr cx, 1 ; divide X by 2 for 320x200

    ; Draw a red pixel at current mouse position unconditionally to act as a cursor/trail
    push cx
    push dx
    push bx
    mov ah, 3
    mov al, 4 ; Red
    int 0x30
    pop bx
    pop dx
    pop cx

    ; BX = button status. Bit 0 = left button
    test bx, 1
    jz skip_draw

    ; Left button pressed! Draw white pixel!
    mov ah, 3
    mov al, 15 ; White
    int 0x30

skip_draw:
    jmp game_loop

clear_screen:
    ; Hide mouse
    mov ah, 14
    int 0x30

    ; Clear screen by re-entering graphics mode
    mov ah, 2
    mov al, 0x13
    int 0x30

    ; Show mouse
    mov ah, 13
    int 0x30

    jmp game_loop

end_game:
    ; Hide mouse
    mov ah, 14
    int 0x30

    ; Restore text mode
    mov ah, 2
    mov al, 0x03
    int 0x30

    ; Print farewell message
    mov ah, 0
    mov si, exit_msg
    int 0x30

    ; Restore segment registers
    pop es
    pop ds
    
    ; Return to OS via FAR RET
    retf

exit_msg db "Mouse demo finished! Back to OS...", 13, 10, 0
