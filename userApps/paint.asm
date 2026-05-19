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

    ; Initial coordinates (center of the screen)
    mov cx, 160 ; X coordinate
    mov dx, 100 ; Y coordinate
    mov bl, 15  ; Default color (white)

game_loop:
    ; Draw pixel at (CX, DX) with color BL
    mov ah, 3
    mov al, bl
    int 0x30

    ; Wait for key press
    mov ah, 4
    int 0x30

    ; Check input key in AL
    cmp al, 'q'
    je end_game     ; Quit
    
    cmp al, 'w'
    je move_up
    cmp al, 's'
    je move_down
    cmp al, 'a'
    je move_left
    cmp al, 'd'
    je move_right
    
    ; Color changing keys
    cmp al, '1'
    je color_red
    cmp al, '2'
    je color_green
    cmp al, '3'
    je color_blue
    cmp al, '4'
    je color_white
    cmp al, '5'
    je color_black  ; Eraser

    cmp al, 'c'
    je clear_screen ; Clear screen

    jmp game_loop

move_up:
    cmp dx, 0
    je game_loop    ; Don't go off top edge
    dec dx
    jmp game_loop

move_down:
    cmp dx, 199
    je game_loop    ; Don't go off bottom edge
    inc dx
    jmp game_loop

move_left:
    cmp cx, 0
    je game_loop    ; Don't go off left edge
    dec cx
    jmp game_loop

move_right:
    cmp cx, 319
    je game_loop    ; Don't go off right edge
    inc cx
    jmp game_loop

color_red:
    mov bl, 4       ; Red
    jmp game_loop
color_green:
    mov bl, 2       ; Green
    jmp game_loop
color_blue:
    mov bl, 1       ; Blue
    jmp game_loop
color_white:
    mov bl, 15      ; White
    jmp game_loop
color_black:
    mov bl, 0       ; Black (acts as an eraser)
    jmp game_loop

clear_screen:
    ; Re-enter graphics mode to clear the screen
    mov ah, 2
    mov al, 0x13
    int 0x30
    jmp game_loop

end_game:
    ; Restore text mode before exiting
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

exit_msg db "Thanks for playing! Back to OS...", 13, 10, 0
