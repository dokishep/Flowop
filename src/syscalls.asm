bits 16

setup_syscalls:
    cli
    xor ax, ax
    mov es, ax
    mov word [es:0x00C0], syscall_handler
    mov word [es:0x00C2], cs 
    sti
    ret

syscall_handler:
    cmp ah, 0
    je .sys_print
    cmp ah, 1
    je .sys_exit
    cmp ah, 2
    je .sys_video_mode
    cmp ah, 3
    je .sys_draw_pixel
    cmp ah, 4
    je .sys_read_key
    cmp ah, 5
    je .sys_read_string
    cmp ah, 6
    je .sys_read_key_async
    cmp ah, 7
    je .sys_get_time
    cmp ah, 8
    je .sys_sleep
    cmp ah, 9
    je .sys_clear_screen
    cmp ah, 10
    je .sys_play_tone
    cmp ah, 11
    je .sys_stop_sound
    cmp ah, 12
    je .sys_mouse_init
    cmp ah, 13
    je .sys_mouse_show
    cmp ah, 14
    je .sys_mouse_hide
    cmp ah, 15
    je .sys_mouse_get_pos
    iret

.sys_print:
    push ax
    push si
.print_loop:
    lodsb
    or al, al
    jz .print_done
    mov ah, 0x0e
    int 0x10
    jmp .print_loop
.print_done:
    pop si
    pop ax
    iret

.sys_exit:
    jmp 0x1000:kernel_end

.sys_video_mode:
    ; Input AL = mode (0x03 text, 0x13 graphics)
    push ax
    mov ah, 0x00
    int 0x10
    pop ax
    iret

.sys_draw_pixel:
    ; Input AL = color, CX = x, DX = y
    push ax
    push bx
    mov ah, 0x0C
    mov bh, 0x00
    int 0x10
    pop bx
    pop ax
    iret

.sys_read_key:
    ; Output AL = ascii character
    mov ah, 0x00
    int 0x16
    iret

.sys_read_string:
    ; Input DI = memory buffer for string
    push ax
    push bx
    push cx
    push di
    mov cx, di       ; Save original buffer start for backspace check
.rs_loop:
    mov ah, 0x00
    int 0x16         ; Wait for key
    cmp al, 0x0D     ; Enter key?
    je .rs_done
    cmp al, 0x08     ; Backspace key?
    je .rs_backspace
    
    stosb            ; Store char in [DI] and DI++
    mov ah, 0x0e
    int 0x10         ; Echo char to screen
    jmp .rs_loop

.rs_backspace:
    cmp di, cx       ; Are we at the start of the buffer?
    je .rs_loop      ; If yes, ignore backspace
    dec di           ; Move buffer pointer back
    mov ah, 0x0e
    mov al, 0x08
    int 0x10         ; Move cursor left visually
    mov al, ' '
    int 0x10         ; Overwrite with space visually
    mov al, 0x08
    int 0x10         ; Move cursor left again visually
    jmp .rs_loop

.rs_done:
    mov byte [di], 0 ; Null terminate the string
    mov ah, 0x0e
    mov al, 0x0D     ; Print Carriage Return
    int 0x10
    mov al, 0x0A     ; Print Line Feed
    int 0x10
    pop di
    pop cx
    pop bx
    pop ax
    iret

.sys_read_key_async:
    ; Output AL = ascii character, or 0 if no key
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    jmp .key_done
.no_key:
    mov al, 0
.key_done:
    iret

.sys_get_time:
    ; Output CX:DX = clock ticks since midnight
    push ax
    mov ah, 0x00
    int 0x1A
    pop ax
    iret

.sys_sleep:
    ; Input CX:DX = microseconds to wait
    push ax
    mov ah, 0x86
    int 0x15
    pop ax
    iret

.sys_clear_screen:
    ; Clears the screen in text mode (and sets cursor to 0,0)
    pusha
    mov ah, 0x06
    mov al, 0x00   ; Scroll all lines
    mov bh, 0x07   ; White on black attribute
    mov cx, 0x0000 ; Top left
    mov dx, 0x184F ; Bottom right (24, 79)
    int 0x10
    
    ; Reset cursor
    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0000
    int 0x10
    popa
    iret

