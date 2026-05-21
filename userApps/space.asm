[org 0x0000]
bits 16

start:
    ; Save caller segment registers
    push ds
    push es

    ; Align segment registers to application execution segment (0x4000)
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; 1. Enter VGA graphics mode (320x200, 256 colors) via Syscall 2
    mov ah, 2
    mov al, 0x13
    int 0x30

    ; 2. Initialize Game Entities & State
    mov word [player_x], 20
    mov word [player_y], 23
    mov byte [bullet_active], 0
    mov word [score], 0
    mov word [game_tick], 0
    mov word [alien_speed], 10   ; Higher is slower (ticks per movement)

    ; Initialize aliens
    call reset_aliens

game_loop:
    ; --- Draw Frame ---
    
    ; 1. Draw Player Ship (Green block)
    mov ax, [player_x]
    mov [temp_x], ax
    mov ax, [player_y]
    mov [temp_y], ax
    mov byte [color], 2         ; Green
    call draw_block

    ; 2. Draw Bullet (Yellow block)
    cmp byte [bullet_active], 0
    je .skip_bullet_draw
    mov ax, [bullet_x]
    mov [temp_x], ax
    mov ax, [bullet_y]
    mov [temp_y], ax
    mov byte [color], 14        ; Yellow
    call draw_block
.skip_bullet_draw:

    ; 3. Draw Aliens (Cyan blocks)
    mov cx, 0
.draw_aliens_loop:
    cmp cx, num_aliens
    jge .draw_aliens_done
    mov bx, cx
    shl bx, 1
    cmp byte [alien_active + cx], 1
    jne .next_alien_draw
    mov ax, [alien_x + bx]
    mov [temp_x], ax
    mov ax, [alien_y + bx]
    mov [temp_y], ax
    mov byte [color], 11        ; Cyan
    call draw_block
.next_alien_draw:
    inc cx
    jmp .draw_aliens_loop
.draw_aliens_done:

    ; --- Frame Delay (Frame Rate Limit ~20 FPS) ---
    mov cx, 0x0000
    mov dx, 50000               ; 50ms delay
    mov ah, 8
    int 0x30

    ; --- Erase Frame ---
    
    ; Erase Player
    mov ax, [player_x]
    mov [temp_x], ax
    mov ax, [player_y]
    mov [temp_y], ax
    mov byte [color], 0         ; Black
    call draw_block

    ; Erase Bullet
    cmp byte [bullet_active], 0
    je .skip_bullet_erase
    mov ax, [bullet_x]
    mov [temp_x], ax
    mov ax, [bullet_y]
    mov [temp_y], ax
    mov byte [color], 0
    call draw_block
.skip_bullet_erase:

    ; Erase Aliens
    mov cx, 0
.erase_aliens_loop:
    cmp cx, num_aliens
    jge .erase_aliens_done
    mov bx, cx
    shl bx, 1
    cmp byte [alien_active + cx], 1
    jne .next_alien_erase
    mov ax, [alien_x + bx]
    mov [temp_x], ax
    mov ax, [alien_y + bx]
    mov [temp_y], ax
    mov byte [color], 0
    call draw_block
.next_alien_erase:
    inc cx
    jmp .erase_aliens_loop
.erase_aliens_done:

    ; --- User Input Handling ---
    mov ah, 6                   ; Non-blocking keyboard read
    int 0x30
    cmp al, 0
    je .no_input

    cmp al, 'q'
    je end_game
    cmp al, 'a'
    je .move_left
    cmp al, 'd'
    je .move_right
    cmp al, ' '                 ; Spacebar to fire
    je .shoot
    jmp .no_input

.move_left:
    cmp word [player_x], 0
    je .no_input
    dec word [player_x]
    jmp .no_input

.move_right:
    cmp word [player_x], 39     ; Rightmost edge of 40-wide grid
    je .no_input
    inc word [player_x]
    jmp .no_input

.shoot:
    cmp byte [bullet_active], 0
    jne .no_input               ; Limit to 1 active laser at a time
    mov ax, [player_x]
    mov [bullet_x], ax
    mov ax, [player_y]
    dec ax
    mov [bullet_y], ax
    mov byte [bullet_active], 1

    ; Shoot Sound Chime (high pitch)
    mov bx, 1500                ; Pit divisor (higher freq)
    mov ah, 10
    int 0x30
    mov cx, 0
    mov dx, 5000                ; Brief beep
    mov ah, 8
    int 0x30
    mov ah, 11
    int 0x30

.no_input:

    ; --- Update Bullet ---
    cmp byte [bullet_active], 0
    je .skip_bullet_update
    dec word [bullet_y]
    cmp word [bullet_y], 0
    jge .check_bullet_collisions
    mov byte [bullet_active], 0  ; Despawn off screen
    jmp .skip_bullet_update

.check_bullet_collisions:
    mov cx, 0
.bullet_collision_loop:
    cmp cx, num_aliens
    jge .skip_bullet_update
    cmp byte [alien_active + cx], 1
    jne .next_bullet_collision
    mov bx, cx
    shl bx, 1
    
    mov ax, [bullet_x]
    cmp ax, [alien_x + bx]
    jne .next_bullet_collision
    
    mov ax, [bullet_y]
    cmp ax, [alien_y + bx]
    jne .next_bullet_collision

    ; Collision Registered!
    mov byte [alien_active + cx], 0
    mov byte [bullet_active], 0
    inc word [score]
    
    ; Enemy Explosion Sound Effect
    mov bx, 4000
    mov ah, 10
    int 0x30
    mov cx, 0
    mov dx, 15000
    mov ah, 8
    int 0x30
    mov ah, 11
    int 0x30
    
    jmp .skip_bullet_update

