[org 0x7c00]
bits 16

KERNEL_SEG equ 0x1000
CMD_SEG    equ 0x2000

start:
    mov [BOOT_DRIVE], dl
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Load Kernel: 4 sectors starting from Sector 2 (LBA 1)
    mov ax, KERNEL_SEG
    mov es, ax
    xor bx, bx          
    mov ah, 0x02        
    mov al, 4           ; Increased to 4 sectors
    mov ch, 0           
    mov dh, 0           
    mov cl, 2           
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc disk_error       

    ; Load Command Binary: 4 sectors starting from Sector 6 (LBA 5)
    mov ax, CMD_SEG
    mov es, ax
    xor bx, bx          
    mov ah, 0x02        
    mov al, 4           ; Increased to 4 sectors
    mov ch, 0           
    mov dh, 0           
    mov cl, 6           ; Moved up to Sector 6
    mov dl, [BOOT_DRIVE]
    int 0x13
    jc disk_error

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