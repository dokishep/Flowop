[org 0x0000]
bits 16

start:
    push ds
    push es
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; 1. Switch to VGA graphics mode (320x200) via Syscall 2
    mov ah, 2
    mov al, 0x13
    int 0x30

    ; 2. Initialize Ant position to center of 320x200 screen
    mov word [ant_x], 160
    mov word [ant_y], 100
    mov byte [ant_dir], 0   ; 0=Up, 1=Right, 2=Down, 3=Left

main_loop:
    ; 3. Check for 'q' key to quit gracefully (non-blocking)
    mov ah, 6
    int 0x30
    cmp al, 'q'
    je exit_game

    ; 4. Read the current pixel color at the Ant's location
    ; Unfortunately, standard BIOS int 0x10/AH=0Dh read-pixel isn't in your 
    ; current syscall list. Instead, we can read directly from VGA Video Memory!
    ; Video memory for mode 13h starts at segment 0xA000. 
    ; Offset = (Y * 320) + X.
    
    push es
    mov ax, 0xA000
    mov es, ax
    
    ; Calculate offset: (Y * 320) + X
    mov ax, [ant_y]
    mov bx, 320
    mul bx              ; DX:AX = Y * 320 (Fits easily in AX since Max Y = 199)
    add ax, [ant_x]     ; AX = (Y * 320) + X
    mov di, ax          ; DI = memory index
    
    mov al, [es:di]     ; Read color from screen memory into AL
    pop es              ; Restore our data segment context

    ; 5. Evaluate color and apply Langton's Ant logic
    cmp al, 0           ; Is it black?
    je .on_black

.on_white:
    ; Rule: If on white (or any non-black color), change to black, turn Left
    mov byte [current_color], 0
    
    ; Turn Left: (dir - 1) & 3
    dec byte [ant_dir]
    and byte [ant_dir], 3
    jmp .update_pixel

.on_black:
    ; Rule: If on black, change to white, turn Right
    mov byte [current_color], 15 ; Color index 15 = crisp White in VGA
    
    ; Turn Right: (dir + 1) & 3
    inc byte [ant_dir]
    and byte [ant_dir], 3

.update_pixel:
    ; 6. Redraw the modified square using your Syscall 3 (Draw Pixel)
    ; Input: AL = color, CX = x, DX = y
    mov al, [current_color]
    mov cx, [ant_x]
    mov dx, [ant_y]
    mov ah, 3
    int 0x30

    ; 7. Move Ant forward one step based on its new direction
    cmp byte [ant_dir], 0
    je .move_up
    cmp byte [ant_dir], 1
    je .move_right
    cmp byte [ant_dir], 2
    je .move_down
    cmp byte [ant_dir], 3
    je .move_left

.move_up:
    dec word [ant_y]
    jmp .check_bounds
.move_right:
    inc word [ant_x]
    jmp .check_bounds
.move_down:
    inc word [ant_y]
    jmp .check_bounds
.move_left:
    dec word [ant_x]

.check_bounds:
    ; 8. Bounds checking & wrap-around (X: 0-319, Y: 0-199)
    ; Check X bounds
    cmp word [ant_x], 320
    jl .check_x_neg
    mov word [ant_x], 0
    jmp .check_y
.check_x_neg:
    cmp word [ant_x], 0
    jge .check_y
    mov word [ant_x], 319

.check_y:
    ; Check Y bounds
    cmp word [ant_y], 200
    jl .check_y_neg
    mov word [ant_y], 0
    jmp .loop_delay
.check_y_neg:
    cmp word [ant_y], 0
    jge .loop_delay
    mov word [ant_y], 199

.loop_delay:
    ; 9. Introduce a short delay so human eyes can watch the simulation build
    mov cx, 0x0000
    mov dx, 4000        ; ~4ms delay. Make smaller or remove entirely for hyper-speed
    mov ah, 8
    int 0x30

    jmp main_loop

exit_game:
    ; 10. Restore text mode (Mode 0x03) via Syscall 2
    mov ah, 2
    mov al, 0x03
    int 0x30

    ; Print closing message via Syscall 0
    mov ah, 0
    mov si, exit_msg
    int 0x30

    pop es
    pop ds
    retf                ; Far return back cleanly to your shell!

; Variable Storage
ant_x         dw 0
ant_y         dw 0
ant_dir       db 0      ; 0=Up, 1=Right, 2=Down, 3=Left
current_color db 0

exit_msg      db "Returned from Langton's Ant application.", 13, 10, 0