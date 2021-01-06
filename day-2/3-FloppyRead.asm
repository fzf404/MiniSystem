; 连续读取多个扇区

NumSector equ 8     ; 软盘最大扇区编号
NumHeader equ 0
NumCylind equ 0

floppyRead:
    call readSector
    mov ax, es
    add ax, 0x0020
    mov es, ax      ; 一扇区512B, 200h
    inc byte [sector+11]    ; 扇区加1
    cmp byte [sector+11], NumSector+1
    jne floppyRead
    ; 下一个磁头
    mov byte [sector+11], 0
    inc byte [header+11]
    cmp   byte [header+11],NumHeader+1
    jne   floppyRead            
    ; 下一个柱面
    mov   byte [header+11],0
    inc   byte [cylind+11]
    cmp   byte [cylind+11],NumCylind+1
    jne   floppyRead            

    ret 

