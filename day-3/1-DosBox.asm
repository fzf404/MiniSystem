; %define   com              ; 调试Flag
%ifdef    com
orgaddr   equ   100h        ; COM调试
%else
orgaddr   equ   7c00h       ; MBR启动
%endif


jmp start

welcome db 'Welcome To fzfOS','$'

start:
    mov ax, cs
    add ax, orgaddr/10h     ; 设置DS寄存器为数据偏移地址
    mov ds, ax
    mov es, ax

    mov  si, welcome
    call printstr

    %ifdef    com           ; COM调试需要调用DOS返回中断
    mov ah, 4ch
    int 21h
    %endif                  ; .COM程序将在此顺利返回Dos系统

    jmp $                   ; 如果是MBR启动，将在此停止运行


printstr:                  ; 显示指定的字符串, 以'$'为结束标记
    mov al,[si]
    cmp al,'$'
    je disover
    mov ah,0eh
    int 10h
    inc si
    jmp printstr

disover:
      ret

times 510-($-$$) db 0
      db 0x55,0xaa