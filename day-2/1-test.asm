MBRseg equ 7c0h ; 启动扇区段地址
OUTseg equ 800h ; 跳出启动扇区地址

jmp start

; Message全局变量定义
msg_welcome:
    db '---- Welcome To fzfOS ----','$'
msg_setp1:
    db 'Setp 1: MBR','$'
msg_setp2:
    db 'Setp 2: JMP OUT MBR','$'
msg_CSIP:
    db 'CS:????-IP:????','$'


start:
    ; 初始化数据段寄存器
    mov ax, MBRseg 
    mov ds, ax
    ; 设置字符串操作的源指针
    call welcome
    call newLine
    call newLine
    call InMBR
    call showCSIP
    call newLine
    call newLine
    
    jmp OUTseg:0

    call msg_setp2
    call showCSIP



welcome:
    mov si, msg_welcome
    call printStr
    ret

; 新的一行
newLine:
    mov ah, 0eh
    mov al, 0dh
    int 10h
    mov al, 0ah
    int 10h
    ret

; 在MBR中
InMBR:  
    mov si, msg_setp1
    call printStr
    call newLine
    ret    

printStr:
    ; 将字符拷贝到al
    mov al, [si]
    ; 判断是否末尾
    cmp al, '$'
    je over
    ; 设置10H中断的服务：在Teletype模式下显示字符
    mov ah, 0eh
    ; BIOS对显示器和屏幕所提供的服务程序
    int 10h
    ; 递增si的值
    inc si
    ; 递归
    jmp printStr

showCSIP:
    ; 将CS值放入ax
    mov ax, CS

    ; 高8位放入dl中, 解析后放入bx
    mov dl, ah
    call Hex2Bit

    ; cs高4位移到dl
    mov dl, bh
    call ASCII
    mov [msg_CSIP+3], dl

    ; cs高-4位
    mov dl, Bl
    call ASCII
    mov [msg_CSIP+4], dl

    mov dl,al
    call Hex2Bit
    mov dl, bh
    call ASCII
    mov  [msg_CSIP+5], dl

    mov dl, bl
    call ASCII
    mov  [msg_CSIP+6], dl

    ; IP值
    pop ax

    ; 高8位放入dl中, 解析后放入bx
    mov dl, ah
    call Hex2Bit

    ; cs高4位移到dl
    mov dl, bh
    call ASCII
    mov [msg_CSIP+11], dl

    ; cs高-4位
    mov dl, Bl
    call ASCII
    mov [msg_CSIP+12], dl

    mov dl,al
    call Hex2Bit
    mov dl, bh
    call ASCII
    mov  [msg_CSIP+13], dl

    mov dl, bl
    call ASCII
    mov  [msg_CSIP+14], dl

    ; 显示
    mov si, msg_CSIP
    call printStr
    ret

Hex2Bit:
    ; CS的高8位挪到dh
    mov dh, dl
    ; CS的高8位挪到bl
    mov bl, dl
    ; dh右移4位，只剩高4位CS值
    SHR dh,1
    SHR dh,1
    SHR dh,1
    SHR dh,1
    ; CS高4位移到bh
    mov bh, dh
    ; CS低4位移到bl
    and bl, 0fh
    ; bx 0101 CS 1100
    ret

ASCII:
    cmp dl,9
    ; 大于9则去LETTER
    jg LETTER
    ; 小于9直接+30h及为对应ASCII
    add dl,30h
    ret

LETTER:
    add dl,37H
    ret

over:
    ret

times 510-($-$$) db 0
db 0x55,0xaa