.sys_play_tone:
    ; Input BX = Pit Divisor
    push ax

    cli

    mov al, 0xB6
    out 0x43, al

    mov ax, bx       ; Transfer input divisor cleanly into AX
    out 0x42, al     ; LOW BYTE
    mov al, ah
    out 0x42, al     ; HIGH BYTE

    in al, 0x61
    or al, 00000011b
    out 0x61, al

    sti
    pop ax
    iret

.sys_stop_sound:
    push ax

    in al, 0x61
    and al, 11111100b
    out 0x61, al

    pop ax
    iret

.sys_mouse_init:
    pusha
    ; Enable auxiliary device (mouse)
    call .ps2_wait
    mov al, 0xA8
    out 0x64, al

    ; Enable IRQ 12 in PS/2 controller
    call .ps2_wait
    mov al, 0x20
    out 0x64, al
    call .ps2_wait_read
    in al, 0x60
    or al, 2
    push ax
    call .ps2_wait
    mov al, 0x60
    out 0x64, al
    call .ps2_wait
    pop ax
    out 0x60, al

    ; Set mouse default
    call .ps2_wait
    mov al, 0xD4
    out 0x64, al
    call .ps2_wait
    mov al, 0xF6
    out 0x60, al
    call .ps2_wait_read
    in al, 0x60

    ; Enable data reporting
    call .ps2_wait
    mov al, 0xD4
    out 0x64, al
    call .ps2_wait
    mov al, 0xF4
    out 0x60, al
    call .ps2_wait_read
    in al, 0x60

    ; Install IRQ 12 handler
    cli
    xor ax, ax
    mov es, ax
    mov word [es:0x01D0], mouse_irq_handler
    mov word [es:0x01D2], cs
    
    ; Unmask IRQ 12
    in al, 0xA1
    and al, 0xEF
    out 0xA1, al

    ; Unmask IRQ 2
    in al, 0x21
    and al, 0xFB
    out 0x21, al
    sti

    popa
    mov ax, 0xFFFF ; return success
    iret

.ps2_wait:
    in al, 0x64
    test al, 2
    jnz .ps2_wait
    ret

.ps2_wait_read:
    in al, 0x64
    test al, 1
    jz .ps2_wait_read
    ret

.sys_mouse_show:
    iret

.sys_mouse_hide:
    iret

.sys_mouse_get_pos:
    mov cx, [cs:mouse_x]
    mov dx, [cs:mouse_y]
    mov bx, [cs:mouse_btn]
    iret

mouse_cycle db 0
mouse_byte db 0, 0, 0
mouse_x dw 160
mouse_y dw 100
mouse_btn dw 0

mouse_irq_handler:
    pusha
    
    in al, 0x60
    mov bl, al
    
    mov al, [cs:mouse_cycle]
    cmp al, 0
    je .byte0
    cmp al, 1
    je .byte1
    cmp al, 2
    je .byte2
    jmp .done

.byte0:
    test bl, 0x08
    jz .done ; Sync error, discard
    mov [cs:mouse_byte], bl
    inc byte [cs:mouse_cycle]
    jmp .done
.byte1:
    mov [cs:mouse_byte+1], bl
    inc byte [cs:mouse_cycle]
    jmp .done
.byte2:
    mov [cs:mouse_byte+2], bl
    mov byte [cs:mouse_cycle], 0
    
    ; Process
    mov al, [cs:mouse_byte+1]
    cbw
    add [cs:mouse_x], ax
    
    cmp word [cs:mouse_x], 0
    jge .x_min
    mov word [cs:mouse_x], 0
.x_min:
    cmp word [cs:mouse_x], 639
    jle .x_max
    mov word [cs:mouse_x], 639
.x_max:

    mov al, [cs:mouse_byte+2]
    cbw
    sub [cs:mouse_y], ax
    
    cmp word [cs:mouse_y], 0
    jge .y_min
    mov word [cs:mouse_y], 0
.y_min:
    cmp word [cs:mouse_y], 199
    jle .y_max
    mov word [cs:mouse_y], 199
.y_max:

    mov bl, [cs:mouse_byte]
    and bx, 7
    mov [cs:mouse_btn], bx

.done:
    mov al, 0x20
    out 0xA0, al
    out 0x20, al
    popa
    iret