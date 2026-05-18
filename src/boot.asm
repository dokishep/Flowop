[org 0x7c00]
bits 16

KERNEL_SEG equ 0x1000
CMD_SEG    equ 0x2000

start:
    ; Save the boot drive number provided by BIOS in DL
    mov [BOOT_DRIVE], dl

    ; Set up clean segment registers and stack pointer
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Load Kernel: 2 sectors starting from Sector 2
    mov ax, KERNEL_SEG
    mov es, ax
    xor bx, bx          ; Destination ES:BX = 0x1000:0000
    mov ah, 0x02        ; BIOS Read Sectors function
    mov al, 2           ; Number of sectors to read
    mov ch, 0           ; Cylinder 0
    mov dh, 0           ; Head 0
    mov cl, 2           ; Sector 2
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc disk_error       ; Jump if carry flag set (error)

    ; Load Command Binary: 1 sector starting from Sector 4
    mov ax, CMD_SEG
    mov es, ax
    xor bx, bx          ; Destination ES:BX = 0x2000:0000
    mov ah, 0x02        ; BIOS Read Sectors function
    mov al, 1           ; Number of sectors to read
    mov ch, 0           ; Cylinder 0
    mov dh, 0           ; Head 0
    mov cl, 4           ; Sector 4
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc disk_error

    ; Jump directly to the loaded kernel
    jmp KERNEL_SEG:0000

disk_error:
    mov si, ERROR_MSG
print_loop:
    lodsb
    or al, al
    jz halt
    mov ah, 0x0e
    int 0x10
    jmp print_loop

halt:
    cli
    hlt
    jmp halt

BOOT_DRIVE db 0
ERROR_MSG  db "Disk Read Error!", 13, 10, 0

times 510-($-$$) db 0
dw 0xaa55