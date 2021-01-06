; 读取一个扇区
cylind db 'cylind:?? $',0   ; 柱面
header db 'header:?? $',0   ; 磁头
sector db 'sectpy:?? $',2   ; 扇区

readSector:     ; 解析读取位置

    mov cl, [sector+11]
    ; 将数字转换成ASCII，替换掉？
    call num2ascii
    mov   [sector+7],al
    mov   [sector+8],ah

    mov cl, [header+11]
    call num2ascii
    mov   [header+7],al
    mov   [header+8],ah

    mov cl, [sector+11]
    call num2ascii
    mov   [sector+7],al
    mov   [sector+8],ah

    ; 设置读取
    mov ch, [cylind+11]
    mov dh, [header+11]
    mov cl, [sector+11]

    ; 显示信息
    call readinfo
    ; 记录读取错误次数
    mov di, 0

retry:

    mov ah, 02h ; AH0x02表示读取磁盘
    mov al, 1   ; 读取的扇区数
    mov bx, 0   ; ES:BX 读到内存的地址 0x0800*16 + 0 = 0x8000
    mov dl, 0   ; 驱动器号，表示第一个软盘
    int 13h     ; 调用bios13号中断，磁盘相关功能
    jnc ReadOK  ; CF=0表示为未出错，则跳转ReadOK
    inc di      ; 错误则递增

    mov ah, 0   ; 设置为重置驱动器
    mov dl, 0   ; 还是第一个软盘
    int 13h     ; 重置驱动器
    cmp di, 5
    jne retry   ; 再次尝试读取

    mov si, fyError     ; 错误处理
    call printStr
    call newLine
    jmp exitread

ReadOK:    
    mov     si, fyOK
    call    printStr
    call    newLine

exitread:
    ret