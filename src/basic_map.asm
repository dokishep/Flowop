; Map structure: [String], Null-Terminator, [Function Pointer Word]
cmd_map:
    db "GRAPHICS", 0
    dw cmd_graphics
    
    db "TEXT", 0
    dw cmd_text
    
    db "DRAW", 0
    dw cmd_draw
    
    db "WAIT", 0
    dw cmd_wait
    
    db "HELP", 0
    dw cmd_help
    
    db "EXIT", 0
    dw cmd_exit
    
    db 0 ; Table Terminator