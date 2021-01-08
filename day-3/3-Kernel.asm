; %define   com             ; 调试Flag
%ifdef    com
Loaderseg   equ   100h        ; COM调试
%else
Loaderseg   equ   800h        ; MBR启动
%endif
jmp    kernal

msg_setp2:
    db 'Setp 2: JMP OUT MBR','$'
msg_Kernal:
    db '--** Now In Kernal! **--','$'
msg_Mem2:
    db 'Value ','$'
msg_CS2:
    db 'CS:????H','$'
msg_IP:
    db 'IP:????H','$'
msg_End:
    db 'End...','$'

kernal:
    ; 跳转后使用新的地址段
    mov ax, Loaderseg
    mov ds, ax
    mov es, ax
    call outMBR
    call showCS2
    call end
    jmp $       ;死循环

outMBR:
    call newLine2
    call newLine2
    ; ds已经加200h,msg需要减去512字节
    mov  si, msg_setp2
    call printStr2
    call newLine2
    call newLine2
    mov si, msg_Kernal
    call printStr2
    call newLine2
    mov  si, msg_Mem2
    call printStr2
    ret

showCS2:
    ; 将CS值放入ax
    mov ax, cs

    ; 高8位放入dl中, 解析后放入bx
    mov dl, ah
    call Hex2Bit2

    ; cs高4位移到dl
    mov dl, bh
    call ASCII2
    mov [msg_CS2+3], dl

    ; cs高-4位
    mov dl, bl
    call ASCII2
    mov [msg_CS2+4], dl

    mov dl,al
    call Hex2Bit2
    mov dl, bh
    call ASCII2
    mov  [msg_CS2+5], dl

    mov dl, bl
    call ASCII2
    mov  [msg_CS2+6], dl

    ; 显示
    mov si, msg_CS2
    call printStr2
    call newLine2

    ; 显示IP的值
    pop ax
    push ax
    ; 高8位放入dl中, 解析后放入bx
    mov dl, ah
    call Hex2Bit2

    ; cs高4位移到dl
    mov dl, bh
    call ASCII2
    mov [msg_IP+3], dl

    ; cs高-4位
    mov dl, bl
    call ASCII2
    mov [msg_IP+4], dl

    mov dl,al
    call Hex2Bit2
    mov dl, bh
    call ASCII2
    mov [msg_IP+5], dl

    mov dl, bl
    call ASCII2
    mov [msg_IP+6], dl

    ; 显示
    mov  si, msg_Mem2
    call printStr2
    mov si, msg_IP
    call printStr2
    call newLine2
    ret


printStr2:
    ; 将字符拷贝到al
    mov al, [si]
    ; 判断是否末尾
    cmp al, '$'
    je over2
    ; 设置10H中断的服务：在Teletype模式下显示字符
    mov ah, 0eh
    ; BIOS对显示器和屏幕所提供的服务程序
    int 10h
    ; 递增si的值
    inc si
    ; 递归
    jmp printStr2

over2:
    ret

; 新的一行
newLine2:
    mov ah, 0eh
    mov al, 0dh
    int 10h
    mov al, 0ah
    int 10h
    ret
; 一比特十六进制转为ASCII
ASCII2:
    cmp dl,9
    ; 大于9则去LETTER
    jg LETTER2
    ; 小于9直接+30h及为对应ASCII
    add dl,30h
    ret

LETTER2:
    add dl,37H
    ret

; 取Byte的高/低4位,IN_DL,OUT_BH+BL
Hex2Bit2:
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

end:
    mov si, msg_End
    call printStr2
    ret
