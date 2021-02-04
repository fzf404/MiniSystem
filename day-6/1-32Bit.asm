NumSector equ 6     ; 软盘最大扇区编号
NumHeader equ 0
NumCylind equ 0

MBRseg equ 7c0h ; 启动扇区段地址
OUTseg equ 800h ; 跳出启动扇区地址
DPTseg equ 7e0h ; DPT段地址

jmp start

; Message全局变量定义
msg_welcome:
    db '--** Welcome To fzfOS **--','$'
msg_setp1:
    db 'Setp 1: MBR','$'
msg_Mem:
    db 'Value of ','$'
msg_CS:
    db 'CS:????H','$'
msg_Load:
    db 'Loading Code...','$'

cylind db 'cylind:?? $',0   ; 柱面
header db 'header:?? $',0   ; 磁头
sector db 'sectpy:?? $',2   ; 扇区
fyOK db 'Read OK','$'
fyError db 'Read Error' ,'$'

start:
    call inMBR
    call floppyLoad
    jmp OUTseg:0    ; 跳出MBR

inMBR: 
    ; 初始化数据段寄存器
    mov ax, MBRseg 
    mov ds, ax
    ; 为读数据到软盘做准备
    mov ax, OUTseg
    mov es, ax      ; 读软盘需要ES:BX

    call inMBRShow
    call showCS
    call newLine
    call newLine
    call showLoad
    ret   

inMBRShow:
    mov si, msg_welcome
    call printStr
    call newLine
    call newLine
    mov si, msg_setp1
    call printStr
    call newLine
    ret

showLoad:
    mov si, msg_Load
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
over:
    ret

; 新的一行
newLine:
    mov ah, 0eh
    mov al, 0dh
    int 10h
    mov al, 0ah
    int 10h
    ret

showCS:
    ; 将CS值放入ax
    mov ax, cs

    ; 高8位放入dl中, 解析后放入bx
    mov dl, ah
    call Hex2Bit

    ; cs高4位移到dl
    mov dl, bh
    call ASCII
    mov [msg_CS+3], dl

    ; cs高-4位
    mov dl, Bl
    call ASCII
    mov [msg_CS+4], dl

    mov dl,al
    call Hex2Bit
    mov dl, bh
    call ASCII
    mov  [msg_CS+5], dl

    mov dl, bl
    call ASCII
    mov  [msg_CS+6], dl

    mov si, msg_Mem
    call printStr
    mov si, msg_CS
    call printStr
    ret

; 一比特十六进制转为ASCII
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

; 取Byte的高/低4位,IN_DL,OUT_BH+BL
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


; -------- 读扇区 --------
floppyLoad:
    call readSector
    mov ax, es
    add ax, 0x0020
    mov es, ax      ; 一扇区512B, 200h
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

; 数字转ASCII 传入cl
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

    mov cl, [sector+11]
    ; 将数字转换成ASCII，替换掉？
    call num2ascii
    mov   [sector+7],al
    mov   [sector+8],ah

    mov cl, [header+11]
    call num2ascii
    mov   [header+7],al
    mov   [header+8],ah

    mov cl, [cylind+11]
    call num2ascii
    mov   [cylind+7],al
    mov   [cylind+8],ah

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

    mov si, fyError     ; 错误处理
    call printStr
    call newLine
    jmp exitRead

ReadOK:    
    mov     si, fyOK
    call    printStr
    call    newLine

exitRead:
    ret

times 510-($-$$) db 0
db 0x55,0xaa

; -------- 第二扇区分割线 --------
jmp    nextProgram

GDTsize dw 32-1
GDTbase dd 0x00007e00

msg_setp2:
    db 'Setp 2: JMP OUT MBR','$'
msg_Mem2:
    db 'Value ','$'
msg_CS2:
    db 'CS:????H','$'
msg_IP:
    db 'IP:????H','$'
msg_Step3:
    db 'Setp3: Enter Protect Mode', '$'

nextProgram:
    ; 跳转后使用新的地址段
    mov ax, OUTseg
    sub ax,20h 
    mov ds, ax

    call outMBR
    call showCS2
    call showprotect

    ; 创建dpt
    mov ax,DPTseg
    ; gpt 选址
    mov es,ax
    call CreatDPT

    jmp next

CreatDPT:
    lgdt [GDTsize]  ; GDP的地址和大小写入GDTR

    ; 保护模式描述符
    mov dword [es:0x00], 0x00
    mov dword [es:0x04], 0x00
    mov dword [es:0x08], 0x8000ffff
    mov dword [es:0x0c], 0x00409800
    mov dword [es:0x10], 0x0000ffff 
    mov dword [es:0x14], 0x00c09200 
    mov dword [es:0x18], 0x00007a00
    mov dword [es:0x1c], 0x00409600
    ret

outMBR:
    call newLine2
    call newLine2
    ; ds已经加200h,msg需要减去512字节
    mov  si, msg_setp2
    call printStr2
    call newLine2
    mov  si, msg_Mem2
    call printStr2
    ret

