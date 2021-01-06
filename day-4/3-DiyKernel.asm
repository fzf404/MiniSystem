jmp near start

%macro  getPos  0       ; 获取光标位置 DX: Y-X

    mov ah, 03h
    mov bh, 0
    int 10h
%endmacro

%macro crtWin  6        ; 建立窗口,行数-前景:背景色-左上角YX-右上角YX

    mov ah, 06h
    mov al, %1
    mov bh, %2
    mov ch, %3
    mov cl, %4
    mov dh, %5
    mov dl, %6
    int 10h
%endmacro

%macro setPos  3        ; 光标位置,页码-Y-X

    mov ah, 02h
    mov bh, %1
    mov dh, %2
    mov dl, %3
    int 10h
%endmacro

%macro printStr  4      ; 打印字符, Num-Attr-Row-Column

    mov cx, %1       ; 字符数量
    mov ah, 13h
    mov al, 01h      ; 显示属性->BL, 光标位置改变
    mov bh, 0        ; 页
    mov bl, %2       ; 属性
    mov dh, %3       ; 行
    mov dl, %4       ; 列
    int 10h

%endmacro

%macro printBuf 0        ; 显示内存中连续字符串(不用指针)

    mov si,0
    mov cl,[keybuf+1]     ; cl 控制需要输出的字符数量
again:
    mov ah,0eh
    mov al,[keybuf+2+si]
    int 10h
    inc si
    loop again
%endmacro


msg_work    db 'Welcome Work Program, Press Esc to Exit'
msg_game    db 'Welcome Game Program, Press Esc to Exit'
msg_video   db 'Welcome Video Program, Press Esc to Exit'
msg_net     db 'Welcome NetWork Program, Press Esc to Exit'

tabInfo     db 'Please Input Tab Key to Select, Press Esc to Exit'

    menu_1  db'1. WORK      '
    menu_2  db'2. GAMES     '
    menu_3  db'3. VIDEO     '
    menu_4  db'4. NETWORK   '

msg_first   db 'Now In fzfOS Kernel, Please Press Enter Key to Run'
msg_wel     db 'Welcome To fzfOS'
dateTime    db '????/??/?? ??:??:??'
dataEnd     db '?'
row         db 0


start:

    mov ax, cs
    mov ds, ax
    mov es, ax

waitEnter:

    call mainWin
    call showWelcom
    call showTime
    mov ah, 0       ; 读取字符送入al
    int 16h         ; ah=扫描码 al=字符码
    cmp ah, 1ch     ; enter
    jz  firstEnter
    jmp waitEnter

subMenu:
    mov bp, menu_1
    mov cx, menu_2-menu_1
    printStr cx, 13h, 10, 32     ; 16颜色Blue+Brown
    
    mov bp, menu_2
    mov cx, menu_3-menu_2
    printStr cx, 13h, 13, 32     ; 16颜色Blue+Brown

    mov bp, menu_3
    mov cx, menu_3-menu_2
    printStr cx, 13h, 16, 32     ; 16颜色Blue+Brown

    mov bp, menu_4
    mov cx, menu_4-menu_3
    printStr cx, 13h, 19, 32     ; 16颜色Blue+Brown

    ret

firstEnter:

    crtWin  0,31h,4,0,22,79    ; 刷新窗口

    mov bp, tabInfo
    mov cx, menu_1-tabInfo
    printStr  cx,31h,7,18

    crtWin 0,65h,10,32,10,42
    crtWin 0,65h,13,32,13,42
    crtWin 0,65h,16,32,16,42
    crtWin 0,65h,19,32,19,42

    call subMenu    ; 窗口中打印字符串

    setPos 0,10,32               ; 光标设置在第1个菜单处

tabSelect:
    mov  ah,0
    int  16h           ; 键盘中断
    cmp  ah,0fh        ; TAB
    jz   inputTab

    cmp  ah,1ch        ; enter
    jz   nextEnter

    cmp  ah,01h        ; ESC
    jz   waitEnter 

    jmp  firstEnter    

inputTab:

    getPos              
    mov [row], dh

    add byte [row], 3              ; 下一个菜单处
    cmp byte [row], 22
    je  tabEnd
    jmp noEnd

tabEnd: 
    mov byte [row], 10               ; 越界刷新
