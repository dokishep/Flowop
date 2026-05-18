[org 0x0000]
bits 16

command_start:
    mov ah, 0
    mov si, WELCOME_MSG
    int 0x30

input_loop:
    mov ah, 0
    mov si, PROMPT_MSG
    int 0x30

    mov ah, 5
    mov di, input_buffer
    int 0x30

    cmp byte [input_buffer], 0
    je input_loop

    call parse_command
    jmp input_loop

parse_command:
    mov bx, cmd_map
.next_cmd:
    mov si, bx
    cmp byte [si], 0
    je .not_found

    mov di, input_buffer
.compare_loop:
    mov al, [si]
    mov ah, [di]
    cmp al, 0
    je .match_found
    cmp al, ah
    jne .skip_cmd
    inc si
    inc di
    jmp .compare_loop

.skip_cmd:
.skip_loop:
    cmp byte [bx], 0
    je .skip_done
    inc bx
    jmp .skip_loop
.skip_done:
    inc bx
    add bx, 2
    jmp .next_cmd

.match_found:
    ; Check if command isolated safely by space boundary or terminator 
    cmp byte [di], 0
    je .execute
    cmp byte [di], ' '
    je .execute
    jmp .skip_cmd

.execute:
    inc si
    mov ax, [si]
    mov di, input_buffer ; Set DI back to buffer head for parameter parsing functions
    call ax
    ret

.not_found:
    mov ah, 0
    mov si, ERR_BAD_CMD
    int 0x30
    ret

WELCOME_MSG db "Flowop Modular Shell v1.1", 13, 10, "Type HELP to list command usages.", 13, 10, 0
PROMPT_MSG  db "BASIC> ", 0
ERR_BAD_CMD db "Syntax error.", 13, 10, 0

; Include dependencies safely in proper linear hierarchy
%include "basic_map.asm"
%include "cmd_logic.asm"

input_buffer times 128 db 0

times 2048-($-$$) db 0