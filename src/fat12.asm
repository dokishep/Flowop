; =====================================================================
; FAT12 RUN COMMAND
; =====================================================================

cmd_run:
    call parse_next_arg
    jc .no_arg
    call format_fat_name

    ; Load Root Directory to 0x3000:0000
    mov ax, 0x3000
    mov es, ax
    mov bx, 0
    mov ah, 0x02
    mov al, 14          ; 14 sectors for root dir
    mov ch, 0           ; Cylinder 0
    mov dh, 1           ; Head 1 (Sector 27 is Cyl 0, Head 1, Sector 10)
    mov cl, 10          ; Sector 10
    mov dl, 0           ; Floppy 0
    int 0x13
    jc .disk_err

    ; Search for file in Root Directory
    mov cx, 224         ; 224 entries
    mov di, 0           ; Offset in 0x3000
.search_loop:
    push cx
    mov cx, 11
    mov si, fat_filename
    push di
.compare_name:
    mov al, [si]
    mov ah, [es:di]
    cmp al, ah
    jne .not_match
    inc si
    inc di
    loop .compare_name
    ; Found it!
    pop di
    pop cx
    jmp .found_file

.not_match:
    pop di
    pop cx
    add di, 32
    loop .search_loop

    ; Not found
    mov ah, 0
    mov si, ERR_FILE_NOT_FOUND
    int 0x30
    ret

.found_file:
    ; Get starting cluster at offset 26
    mov ax, [es:di+26]
    ; Get file size (low word) at offset 28
    mov cx, [es:di+28]
    ; Calculate LBA: LBA = cluster - 2 + 41 = cluster + 39
    add ax, 39
    ; Convert LBA (AX) to CHS for INT 13h
    ; Sectors per track = 18. Tracks per cylinder = 2.
    ; Temp LBA = LBA / 18 -> quotient = Track, rem = Sector - 1
    ; Cylinder = Track / 2 -> quotient = Cylinder, rem = Head
    push ax
    push cx
    xor dx, dx
    mov bx, 18
    div bx              ; AX = Track, DX = Sector - 1
    inc dl              ; DL = Sector
    mov cl, dl          ; CL = Sector
    xor dx, dx
    mov bx, 2
    div bx              ; AX = Cylinder, DX = Head
    mov ch, al          ; CH = Cylinder
    mov dh, dl          ; DH = Head
    mov dl, 0           ; Drive = 0
    pop ax              ; File size into AX
    ; How many sectors? (Size + 511) / 512
    add ax, 511
    shr ax, 9
    cmp ax, 0
    jne .do_read
    mov ax, 1           ; At least 1 sector
.do_read:
    mov al, al          ; AL = sectors to read (assumes < 255)
    
    ; Read to 0x4000:0000
    mov bx, 0x4000
    mov es, bx
    mov bx, 0
    mov ah, 0x02
    int 0x13
    jc .disk_err
    pop bx              ; Stack fix from LBA push

    ; Reset ES back to DS (0x2000)
    mov ax, ds
    mov es, ax

    ; Check extension
    mov al, [fat_filename+8]
    cmp al, 'B'
    jne .unknown_ext
    mov al, [fat_filename+9]
    cmp al, 'A'
    je .run_bas
    cmp al, 'I'
    je .run_bin
.unknown_ext:
    mov ah, 0
    mov si, ERR_INVALID_EXT
    int 0x30
    ret

.run_bin:
    ; Execute BIN file via far call
    call 0x4000:0000
    ret

.run_bas:
    ; Execute BAS file
    mov word [script_ptr], 0
.bas_loop:
    mov ax, 0x4000
    mov es, ax
    mov si, [script_ptr]
    ; Check for EOF or NULL
    mov al, [es:si]
    cmp al, 0
    je .bas_done
    ; Copy line to input_buffer
    mov di, input_buffer
    mov ax, ds
    mov es, ax      ; ES back to 0x2000
.bas_copy_line:
    push ds
    mov ax, 0x4000
    mov ds, ax
    lodsb           ; AL = char from 0x4000:SI
    pop ds
    cmp al, 0
    je .bas_eol
    cmp al, 10      ; \n
    je .bas_eol
    cmp al, 13      ; \r
    je .bas_copy_line
    stosb
    jmp .bas_copy_line
.bas_eol:
    mov byte [di], 0
    mov [script_ptr], si
    ; Call parse_command
    pusha
    call parse_command
    popa
    ; Check if EOF
    cmp al, 0
    je .bas_done
    jmp .bas_loop
.bas_done:
    ret

.no_arg:
    mov ah, 0
    mov si, ERR_MISSING_ARG
    int 0x30
    ret
.disk_err:
    mov ah, 0
    mov si, ERR_DISK
    int 0x30
    ret

format_fat_name:
    pusha
    mov si, di
    mov di, fat_filename
    mov cx, 11
    mov al, ' '
    rep stosb
    mov di, fat_filename
    mov cx, 8
.copy_name:
    lodsb
    cmp al, 0
    je .done_name
    cmp al, ' '
    je .done_name
    cmp al, '.'
    je .copy_ext
    cmp al, 'a'
    jl .store
    cmp al, 'z'
    jg .store
    sub al, 32
.store:
    stosb
    loop .copy_name
.skip:
    lodsb
    cmp al, '.'
    je .copy_ext
    cmp al, 0
    je .done_name
    jmp .skip
.copy_ext:
    mov di, fat_filename + 8
    mov cx, 3
.copy_ext_loop:
    lodsb
    cmp al, 0
    je .done_name
    cmp al, ' '
    je .done_name
    cmp al, 'a'
    jl .store_ext
    cmp al, 'z'
    jg .store_ext
    sub al, 32
