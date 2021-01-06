NumSector equ 18     ; 软盘最大扇区编号
NumHeader equ 1
NumCylind equ 5

MBRseg       equ    7c0h     ; 启动扇区段地址
Loaderseg    equ    800h     ; 从软盘读取LOADER到内存的段地址
Kernelseg    equ    0c20h    ; 8000h+4200h 4200H为FAT文件的偏移地址

jmp short start     ;  jmp short 占位2字节

    DB  0x90            ; 第三字节必须为90
    DB  "FZF40404"      ; 8字节名称
    DW  512
    DB  1               ; 簇(cluster)的大小必须为1个扇区
    DW  1               ; FAT的起始位置(一般从第一个扇区开始)
    DB  2               ; FAT的个数(必须为2)
    DW  224             ; 根目录的大小(一般设为244项)
    DW  2880            ; 该磁盘的的大小(必须为2880扇区)
    DB  0xf0            ; 磁盘的种类(必须为0xfd)
    DW  9               ; FAT的长度(必须为9扇区)
    DW  18              ; 一个磁道(track)有几个扇区(必须为18)
    DW  2               ; 磁头数(必须为2)
    DD  0               ; 不使用分区(必须为0)
    DD  2880            ; 重写一次磁盘大小
    DB  0,0,0x29        ; 意义不明，固定
    DD  0xffffffff      ; (可能是)卷标号码
    DB  "FZF-OS-DISC"   ; 磁盘名称(11字节)
    DB  "FAT12   "      ; 磁盘格式名称(8字节)
    RESB    18          ; 先腾出18字节

start:
    call inMBR
    call loader
    ; jmp  $
    jmp Kernelseg:0

inMBR:
    mov ax, MBRseg 
    mov ds, ax      ; 初始化段寄存器   
    mov ax, Loaderseg
    mov es, ax      ; 读软盘需要ES:BX

    mov si, msg_welcome
    call printStr
    call newLine
    ret   

loader:
    mov si, msg_Fyread
    call printStr
    call newLine
    call floppyLoad
    mov si ,msg_FyContent
    call printStr
    call showData
    ret

floppyLoad:
    call readSector
    mov ax, es
    add ax, 0x0020
    mov es, ax              ; 一扇区512B->200h
    inc byte [sector+11]    ; 扇区加1
    cmp byte [sector+11], NumSector+1
    jne floppyLoad
    ; 下一个磁头
    mov byte [sector+11], 1
    inc byte [header+11]
    cmp byte [header+11],NumHeader+1
    jne floppyLoad            
    ; 下一个柱面
    mov byte [header+11],0
    inc byte [cylind+11]
    cmp byte [cylind+11],NumCylind+1
    jne floppyLoad            

    ret 

num2ascii:
    mov ax, 0
    mov al, cl
    mov bl, 10
    div bl  ; ax/bl 结果->ah 余数->al
    add ax, 3030h
    ret

readInfo:
    mov si, cylind
    call printStr
    mov si, header
    call printStr
    mov si, sector
    call printStr
    ret

readSector:     ; 解析读取位置

    mov  cl, [sector+11]
    ; 将数字转换成ASCII，替换掉？
    call num2ascii
    mov  [sector+7],al
    mov  [sector+8],ah

    mov  cl, [header+11]
    call num2ascii
    mov  [header+7],al
    mov  [header+8],ah

    mov  cl, [cylind+11]
    call num2ascii
    mov  [cylind+7],al
    mov  [cylind+8],ah

    ; 设置读取
    mov ch, [cylind+11]
    mov dh, [header+11]
    mov cl, [sector+11]

    ; 显示信息
    call readInfo
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

    mov si, msg_FyError     ; 错误处理
    call printStr
    call newLine
    jmp exitRead

ReadOK:    
    mov     si, msg_FyOK
    call    printStr
    call    newLine

exitRead:
    ret

printStr:
    ; 将字符拷贝到al
    mov al, [si]
    ; 判断是否末尾
    cmp al, '$'
    je showOver
    ; 设置10H中断的服务：在Teletype模式下显示字符
    mov ah, 0eh
    ; BIOS对显示器和屏幕所提供的服务程序
    int 10h
    ; 递增si的值
    inc si
    ; 递归
    jmp printStr
showOver:
    ret

newLine:
    mov ah, 0eh
    mov al, 0dh
    int 10h
    mov al, 0ah
    int 10h
    ret

showData:  
    mov  si, 3             ; 验证显示从软盘读取到内存的数据 
    mov  ax, Kernelseg 
    mov  es, ax
    mov  cx, 8             ; nextchar循环9次 
nextchar:  
    mov al, [es:si]
    mov ah, 0eh
    int 10h
    inc si
    loop nextchar
    ret

msg_welcome db 'Welcome To FZF OS!','$'
cylind  db 'cylind:?? $',0    
header  db 'header:?? $',0    
sector  db 'sector:?? $',1    
msg_FyOK db '-- Floppy Read OK','$'
msg_Fyread  db 'Floppy Read Loader:','$'
msg_FyError db '-- Floppy Read Error' ,'$'
msg_FyContent db 'Floppy Content is: ', '$'

times 510-($-$$) db 0
db 0x55,0xaa