showprotect:
    call newLine2
    call newLine2
    mov si, msg_Step3
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

next:
    in al,0x92    ; 打开a20地址线
    or al,0000_0010B
    out 0x92,al
    cli         ; 禁止中断
    mov eax,cr0 ; 打开保护模式开关
    or eax,1
    mov cr0,eax

    ; 进入保护模式
    jmp dword 0x0008:inprotectmode-512  ; 16位的描述符选择子：32位偏移;这里需要扣除掉512B的MBR偏移量

[bits 32]
inprotectmode:

    mov ax,00000000000_10_000B          ; 加载数据段选择子(0x10)
    mov ds,ax
    ; 验证保护模式下的数据段设置正确
    mov byte [0xb8000+20*160+0x00],'P'  ;屏幕第20行开始显示
    mov byte [0xb8000+20*160+0x01],0x0c
    mov byte [0xb8000+20*160+0x02],'R'
    mov byte [0xb8000+20*160+0x03],0x0c
    mov byte [0xb8000+20*160+0x04],'O'
    mov byte [0xb8000+20*160+0x05],0x0c
    mov byte [0xb8000+20*160+0x06],'T'
    mov byte [0xb8000+20*160+0x07],0x0c
    mov byte [0xb8000+20*160+0x08],'E'
    mov byte [0xb8000+20*160+0x09],0x0c
    mov byte [0xb8000+20*160+0x0a],'C'
    mov byte [0xb8000+20*160+0x0b],0x0c
    mov byte [0xb8000+20*160+0x0c],'T'
    mov byte [0xb8000+20*160+0x0d],0x0c
    mov byte [0xb8000+20*160+0x0e],'-'
    mov byte [0xb8000+20*160+0x0f],0x0c
    mov byte [0xb8000+20*160+0x10],'M'
    mov byte [0xb8000+20*160+0x11],0x0c
    mov byte [0xb8000+20*160+0x12],'O'
    mov byte [0xb8000+20*160+0x13],0x0c
    mov byte [0xb8000+20*160+0x14],'D'
    mov byte [0xb8000+20*160+0x15],0x0c
    mov byte [0xb8000+20*160+0x16],'E'
    mov byte [0xb8000+20*160+0x17],0x0c
    mov byte [0xb8000+20*160+0x18],' '
    mov byte [0xb8000+20*160+0x19],0x0c
    mov byte [0xb8000+20*160+0x1a],'!'
    mov byte [0xb8000+20*160+0x1b],0x0c
    mov byte [0xb8000+20*160+0x1c],'!'
    mov byte [0xb8000+20*160+0x1d],0x0c
    mov byte [0xb8000+20*160+0x1e],'!'
    mov byte [0xb8000+20*160+0x1f],0x0c

    ; 通过堆栈操作,验证保护模式下的堆栈段设置正确
    mov ax, 00000000000_11_000B ; 加载堆栈段选择子(0x11)
    mov ss, ax                  ; 7a00-7c00为此次设计的堆栈区
    mov esp,0x7c00              ; 7c00固定地址为栈底，
                                ; 7a00为栈顶的最低地址（通过载堆栈段选择子的段界限值设置）
    mov  ebp,esp                ; 保存堆栈指针
    push byte '$'               ; 压入立即数


    sub ebp,4

    cmp ebp,esp ; 判断ESP是否减4
    jnz over3    ; 如果堆栈工作正常则打印出pop出来的值和其它字符

    pop eax

    mov byte [0xb8000+22*160+0x00],'S'
    mov byte [0xb8000+22*160+0x01],0x0c
    mov byte [0xb8000+22*160+0x02],'t'
    mov byte [0xb8000+22*160+0x03],0x0c
    mov byte [0xb8000+22*160+0x04],'a'
    mov byte [0xb8000+22*160+0x05],0x0c
    mov byte [0xb8000+22*160+0x06],'c'
    mov byte [0xb8000+22*160+0x07],0x0c
    mov byte [0xb8000+22*160+0x08],'k'
    mov byte [0xb8000+22*160+0x09],0x0c
    mov byte [0xb8000+22*160+0x0a],':'
    mov byte [0xb8000+22*160+0x0b],0x0c
    mov byte [0xb8000+22*160+0x0c],al     ;打印出pop出来的值
    mov byte [0xb8000+22*160+0x0d],0x0c
    mov byte [0xb8000+22*160+0x0e],','
    mov byte [0xb8000+22*160+0x0f],0x0c
    mov byte [0xb8000+22*160+0x10],'O'
    mov byte [0xb8000+22*160+0x11],0x0c
    mov byte [0xb8000+22*160+0x12],'K'
    mov byte [0xb8000+22*160+0x13],0x0c
    mov byte [0xb8000+22*160+0x14],'!'
    mov byte [0xb8000+22*160+0x15],0x0c

over3:
    jmp $
