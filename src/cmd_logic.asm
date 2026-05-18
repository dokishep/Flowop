bits 16

; =====================================================================
; HELPER PARSERS
; =====================================================================

; Finds the next argument by searching for spaces and skipping them
; Input: DI = current position in string
; Output: DI = pointer to start of next argument string, Carry Flag set if empty
parse_next_arg:
.find_space:
    mov al, [di]
    cmp al, 0
    je .no_arg
    cmp al, ' '
    je .skip_spaces
    inc di
    jmp .find_space
.skip_spaces:
    mov al, [di]
    cmp al, ' '
    jne .check_end
    inc di
    jmp .skip_spaces
.check_end:
    cmp byte [di], 0
    je .no_arg
    clc                 ; Clear carry (argument found)
    ret
.no_arg:
    stc                 ; Set carry (no argument found)
    ret

; Converts an ASCII numeric argument to a raw word value
; Input: DI = pointer to ASCII string digits
; Output: AX = integer value
arg_to_int:
    push bx
    push cx
    xor ax, ax
    xor cx, cx
.loop:
    mov cl, [di]
    cmp cl, ' '
    je .done
    cmp cl, 0
    je .done
    cmp cl, '0'
    jl .done
    cmp cl, '9'
    jg .done
    
    sub cl, '0'
    mov bx, 10
    mul bx              ; AX = AX * 10
    add ax, cx
    inc di
    jmp .loop
.done:
    pop cx
    pop bx
    ret

; =====================================================================
; MODULAR BASIC COMMAND ACTIONS
; =====================================================================

cmd_graphics:
    mov ah, 2
    mov al, 0x13        ; Mode 13h (320x200 graphics mode)
    int 0x30
    ret

cmd_text:
    mov ah, 2
    mov al, 0x03        ; Mode 03h (80x25 text mode)
    int 0x30
    ret

; Usage: PRINT <your string message here>
cmd_print:
    call parse_next_arg
    jc .no_arg
    mov si, di          ; Point SI directly to the string argument
    mov ah, 0           ; Syscall 0: Print String
    int 0x30
    ; Print a newline character sequence safely
    mov ah, 0
    mov si, NEWLINE_STR
    int 0x30
    ret
.no_arg:
    mov ah, 0
    mov si, ERR_MISSING_ARG
    int 0x30
    ret

; Usage: PIXEL <X> <Y> <COLOR>
; Example: PIXEL 100 50 14
cmd_pixel:
    call parse_next_arg
    jc .error
    call arg_to_int
    push ax             ; Save X coordinate

    call parse_next_arg
    jc .error_pop1
    call arg_to_int
    push ax             ; Save Y coordinate

    call parse_next_arg
    jc .error_pop2
    call arg_to_int     ; AX now holds Color index
    
    pop dx              ; DX = Y
    pop cx              ; CX = X
    mov ah, 3           ; Syscall 3: Draw Pixel
    int 0x30
    ret
.error_pop2: pop ax
.error_pop1: pop ax
.error:
    mov ah, 0
    mov si, ERR_ARGS
    int 0x30
    ret

; Usage: RECT <X> <Y> <WIDTH> <HEIGHT> <COLOR>
; Example: RECT 10 10 50 30 4
cmd_rect:
    call parse_next_arg
    jc .err
    call arg_to_int
    push ax         ; [sp+8] X Start
    
    call parse_next_arg
    jc .err_p1
    call arg_to_int
    push ax         ; [sp+6] Y Start
    
    call parse_next_arg
    jc .err_p2
    call arg_to_int
    push ax         ; [sp+4] Width
    
    call parse_next_arg
    jc .err_p3
    call arg_to_int
    push ax         ; [sp+2] Height
    
    call parse_next_arg
    jc .err_p4
    call arg_to_int
    push ax         ; [sp] Color

    ; Variables setup for processing loop execution
    pop bx              ; BX = Color
    pop si              ; SI = Height counter
.row_loop:
    push si
    mov bp, [esp+4]     ; BP = Width counter
    mov cx, [esp+8]     ; CX = Current working X position
    mov dx, [esp+6]     ; DX = Current working Y position
.col_loop:
    mov ax, bx          ; AL = Color
    mov ah, 3           ; Syscall 3: Draw Pixel
    int 0x30
    inc cx              ; Next pixel column
    dec bp
    jnz .col_loop
    
    inc word [esp+6]    ; Shift execution row tracking pointer down 1 pixel line
    pop si
    dec si
    jnz .row_loop

    add sp, 6           ; Clean leftover variables up off stack cleanly
    ret
.err_p4: pop ax
.err_p3: pop ax
.err_p2: pop ax
.err_p1: pop ax
.err:
    mov ah, 0
    mov si, ERR_ARGS
    int 0x30
    ret

cmd_wait:
    mov ah, 0
    mov si, MSG_WAIT
    int 0x30
    mov ah, 4           ; Syscall 4: Read Key
    int 0x30
    ret

cmd_help:
    mov ah, 0
    mov si, MSG_HELP
    int 0x30
    ret

cmd_exit:
    mov ah, 1           ; Syscall 1: Terminate to Kernel
    int 0x30
    ret
    
NEWLINE_STR     db 13, 10, 0
ERR_MISSING_ARG db "Error: Missing string argument.", 13, 10, 0
ERR_ARGS        db "Syntax Error: Invalid parameter arguments.", 13, 10, 0
MSG_WAIT        db "Press any key to return...", 13, 10, 0

MSG_HELP        db "Commands:", 13, 10
                db "  TEXT, GRAPHICS, HELP, WAIT, EXIT", 13, 10
                db "  PRINT <text_string>", 13, 10
                db "  PIXEL <x> <y> <color>", 13, 10
                db "  RECT  <x> <y> <w> <h> <color>", 13, 10, 0