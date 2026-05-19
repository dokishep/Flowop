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
    push bx
    mov ah, 0x00
    int 0x16
    pop bx
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
    push bx
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    jmp .key_done
.no_key:
    mov al, 0
.key_done:
    pop bx
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
    mov al, 0x00 ; Scroll all lines
    mov bh, 0x07 ; White on black attribute
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