.store_ext:
    stosb
    loop .copy_ext_loop
.done_name:
    popa
    ret

cmd_cat:
    call parse_next_arg
    jc .no_arg
    call format_fat_name

    ; Load Root Directory to 0x3000:0000
    mov ax, 0x3000
    mov es, ax
    mov bx, 0
    mov ah, 0x02
    mov al, 14          ; 14 sectors for root dir
    mov ch, 0           ; Cylinder 0
    mov dh, 1           ; Head 1 (Sector 27 is Cyl 0, Head 1, Sector 10)
    mov cl, 10          ; Sector 10
    mov dl, 0           ; Floppy 0
    int 0x13
    jc .disk_err

    ; Search for file in Root Directory
    mov cx, 224         ; 224 entries
    mov di, 0           ; Offset in 0x3000
.search_loop:
    push cx
    mov cx, 11
    mov si, fat_filename
    push di
.compare_name:
    mov al, [si]
    mov ah, [es:di]
    cmp al, ah
    jne .not_match
    inc si
    inc di
    loop .compare_name
    ; Found it!
    pop di
    pop cx
    jmp .found_file

.not_match:
    pop di
    pop cx
    add di, 32
    loop .search_loop

    ; Not found
    mov ah, 0
    mov si, ERR_FILE_NOT_FOUND
    int 0x30
    ret

.found_file:
    ; Get starting cluster at offset 26
    mov ax, [es:di+26]
    ; Get file size (low word) at offset 28
    mov cx, [es:di+28]
    push cx             ; Save actual file size (bytes)
    ; Calculate LBA: LBA = cluster - 2 + 41 = cluster + 39
    add ax, 39
    ; Convert LBA (AX) to CHS for INT 13h
    push ax
    push cx
    xor dx, dx
    mov bx, 18
    div bx              ; AX = Track, DX = Sector - 1
    inc dl              ; DL = Sector
    mov cl, dl          ; CL = Sector
    xor dx, dx
    mov bx, 2
    div bx              ; AX = Cylinder, DX = Head
    mov ch, al          ; CH = Cylinder
    mov dh, dl          ; DH = Head
    mov dl, 0           ; Drive = 0
    pop ax              ; Restore file size into AX
    ; How many sectors? (Size + 511) / 512
    add ax, 511
    shr ax, 9
    cmp ax, 0
    jne .do_read
    mov ax, 1           ; At least 1 sector
.do_read:
    mov al, al          ; AL = sectors to read
    
    ; Read to 0x4000:0000
    mov bx, 0x4000
    mov es, bx
    mov bx, 0
    mov ah, 0x02
    int 0x13
    pop bx              ; Stack fix from LBA push
    jc .disk_err_pop_cx

    ; Reset ES back to DS (0x2000)
    mov ax, ds
    mov es, ax

    ; Print file contents
    pop cx              ; CX = Actual file size
    cmp cx, 0
    je .done
    
    mov si, 0
.print_loop:
    push ds
    mov ax, 0x4000
    mov ds, ax
    lodsb               ; AL = char from 0x4000:SI
    pop ds
    
    cmp al, 0
    je .skip_null
    mov ah, 0x0E
    mov bh, 0
    int 0x10
.skip_null:
    loop .print_loop

.done:
    ; Print newline
    mov ah, 0
    mov si, NEWLINE_STR
    int 0x30
    ret

.no_arg:
    mov ah, 0
    mov si, ERR_MISSING_ARG
    int 0x30
    ret

.disk_err_pop_cx:
    pop cx
.disk_err:
    mov ah, 0
    mov si, ERR_DISK
    int 0x30
    ret

cmd_dir:
    ; Load Root Directory to 0x3000:0000
    mov ax, 0x3000
    mov es, ax
    mov bx, 0
    mov ah, 0x02
    mov al, 14          ; 14 sectors for root dir
    mov ch, 0           ; Cylinder 0
    mov dh, 1           ; Head 1 (Sector 27 is Cyl 0, Head 1, Sector 10)
    mov cl, 10          ; Sector 10
    mov dl, 0           ; Floppy 0
    int 0x13
    jc .disk_err_dir

    mov cx, 224         ; 224 entries
    mov di, 0           ; Offset in 0x3000

.dir_loop:
    mov al, [es:di]
    cmp al, 0x00        ; End of directory
    je .dir_done
    cmp al, 0xE5        ; Deleted file
    je .skip_entry
    
    ; Check attribute byte at offset 11
    mov al, [es:di+11]
    cmp al, 0x0F        ; LFN entry
    je .skip_entry
    test al, 0x08       ; Volume label
    jnz .skip_entry
    
    ; Print filename (11 chars)
    push cx
    mov cx, 11
    mov si, di
.print_name:
    mov al, [es:si]
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    inc si
    loop .print_name
    pop cx
    
    ; Print newline
    mov ah, 0
    mov si, NEWLINE_STR
    int 0x30

.skip_entry:
    add di, 32
    loop .dir_loop

.dir_done:
    mov ax, ds
    mov es, ax
    ret

.disk_err_dir:
    mov ax, ds
    mov es, ax
    mov ah, 0
    mov si, ERR_DISK
    int 0x30
    ret

; Variables and strings for FAT12
fat_filename       db "           "
script_ptr         dw 0
ERR_FILE_NOT_FOUND db "Error: File not found.", 13, 10, 0
ERR_INVALID_EXT    db "Error: Invalid file extension (use .BIN or .BAS).", 13, 10, 0
ERR_DISK           db "Error: Disk read failure.", 13, 10, 0
