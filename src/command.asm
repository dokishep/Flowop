[org 0x0000]
bits 16

command_start:
    mov ah, 0
    mov si, WELCOME_MSG
    int 0x30

input_loop:
    ; Print Prompt
    mov ah, 0
    mov si, PROMPT_MSG
    int 0x30

    ; Read Full String Input (Syscall 5)
    mov ah, 5
    mov di, input_buffer
    int 0x30

    ; If user just pressed enter (empty buffer), loop
    cmp byte [input_buffer], 0
    je input_loop

    ; Parse and Execute
    call parse_command
    jmp input_loop

parse_command:
    mov bx, cmd_map
.next_cmd:
    mov si, bx
    cmp byte [si], 0       ; Reached end of map table?
    je .not_found

    mov di, input_buffer
.compare_loop:
    mov al, [si]
    mov ah, [di]
    cmp al, 0              ; Reached end of the map's string? -> MATCH!
    je .match_found
    cmp al, ah             ; Characters match?
    jne .skip_cmd
    inc si
    inc di
    jmp .compare_loop

.skip_cmd:
    ; Fast-forward BX to the next entry in the map table
.skip_loop:
    cmp byte [bx], 0
    je .skip_done
    inc bx
    jmp .skip_loop
.skip_done:
    inc bx                 ; Skip null terminator
    add bx, 2              ; Skip the 2-byte function pointer
    jmp .next_cmd

.match_found:
    ; Ensure input string is also finished or followed by a space
    cmp byte [di], 0
    je .execute
    cmp byte [di], ' '
    je .execute
    jmp .skip_cmd

.execute:
    inc si                 ; Skip the null byte of the map string
    mov ax, [si]           ; Grab the function pointer
    call ax                ; Execute!
    ret

.not_found:
    mov ah, 0
    mov si, ERR_BAD_CMD
    int 0x30
    ret

; ======================================
; BASIC COMMAND WRAPPERS 
; ======================================

cmd_graphics:
    mov ah, 2
    mov al, 0x13           ; Syscall 2: Mode 13h (Graphics 320x200x256)
    int 0x30
    ret

cmd_text:
    mov ah, 2
    mov al, 0x03           ; Syscall 2: Mode 03h (Text 80x25)
    int 0x30
    ret

cmd_draw:
    ; Draws a diagonal white line as a demo
    mov cx, 50             ; X Start
    mov dx, 50             ; Y Start
    mov al, 15             ; Color: White
.draw_loop:
    mov ah, 3              ; Syscall 3: Draw Pixel
    int 0x30
    inc cx
    inc dx
    cmp cx, 100
    jne .draw_loop
    mov ah, 0
    mov si, MSG_DRAWN
    int 0x30
    ret

cmd_wait:
    mov ah, 0
    mov si, MSG_WAIT
    int 0x30
    mov ah, 4              ; Syscall 4: Wait for single key
    int 0x30
    ret

cmd_help:
    mov ah, 0
    mov si, MSG_HELP
    int 0x30
    ret

cmd_exit:
    mov ah, 1              ; Syscall 1: Terminate to Kernel
    int 0x30
    ret

; ======================================
; DATA & INCLUDES
; ======================================
WELCOME_MSG db "Flowop BASIC Shell v1.0", 13, 10, "Type HELP to view commands.", 13, 10, 0
PROMPT_MSG  db "BASIC> ", 0
ERR_BAD_CMD db "Syntax error.", 13, 10, 0
MSG_WAIT    db "Press any key to continue...", 13, 10, 0
MSG_DRAWN   db "Line drawn! (Switch to GRAPHICS to see it)", 13, 10, 0
MSG_HELP    db "Commands: TEXT, GRAPHICS, DRAW, WAIT, HELP, EXIT", 13, 10, 0

; Include the mapping table directly into the binary
%include "basic_map.asm"

input_buffer times 128 db 0

; Pad to exactly 4 sectors (2048 bytes)
times 2048-($-$$) db 0