.next_bullet_collision:
    inc cx
    jmp .bullet_collision_loop

.skip_bullet_update:

    ; --- Update Aliens ---
    inc word [game_tick]
    mov ax, [game_tick]
    xor dx, dx
    div word [alien_speed]
    cmp dx, 0
    jne .aliens_update_done     ; Move aliens only on specific ticks

    ; Move active aliens down
    mov cx, 0
.aliens_move_loop:
    cmp cx, num_aliens
    jge .aliens_move_done
    cmp byte [alien_active + cx], 1
    jne .next_alien_move
    mov bx, cx
    shl bx, 1
    inc word [alien_y + bx]
    
    ; Defeat Condition: Alien reached the player's baseline
    mov ax, [alien_y + bx]
    cmp ax, [player_y]
    jge game_over
.next_alien_move:
    inc cx
    jmp .aliens_move_loop
.aliens_move_done:

    ; Respawn check: Are all aliens destroyed?
    mov cx, 0
    mov al, 0
.check_alive_loop:
    cmp cx, num_aliens
    jge .check_alive_done
    or al, [alien_active + cx]
    inc cx
    jmp .check_alive_loop
.check_alive_done:
    cmp al, 0
    jne .aliens_update_done

    ; All dead! Respawn next wave with higher difficulty
    call reset_aliens
    cmp word [alien_speed], 3
    jle .aliens_update_done
    dec word [alien_speed]      ; Fasten next wave movement pace

.aliens_update_done:
    jmp game_loop

end_game:
    ; Restore original standard 80x25 Text Mode
    mov ah, 2
    mov al, 0x03
    int 0x30

    mov ah, 0
    mov si, exit_msg
    int 0x30

    pop es
    pop ds
    retf

game_over:
    ; Defeat Sound Melody
    mov bx, 6000
    mov ah, 10
    int 0x30
    mov cx, 0
    mov dx, 100000
    mov ah, 8
    int 0x30
    mov bx, 8000
    mov ah, 10
    int 0x30
    mov cx, 0
    mov dx, 150000
    mov ah, 8
    int 0x30
    mov ah, 11
    int 0x30

    ; Restore text mode
    mov ah, 2
    mov al, 0x03
    int 0x30

    mov ah, 0
    mov si, game_over_msg
    int 0x30

    mov ah, 0
    mov si, final_score_msg
    int 0x30

    ; Convert score integer to printed string
    mov ax, [score]
    call print_score

    mov ah, 0
    mov si, newline_msg
    int 0x30

    pop es
    pop ds
    retf

; --- Helper Functions ---

; draw_block: Draws an 8x8 pixel block on a 40x25 grid map
draw_block:
    pusha
    
    mov ax, [temp_x]
    shl ax, 3
    mov cx, ax                  ; CX = physical start pixel X

    mov ax, [temp_y]
    shl ax, 3
    mov dx, ax                  ; DX = physical start pixel Y

    mov bx, dx
    add bx, 8                   ; BX = physical end pixel Y
.row_loop:
    mov di, cx
    add di, 8                   ; DI = physical end pixel X
    
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

reset_aliens:
    pusha
    ; Reset alive states and row height
    mov cx, 0
.r_loop:
    cmp cx, num_aliens
    jge .r_done
    mov byte [alien_active + cx], 1
    mov bx, cx
    shl bx, 1
    mov word [alien_y + bx], 2
    inc cx
    jmp .r_loop
.r_done:
    ; Partially randomize starting X coordinates using system clock tick variations
    mov ah, 7
    int 0x30
    and dx, 3                   ; Offsets 0 to 3
    mov cx, 0
.shift_x:
    cmp cx, num_aliens
    jge .shift_done
    mov bx, cx
    shl bx, 1
    mov ax, cx
    mov si, 7
    mul si
    add ax, 3
    add ax, dx                  ; Spreads aliens across screen safely
    mov [alien_x + bx], ax
    inc cx
    jmp .shift_x
.shift_done:
    popa
    ret

print_score:
    ; Converts AX value to ASCII and prints it
    mov di, score_str_buf
    call int_to_str
    mov si, score_str_buf
    mov ah, 0
    int 0x30
    ret

int_to_str:
    pusha
    mov bx, 10
    xor cx, cx
.push_digits:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    cmp ax, 0
    jne .push_digits
.pop_digits:
    pop dx
    mov [di], dl
    inc di
    loop .pop_digits
    mov byte [di], 0
    popa
    ret

; --- Game Data Segment ---
player_x        dw 0
player_y        dw 0

bullet_x        dw 0
bullet_y        dw 0
bullet_active   db 0

num_aliens      equ 5
alien_x         times num_aliens dw 0
alien_y         times num_aliens dw 0
alien_active    times num_aliens db 0

score           dw 0
game_tick       dw 0
alien_speed     dw 0

temp_x          dw 0
temp_y          dw 0
color           db 0

exit_msg        db "Quit Space Shooter. Returned to OS...", 13, 10, 0
game_over_msg   db "==============================", 13, 10
                db "          GAME OVER           ", 13, 10
                db "==============================", 13, 10, 0
final_score_msg db "Your Final Score: ", 0
newline_msg     db 13, 10, 0

score_str_buf   times 8 db 0