noEnd:   
    crtWin 0,6dh,[row],32,[row],40
    call subMenu
    setPos 0,[row],32
    jmp tabSelect

nextEnter:
    getPos                       ; 定位什么地方按的ENTER
    mov [row],dh

    cmp byte [row],10
    je  work

    cmp byte [row],13
    je  games

    cmp byte [row],16
    je  video

    cmp byte [row],19
    je  network

    jmp inputTab

work: 

    crtWin 0,31h,4,0,22,79

    mov bp, msg_work
    mov cx,  msg_game-msg_work
    printStr  cx,31h,7,22

    mov  ah,0
    int  16h
    cmp  ah,01h                    ;ESC功能
    jz   firstEnter
    jmp  work


games:  
    crtWin 0,31h,4,0,22,79

    mov bp, msg_game
    mov cx, msg_video-msg_game
    printStr  cx,31h,7,22

    mov  ah,0
    int  16h
    cmp  ah,01h                    ; ESC功能
    jz   firstEnter
    jmp  games

video:   
    crtWin 0,31h,4,0,22,79

    mov bp, msg_video
    mov cx,  msg_net-msg_video
    printStr  cx,31h,7,22

    mov  ah,0
    int  16h
    cmp  ah,01h                    ; ESC功能
    jz   firstEnter
    jmp  video

network:
    crtWin 0,31h,4,0,22,79

    mov bp, msg_net
    mov cx,  tabInfo-msg_net
    printStr  cx,31h,7,22

    mov  ah,0
    int  16h
    cmp  ah,01h                    ;ESC功能
    jz   firstEnter
    jmp  network


showWelcom:
    mov bp,msg_wel
    mov cx, dateTime-msg_wel
    printStr  cx,13h,2,30

    mov bp, msg_first
    mov cx,  msg_wel-msg_first
    printStr  cx,31h,7,12
    ret

mainWin:
    crtWin 0,0x31,0,0,24,79           ;定义窗口背景
    crtWin 0,0x1f,0,0,3,79            ;第一行
    crtWin 0,0x1f,23,0,24,79          ;最后一行
    ret

showTime:

    mov ah,04H             ; DH:DL=月:日 01:04   ch:cl=世纪:年,20:21
    int 1ah

    mov  bh,ch
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    add  bh,30h            ;Ch的高4位to ascii
    and  ch,0000_1111b
    add  ch,30h            ;Ch的低4位to ascii

    mov [dateTime],bh
    mov [dateTime+1],ch

    mov  bh,cl
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    add bh,30h            ;Cl的高4位to ascii
    and cl,0000_1111b
    add cl,30h            ;Cl的低4位to ascii

    mov [dateTime+2],bh
    mov [dateTime+3],cl

    mov  bh,dh
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    add  bh,30h            ;dh的高4位to ascii
    and  dh,0000_1111b
    add  dh,30h            ;dh的低4位to ascii

    mov [dateTime+5],bh
    mov [dateTime+6],dh

    mov  bh,dl
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    add  bh,30h            ;dl的高4位to ascii
    and  dl,0000_1111b
    add  dl,30h            ;dl的低4位to ascii

    mov [dateTime+8],bh
    mov [dateTime+9],dl

    mov ah,02H             ;CH:CL=时:分 DH=秒
    int 1ah

    mov  bh,ch
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    add  bh,30h            ;Ch的高4位to ascii
    and  ch,0000_1111b
    add  ch,30h            ;Ch的低4位to ascii

    mov [dateTime+11],bh
    mov [dateTime+12],ch

    mov  bh,cl
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    add bh,30h            ;Cl的高4位to ascii
    and cl,0000_1111b
    add cl,30h            ;Cl的低4位to ascii

    mov [dateTime+14],bh
    mov [dateTime+15],cl

    mov  bh,dh
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    SHR  bh,1
    add  bh,30h            ;dh的高4位to ascii
    and  dh,0000_1111b
    add  dh,30h            ;dh的低4位to ascii

    mov [dateTime+17],bh
    mov [dateTime+18],dh


    crtWin 0,13h,24,60,24,79     ;设置窗口颜色

    mov bp,dateTime
    mov cx, dataEnd-dateTime
    printStr  cx,13h,24,60

    ret
