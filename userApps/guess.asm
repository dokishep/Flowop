[org 0x0000]
bits 16

start:
    ; Save segment registers
    push ds
    push es

    ; App runs at 0x4000:0000 (CS=0x4000, IP=0)
    ; Set DS and ES to match CS
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov ah, 0
    mov si, welcome_msg
    int 0x30

    ; Hardcoded target number for simplicity
    mov cx, 42

game_loop:
    mov ah, 0
    mov si, prompt_msg
    int 0x30

    mov ah, 5
    mov di, buffer
    int 0x30

    ; Convert string in buffer to integer in AX
    mov si, buffer
    call str_to_int

    cmp ax, cx
    je win
    jl too_low

too_high:
    mov ah, 0
    mov si, high_msg
    int 0x30
    jmp game_loop

too_low:
    mov ah, 0
    mov si, low_msg
    int 0x30
    jmp game_loop

win:
    mov ah, 0
    mov si, win_msg
    int 0x30

    ; Restore segment registers
    pop es
    pop ds
    
    ; Return via FAR RET since cmd_run uses a FAR CALL
    retf

str_to_int:
    push cx
    push dx
    xor ax, ax
    xor bx, bx
.loop:
    mov bl, [si]
    inc si
    cmp bl, 0
    je .done
    cmp bl, '0'
    jl .done
    cmp bl, '9'
    jg .done
    
    sub bl, '0'
    mov cx, 10
    mul cx          ; ax = ax * 10
    add ax, bx
    jmp .loop
.done:
    pop dx
    pop cx
    ret

welcome_msg db "Number Guessing Game! Guess a number between 1 and 100.", 13, 10, 0
prompt_msg  db "Enter your guess: ", 0
high_msg    db "Too high!", 13, 10, 0
low_msg     db "Too low!", 13, 10, 0
win_msg     db "Correct! You win!", 13, 10, 0

buffer times 16 db 0
