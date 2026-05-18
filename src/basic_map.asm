cmd_map:
    db "GRAPHICS", 0
    dw cmd_graphics
    
    db "TEXT", 0
    dw cmd_text
    
    db "PRINT", 0
    dw cmd_print
    
    db "PIXEL", 0
    dw cmd_pixel

    db "LINE", 0
    dw cmd_line
    
    db "RECT", 0
    dw cmd_rect
    
    db "WAIT", 0
    dw cmd_wait
    
    db "HELP", 0
    dw cmd_help
    
    db "EXIT", 0
    dw cmd_exit
    
    db 0 ; End of Table Map