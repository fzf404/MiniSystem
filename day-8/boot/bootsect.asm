;*********************************************************
;****Linux操作系统Nasm引导程序:bootsect,制作者:Mr.Jiang***
;*************2020-10-17**********************************

%include "config.inc"


SETUPLEN equ 4                ;SETUP模块长度扇区数 
BOOTSEG  equ 0x07c0           ;MBR启动地址 
INITSEG  equ DEF_INITSEG      ;MBR程序挪动后的目标地址0x9000 
SETUPSEG equ DEF_SETUPSEG     ;SETUP模块放置地址0x9020 
SYSSEG   equ DEF_SYSSEG       ;SYSEM模块放置地址0x1000

SETUPSector   equ   2                    ;SETUP开始扇区号
SYSSector     equ   SETUPSector+SETUPLEN ;SYSTEM开始扇区号6
SYScylind     equ   7                    ;SYSTEM读到的柱面数(8*36>260扇区)


;root_dev定义在引导扇区508，509字节处
;当编译内核时，你可以在Makefile文件中指定自己的值。内核映像文件Image的
;创建程序tools/build会使用你指定的值来设置你的根文件系统所在设备号。

ROOT_DEV equ 0 ;根文件系统设备使用与系统引导时同样的设备(不指定)；
SWAP_DEV equ 0 ;交换设备使用与系统引导时同样的设备(不指定)；
 

;设备号=主设备号*256 + 次设备号（也即dev_no = (major<<8) + minor ）
;主设备号：1-内存,2-磁盘,3-硬盘,4-ttyx,5-tty,6-并行口,7-非命名管道）
;0x300 - /dev/hd0 - 代表整个第1个硬盘；
;0x301 - /dev/hd1 - 第1个盘的第1个分区；
;…
;0x304 - /dev/hd4 - 第1个盘的第4个分区；
;0x305 - /dev/hd5 - 代表整个第2个硬盘；
;0x306 - /dev/hd6 - 第2个盘的第1个分区；
;…
;0x309 - /dev/hd9 - 第2个盘的第4个分区；

;次设备号 = type*4 + nr，其中
;nr为0-3分别对应软驱A、B、C或D；type是软驱的类型（2:1.2MB或7:1.44MB等）。
;因为7*4+0=28=0x1c，所以/dev/PS0 指的是1.44MB A驱动器,其设备号是0x021c

jmp  start

start: 
     mov   ax,0        ;BIOS把引导扇区加载到0x7c00时,ss=0x00,sp=0xfffe
     mov   ss,ax       
     mov   sp,BOOTSEG  ;重新定义堆栈0x7c00
     
     mov   ax,BOOTSEG
     mov   ds,ax       ;为显示各种提示信息做准备
     mov   si, welcome 
     call  showmsg     ;打印"Linux"
     
     ;0x021c :/dev/PS0 - 1.44Mb 软驱A盘
     mov   word  [root_dev],0x021c   
     ;不指定,将软驱A设置成根文件系统设备保存在root_dev 
     

        ;1.将bootsect程序从0x07c0复制到0x9000（共1个扇区512B） 
        mov	ax, INITSEG
	mov	es,ax
	mov	cx, 256	
	sub	si,si
	sub	di,di
	rep                  ;循环挪动次数=512B/16B
	movsw                ;一次挪动16B， 
        jmp	INITSEG:go

;完成复制后，CPU将会跳转到这里 
go:	mov	ax,cs        ;到新的段地址后重新设置DS 
        mov     ds,ax        ;为显示各种提示信息做准备
        mov     si, msg1    
        call    showmsg      ;打印必要信息 
        
        mov   ax,cs        ;重新定义堆栈,栈顶:0x9ff00-12（参数表长度=0x9fef4
        mov   ss,ax        ;因为栈顶后面安排了一个长度12的自建驱动器参数表
        mov   sp,0xfef4    ;刨除掉SS段值0x9000*10后,SP的偏移量是0xfef4   

        ;2.将setup程序装载到0x9020（共4个扇区4*512B）
        mov     si, msg2
        call    showmsg 
        mov	ax, SETUPSEG            ;设置setup装载到的目标段地址
        mov	es,ax                   ;设置setup装载到的目标段地址    
        mov     byte [sector+11],SETUPSector    ;设置开始读取的扇区号:2 
        call    loadsetup
     
     
        ;3.将system程序装载到0x1000（共240个扇区4*512B）
        mov     si, msg3
        call    showmsg          
        mov	ax, SYSSEG            ;设置system装载到的目标段地址
        mov	es,ax                 ;设置system装载到的目标段地址
        mov     byte [sector+11],SYSSector      ;设置开始读取的扇区号:6
        call    loadsystem
        ;jmp     $                    ;调试 
       
        jmp     SETUPSEG:0            ;bootsect运行完毕，跳到setup:0x9020 


showmsg:                              ;打印字符串子程序     
     call  newline
     call  printstr
     call  newline 
     ret
     


