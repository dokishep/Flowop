[org 0x0000]
bits 16

start:
    push ds
    push es
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; Print title
    mov ah, 0
    mov si, MSG_TITLE
    int 0x30

    ; Phrase 1
    mov bx, 659
    mov cx, 150
    call play_note

    mov bx, 698
    mov cx, 150
    call play_note

    mov bx, 831
    mov cx, 150
    call play_note

    mov bx, 880
    mov cx, 150
    call play_note

    mov bx, 988
    mov cx, 300
    call play_note

    mov bx, 880
    mov cx, 150
    call play_note

    mov bx, 988
    mov cx, 150
    call play_note

    mov bx, 880
    mov cx, 150
    call play_note

    ; Phrase 2
    mov bx, 831
    mov cx, 150
    call play_note

    mov bx, 698
    mov cx, 150
    call play_note

    mov bx, 659
    mov cx, 300
    call play_note

    ; Phrase 3
    mov bx, 659
    mov cx, 100
    call play_note

    mov bx, 698
    mov cx, 100
    call play_note

    mov bx, 831
    mov cx, 100
    call play_note

    mov bx, 880
    mov cx, 100
    call play_note

    mov bx, 988
    mov cx, 200
    call play_note

    mov bx, 1047
    mov cx, 200
    call play_note

    mov bx, 988
    mov cx, 150
    call play_note

    mov bx, 880
    mov cx, 150
    call play_note

    mov bx, 831
    mov cx, 150
    call play_note

    mov bx, 698
    mov cx, 150
    call play_note

    mov bx, 659
    mov cx, 500
    call play_note

    ; Done
    mov ah, 0
    mov si, MSG_DONE
    int 0x30

    pop es
    pop ds
    retf

; -------------------------------------------------
; play_note
; BX = frequency (Hz)
; CX = duration (ms)
; -------------------------------------------------
play_note:
    push ax
    push bx
    push cx
    push dx

    ; ---- convert freq to PIT divisor ----
    mov ax, 0x34DC
    mov dx, 0x0012
    div bx

    ; ---- play tone ----
    mov bx, ax          ; Pass the calculated divisor in BX
    mov ah, 10          ; Syscall 10: Play Tone
    int 0x30

    ; ---- sleep ----
    mov ax, cx
    xor dx, dx
    mov cx, 1000
    mul cx              ; ms -> us (result in DX:AX)

    mov cx, dx          ; High 16-bits of delay
    mov dx, ax          ; Low 16-bits of delay
    mov ah, 8           ; Syscall 8: Sleep
    int 0x30

    ; stop sound
    mov ah, 11          ; Syscall 11: Stop Sound
    int 0x30

    ; gap
    mov cx, 0
    mov dx, 50000
    mov ah, 8
    int 0x30

    pop dx
    pop cx
    pop bx
    pop ax
    ret

MSG_TITLE db "Playing Arabic Riff...", 13, 10, 0
MSG_DONE  db "Done!", 13, 10, 0