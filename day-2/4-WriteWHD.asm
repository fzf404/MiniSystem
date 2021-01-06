whdcylind  db 'cylind:?? $',0    ; 设置开始写的柱面编号
whdheader  db 'header:?? $',0    ; 设置开始写的磁头编号
whdsector  db 'sector:?? $',2    ; 设置开始写的扇区编号

writeSector:   ; 写一个扇区

    mov   cl, [whdsector+11]      
    call  numtoascii2
    mov   [whdsector+7], al
    mov   [whdsector+8], ah

    mov   cl, [whdheader+11]
    call  numtoascii2
    mov   [whdheader+7], al
    mov   [whdheader+8], ah

    mov   cl, [whdcylind+11]
    call  numtoascii2
    mov   [whdcylind+7], al
    mov   [whdcylind+8], ah

    mov   ch, [whdcylind+11]    
    mov   dh, [whdheader+11]    
    mov   cl, [whdsector+11]    

    call  writeinfo2
    mov   di,0

wretry:
    mov    ah, 03H     ; AH=0x03表示写磁盘
    mov    al, 1       ; 要写的扇区数
    mov    bx, 0       ; ES:BX表示取数据从内存的地址 0x1000*16 + 0 = 0x10000
    mov    dl,80H      ; 驱动器号，硬盘C:80H C 硬盘D:81H
    int    13H
    jnc    writeOK     ; 成功跳转
    inc    di
    mov    ah,0x00
    mov    dl,0x80
    int    13h         ; 重置驱动器
    cmp    di, 5       ; 同一扇区如果重读5次都失败就放弃
    jne    wretry

    mov     si, whdError
    call    printstr
    call    newline2
    jmp     exitWrite
writeOK: 
    mov     si, whdOK
    call    printstr
    call    newLine
       
exitWrite:     
    ret

; 写入n个
whdNumSector      EQU    2        ; 设置写到硬盘的最大扇区编号
whdNumHeader      EQU    0        ; 设置写到硬盘的最大磁头编号
whdNumCylind      EQU    0        ; 设置写到硬盘的柱面编号

hdiskWrite:
    call    writeSector
    mov ax, es
    add ax, 0x0020
    mov es, ax      ; 一扇区512B, 200h
    inc   byte [whdsector+11]
    cmp   byte [whdsector+11],whdNUMsector+1
    jne   hdiskWrite             

    mov   byte [whdsector+11],0
    inc   byte [whdheader+11]
    cmp   byte [whdheader+11],whdNUMheader+1
    jne   hdiskWrite            

    mov   byte [whdheader+11],0
    inc   byte [whdcylind+11]
    cmp   byte [whdcylind+11],whdNUMcylind+1
    jne   hdiskWrite             

    ret