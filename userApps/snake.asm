[org 0x0000]
bits 16

start:
    push ds
    push es
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; Switch to VGA graphics mode (320x200)
    mov ah, 2
    mov al, 0x13
    int 0x30

    ; Init snake
    mov word [snake_len], 3
    mov word [snake_x], 10
    mov word [snake_y], 10
    mov word [snake_x+2], 9
    mov word [snake_y+2], 10
    mov word [snake_x+4], 8
    mov word [snake_y+4], 10
    mov byte [dir], 0 ; right

    mov word [apple_x], 20
    mov word [apple_y], 15

game_loop:
    ; Check for key press (non-blocking)
    mov ah, 01h
    int 16h
    jz .no_key

    ; Consume key
    mov ah, 00h
    int 16h

    cmp al, 'q'
    je end_game
    cmp al, 'w'
    je .dir_up
    cmp al, 's'
    je .dir_down
    cmp al, 'a'
    je .dir_left
    cmp al, 'd'
    je .dir_right
    jmp .no_key

.dir_up:
    cmp byte [dir], 3 ; Can't go down if going up
    je .no_key
    mov byte [dir], 1
    jmp .no_key

.dir_down:
    cmp byte [dir], 1 ; Can't go up if going down
    je .no_key
    mov byte [dir], 3
    jmp .no_key

.dir_left:
    cmp byte [dir], 0 ; Can't go right if going left
    je .no_key
    mov byte [dir], 2
    jmp .no_key

.dir_right:
    cmp byte [dir], 2 ; Can't go left if going right
    je .no_key
    mov byte [dir], 0

.no_key:
    ; Erase tail block
    mov cx, [snake_len]
    dec cx
    shl cx, 1
    mov bx, cx
    mov ax, [snake_x + bx]
    mov [temp_x], ax
    mov ax, [snake_y + bx]
    mov [temp_y], ax
    mov byte [color], 0
    call draw_block

    ; Shift body array (from tail to head)
    mov cx, [snake_len]
    dec cx
.shift_loop:
    cmp cx, 0
    je .shift_done
    mov bx, cx
    shl bx, 1
    mov ax, [snake_x + bx - 2]
    mov [snake_x + bx], ax
    mov ax, [snake_y + bx - 2]
    mov [snake_y + bx], ax
    dec cx
    jmp .shift_loop
.shift_done:

    ; Update head
    mov ax, [snake_x]
    mov bx, [snake_y]

    cmp byte [dir], 0
    je .move_right
    cmp byte [dir], 1
    je .move_up
    cmp byte [dir], 2
    je .move_left
    cmp byte [dir], 3
    je .move_down

.move_right:
    inc ax
    jmp .move_done
.move_up:
    dec bx
    jmp .move_done
.move_left:
    dec ax
    jmp .move_done
.move_down:
    inc bx
.move_done:

    ; Wrap around edges (40x25 grid)
    cmp ax, 40
    jl .check_x_neg
    mov ax, 0
    jmp .check_y
.check_x_neg:
    cmp ax, 0
    jge .check_y
    mov ax, 39
.check_y:
    cmp bx, 25
    jl .check_y_neg
    mov bx, 0
    jmp .update_head
.check_y_neg:
    cmp bx, 0
    jge .update_head
    mov bx, 24

.update_head:
    mov [snake_x], ax
    mov [snake_y], bx

    ; Self-collision check
    mov cx, 1 ; Start from second body part
.collision_loop:
    cmp cx, [snake_len]
    jge .no_collision
    mov bx, cx
    shl bx, 1
    cmp ax, [snake_x + bx]
    jne .next_collision
    mov dx, [snake_y]
    cmp dx, [snake_y + bx]
    je end_game ; Game over on self-collision
.next_collision:
    inc cx
    jmp .collision_loop
.no_collision:

    ; Check apple collision
    mov ax, [snake_x]
    mov bx, [snake_y]
    cmp ax, [apple_x]
    jne .draw_all
    cmp bx, [apple_y]
    jne .draw_all

    ; Ate apple!
    mov cx, [snake_len]
    cmp cx, 99
    jge .no_grow
    inc word [snake_len]
    ; Put new tail at temp_x, temp_y
    mov bx, cx
    shl bx, 1
    mov ax, [temp_x]
    mov [snake_x + bx], ax
    mov ax, [temp_y]
    mov [snake_y + bx], ax
.no_grow:
    ; Simplistic random apple position
    mov ah, 00h
    int 1Ah ; CX:DX = clock ticks
    mov ax, dx
    xor dx, dx
    mov cx, 40
    div cx
    mov [apple_x], dx

    mov ah, 00h
    int 1Ah
    mov ax, dx
    xor dx, dx
    mov cx, 25
    div cx
    mov [apple_y], dx

.draw_all:
    ; Draw apple
    mov ax, [apple_x]
    mov [temp_x], ax
    mov ax, [apple_y]
    mov [temp_y], ax
    mov byte [color], 4 ; Red
    call draw_block

    ; Draw head
    mov ax, [snake_x]
    mov [temp_x], ax
    mov ax, [snake_y]
    mov [temp_y], ax
    mov byte [color], 2 ; Green
    call draw_block

    ; Delay
    mov cx, 0x0001
    mov dx, 0x86A0 ; ~100ms
    mov ah, 86h
    int 15h

    jmp game_loop

end_game:
    ; Restore text mode
    mov ah, 2
    mov al, 0x03
    int 0x30

    mov ah, 0
    mov si, exit_msg
    int 0x30

    pop es
    pop ds
    retf

; draw_block: draws 8x8 block at temp_x, temp_y with color [color]
draw_block:
    pusha
    
    mov ax, [temp_x]
    shl ax, 3
    mov cx, ax ; CX = start X

    mov ax, [temp_y]
    shl ax, 3
    mov dx, ax ; DX = start Y

    mov bx, dx
    add bx, 8  ; BX = end Y
.row_loop:
    mov di, cx
    add di, 8  ; DI = end X
    
    mov si, cx
.col_loop:
    push cx
    push dx
    push bx
    mov ah, 3
    mov al, [color]
    mov cx, si
    int 0x30
    pop bx
    pop dx
    pop cx

    inc si
    cmp si, di
    jl .col_loop

    inc dx
    cmp dx, bx
    jl .row_loop

    popa
    ret

exit_msg db "Snake game over!", 13, 10, 0

temp_x dw 0
temp_y dw 0
color db 0
dir db 0 ; 0:R, 1:U, 2:L, 3:D
snake_len dw 0
apple_x dw 0
apple_y dw 0
snake_x times 100 dw 0
snake_y times 100 dw 0
