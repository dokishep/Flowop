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
    push ax             ; [esp+4] Save X coordinate

    call parse_next_arg
    jc .error_pop1
    call arg_to_int
    push ax             ; [esp+2] Save Y coordinate

    call parse_next_arg
    jc .error_pop2
    call arg_to_int     ; AX now holds Color index
    
    mov dx, [esp+2]     ; DX = Y
    mov cx, [esp+4]     ; CX = X
    mov ah, 3           ; Syscall 3: Draw Pixel
    int 0x30

.finish:
    add sp, 4           ; Clean X and Y off the stack safely
    ret

.error_pop2: pop ax
.error_pop1: pop ax
.error:
    mov ah, 0
    mov si, ERR_ARGS
    int 0x30
    ret

; Usage: LINE <X1> <Y1> <X2> <Y2> <COLOR>
; Example: LINE 10 10 200 150 15
cmd_line:
    call parse_next_arg
    jc .err
    call arg_to_int
    push ax             ; [esp+8] X1 Location
    
    call parse_next_arg
    jc .err_p1
    call arg_to_int
    push ax             ; [esp+6] Y1 Location
    
    call parse_next_arg
    jc .err_p2
    call arg_to_int
    push ax             ; [esp+4] X2 Location
    
    call parse_next_arg
    jc .err_p3
    call arg_to_int
    push ax             ; [esp+2] Y2 Location
    
    call parse_next_arg
    jc .err_p4
    call arg_to_int
    push ax             ; [esp]   Color Index

    mov cx, [esp+8]     ; CX = Working X coordinate (Starts at X1)
    mov dx, [esp+6]     ; DX = Working Y coordinate (Starts at Y1)
    mov bx, [esp]       ; BX = Color (BL)

.line_loop:
    mov ax, bx          ; AL = Color
    mov ah, 3           ; Syscall 3: Draw Pixel
    int 0x30

    cmp cx, [esp+4]     ; Check if we reached X2 target destination
    je .done_step_x
    jl .inc_x
    dec cx              ; Move X left if X1 > X2
    jmp .step_y
.inc_x:
    inc cx              ; Move X right if X1 < X2

.step_y:
    cmp dx, [esp+2]     ; Linear interpolation check for Y coordinate step
    je .line_loop
    jl .inc_y
    dec dx              ; Move Y up if Y1 > Y2
    jmp .line_loop
.inc_y:
    inc dx              ; Move Y down if Y1 < Y2
    jmp .line_loop

.done_step_x:
    cmp dx, [esp+2]     ; If X reached destination, check if Y still has steps left
    je .finish
    jl .inc_y_only
    dec dx
    jmp .draw_last_vertical
.inc_y_only:
    inc dx
.draw_last_vertical:
    mov ax, bx
    mov ah, 3
    int 0x30
    jmp .done_step_x

.finish:
    add sp, 10          ; Clean all 5 arguments off the stack safely
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

; Usage: RECT <X> <Y> <WIDTH> <HEIGHT> <COLOR>
; Example: RECT 10 10 50 30 4
cmd_rect:
    call parse_next_arg
    jc .err
    call arg_to_int
    push ax             ; [esp+8] X Start
    
    call parse_next_arg
    jc .err_p1
    call arg_to_int
    push ax             ; [esp+6] Y Start
    
    call parse_next_arg
    jc .err_p2
    call arg_to_int
    push ax             ; [esp+4] Width
    
    call parse_next_arg
    jc .err_p3
    call arg_to_int
    push ax             ; [esp+2] Height
    
    call parse_next_arg
    jc .err_p4
    call arg_to_int
    push ax             ; [esp] Color

    mov si, [esp+2]     ; SI = Height counter
.row_loop:
    push si
    mov bp, [esp+6]     ; BP = Width counter (Offset shifted due to push si)
    mov cx, [esp+10]    ; CX = Current working X position
    mov dx, [esp+8]     ; DX = Current working Y position
.col_loop:
    mov ax, [esp+2]     ; AL = Color (Offset shifted due to push si)
    mov ah, 3           ; Syscall 3: Draw Pixel
    int 0x30
    inc cx              ; Next pixel column
    dec bp
    jnz .col_loop
    
    inc word [esp+8]    ; Shift execution row tracking pointer down 1 pixel line
    pop si
    dec si
    jnz .row_loop

.finish:
    add sp, 10          ; Clean all 5 arguments off the stack safely
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

; =====================================================================
; DATA STRINGS
; =====================================================================
NEWLINE_STR     db 13, 10, 0
ERR_MISSING_ARG db "Error: Missing string argument.", 13, 10, 0
ERR_ARGS        db "Syntax Error: Invalid parameter arguments.", 13, 10, 0
MSG_WAIT        db "Press any key to return...", 13, 10, 0

MSG_HELP        db "Commands:", 13, 10
                db "  TEXT, GRAPHICS, HELP, WAIT, EXIT", 13, 10
                db "  PRINT <text_string>", 13, 10
                db "  PIXEL <x> <y> <color>", 13, 10
                db "  LINE  <x1> <y1> <x2> <y2> <color>", 13, 10
                db "  RECT  <x> <y> <w> <h> <color>", 13, 10, 0