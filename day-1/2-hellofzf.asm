MBRset equ 7c0h ; 启动扇区段地址

jmp start

hello:
    db '---- Welcome To fzfOS ----','$'

start:
    ; 初始化数据段寄存器
    mov ax, MBRset 
    mov ds, ax
    ; 设置字符串操作的源指针
    mov si, hello
    ; 打印字符串
    call printStr

printStr:
    ; 将字符拷贝到al
    mov al, [si]
    ; 判断是否末尾
    cmp al, '$'
    je over
    ; 设置10H中断的服务：在Teletype模式下显示字符
    mov ah,0eh
    ; BIOS对显示器和屏幕所提供的服务程序
    int 10h
    ; 递增si的值
    inc si
    ; 递归
    jmp printStr

over:
    ret