;读软盘逻辑扇区2-5共4个扇区  
loadsetup:       
     call    read1sector
     MOV     AX,ES
     ADD     AX,0x0020                  ;一个扇区占512B=200H，刚好能被整除成完整的段
     MOV     ES,AX                      ;因此只需改变ES值，无需改变BX即可。
     inc     byte [sector+11]             ;读完一个扇区
     cmp     byte [sector+11],SETUPLEN+1+1 ;读到的结束扇区
     jne     loadsetup 
     ret
     
 


;读软盘逻辑扇区6-8*36共282个扇区
loadsystem:          
     call    read1sector
     MOV     AX,ES
     ADD     AX,0x0020           ;一个扇区占512B=200H，刚好能被整除成完整的段
     MOV     ES,AX               ;因此只需改变ES值，无需改变BX即可。 
     inc   byte [sector+11]       ;读完一个扇区
     cmp   byte [sector+11],18+1  ;最大扇区编号18,
     jne   loadsystem             
     mov   byte [sector+11],1
     inc   byte [header+11]       ;读完一个磁头
     cmp   byte [header+11],1+1   ;最大磁头编号1
     jne   loadsystem             
     mov   byte [header+11],0
     inc   byte [cylind+11]        ;读完一个柱面
     cmp   byte [cylind+11],SYScylind+1
     jne   loadsystem            

     ret
     
     
numtoascii:     ;将2位数的10进制数分解成ASII码才能正常显示。
                ;如柱面56 分解成出口ascii: al:35,ah:36
     mov ax,0
     mov al,cl  ;输入cl
     mov bl,10
     div bl
     add ax,3030h
     ret

readinfo:       ;实时显示当前读到哪个扇区、哪个磁头、哪个柱面 
     mov si,cylind
     call  printstr
     mov si,header
     call  printstr
     mov si,sector
     call  printstr
     ret


 
read1sector:  ;读1扇区通用程序。扇区参数由 sector header  cylind控制

       mov   cl, [sector+11]   ;为了能实时显示读到的物理位置
       call  numtoascii
       mov   [sector+7],al
       mov   [sector+8],ah

       mov   cl,[header+11]
       call  numtoascii
       mov   [header+7],al
       mov   [header+8],ah

       mov   cl,[cylind+11]
       call  numtoascii
       mov   [cylind+7],al
       mov   [cylind+8],ah

       MOV        CH,[cylind+11]    ;柱面开始读
       MOV        DH,[header+11]    ;磁头开始读
       mov        cl,[sector+11]    ;扇区开始读        

        call       readinfo        ;显示软盘读到的物理位置
        mov        di,0
retry:
        MOV        AH,02H    ; AH=0x02 : AH设置为0x02表示读取磁盘
        MOV        AL,1      ; 要读取的扇区数
        mov        BX,    0  ; ES:BX表示读到内存的地址
        MOV        DL,00H    ; 驱动器号,0表示软盘A,硬盘C:80H C 硬盘D:81H
        INT        13H       ; 调用BIOS 13号中断，磁盘相关功能
        JNC        READOK    ; 未出错则跳转到READOK，出错的话EFLAGS的CF位置1
           inc     di
           MOV     AH,0x00
           MOV     DL,0x00   ; A驱动器
           INT     0x13      ; 重置驱动器
           cmp     di, 5     ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃 
           jne     retry

           mov     si, Fyerror
           call    printstr
           call    newline
           jmp     exitread
READOK:    mov     si, FloppyOK
           call    printstr
           call    newline
exitread:
           ret




printstr:                  ;显示指定的字符串, 以'$'为结束标记 
      mov al,[si]
      cmp al,'$'
      je disover
      mov ah,0eh
      int 10h
      inc si
      jmp printstr
disover:
      ret

newline:                     ;显示回车换行
      mov ah,0eh
      mov al,0dh
      int 10h
      mov al,0ah
      int 10h
      ret

welcome db '(i)Linux-bootsect!','$'

msg1 db '1.bootsect to 0x9000','$'
msg2 db '2.setup to 0x9020','$'
msg3 db '3.system  to 0x1000','$'

cylind  db 'cylind:?? $',0    ; 设置开始读取的柱面编号
header  db 'header:?? $',0    ; 设置开始读取的磁头编号
sector  db 'sector:?? $',1,   ; 设置开始读取的扇区编号
FloppyOK db '-Floppy Read OK','$'
Fyerror db '-Floppy Read Error' ,'$'

times 512-2*3-($-$$) db 0     ;MBR程序中间部分用0填充 

swap_dev:
	dw SWAP_DEV     ;2Byte,存放交换系统所在设备号(init/main.c中会用)。
root_dev:                
	dw ROOT_DEV     ;2Byte,存放根文件系统所在设备号(init/main.c中会用)。

boot_flag: db 0x55,0xaa	  ;2Byte,MBR启动标记