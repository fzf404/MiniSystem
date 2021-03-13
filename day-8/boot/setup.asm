;******************************************************
;****Linux操作系统Nasm引导程序:setup,制作者:Mr.Jiang***
;*************2020-10-20*******************************

%include "config.inc"

INITSEG  EQU DEF_INITSEG   ;全部同bootsect 
SYSSEG   EQU DEF_SYSSEG	 
SETUPSEG EQU DEF_SETUPSEG 

jmp      start

start:

     mov   ax,SETUPSEG
     mov   ds,ax        ;为显示各种提示信息做准备
     mov   si, welcome 
     call  showmsg      ;打印"Welcome Linux"
     
;1.取扩展内存的大小值（KB）     
     mov   si, msg1
     call  showmsg   
     
     mov	ah,0x88    
     int	0x15      ;通过调用BIOS中断实现 
     mov	[2],ax    ;将扩展内存数值存在0x90002处（1个字）。
    
		

;2.检查显示方式（EGA/VGA）并取参数。
     mov   si, msg2
     call  showmsg
     
     	mov	ah,0x12
	mov	bl,0x10
	int	0x10
	mov	[8],ax
	mov	[10],bx     ;0x9000A =安装的显示内存；0x9000B=显示状态(彩/单色)
	mov	[12],cx     ;0x9000C =显示卡特性参数。
	
	mov ax,0x5019       ;在ax中预置屏幕默认行列值（ah = 80列；al=25行）。
	mov [14],ax         ;保存屏幕当前行列值（0x9000E，0x9000F）。
	                                 
	mov	ah,0x03	    ;取屏幕当前光标位置
	xor	bh,bh
	int	0x10		
	mov	[0],dx	    ;保存在内存0x90000处（2字节）	


;3.取显示卡当前显示模式
        mov   si, msg3
        call  showmsg
      
      	mov	ah,0x0f
	int	0x10
	mov	[4],bx	    ;0x90004(1字)存放当前页
	mov	[6],ax	    ;0x90006存放显示模式；0x90007存放字符列数。
	
;4.取第一个硬盘的信息（复制硬盘参数表）。
      ;第1个硬盘参数表的首地址竟然是中断0x41的中断向量值
      ;而第2个硬盘参数表紧接在第1个表的后面，中断0x46的向量向量值
      ;也指向第2个硬盘的参数表首址。表的长度是16个字节。
        mov   si, msg4
        call  showmsg

        push    ds           ;由于复制数据要修改DS的值，因此暂存起来 
      	mov	ax,0x0000
	mov	ds,ax
	lds	si,[4*0x41]
	mov	ax,INITSEG
	mov	es,ax
	mov	di,0x0080     ;0x90080处存放第1个硬盘的表
	mov	cx,0x10
	rep
	movsb
	
;5.取第2个硬盘的信息（复制硬盘参数表）。  
        pop   ds             ;恢复DS为本段setup段地址，才能正常打印字符串 
        mov   si, msg5
        call  showmsg
        
        push    ds           ;由于复制数据要修改DS的值，因此暂存起来
      	mov	ax,0x0000
	mov	ds,ax
	lds	si,[4*0x46]
	mov	ax,INITSEG
	mov	es,ax
	mov	di,0x0090     ;0x90090处存放第2个硬盘的表
	mov	cx,0x10
	rep
	movsb
	
;6.检查系统是否有第2个硬盘。如果没有则把第2个表清零。

        pop   ds              ;恢复DS的值，才能正常打印字符串
        mov   si, msg6
        call  showmsg
        
      	mov	ax,0x01500
	mov	dl,0x81
	int	0x13
	jc	no_disk1
	cmp	ah,3
	je	is_disk1
no_disk1:
	mov	ax,INITSEG
	mov	es,ax
	mov	di,0x0090
	mov	cx,0x10
	mov	ax,0x00
	rep
	stosb
is_disk1:

;7.现在要进入保护模式了 
        mov   si, msg7
        call  showmsg
       
        mov   si, msg8
        call  showmsg
        
        mov   cx,14 
line:   call  newline       ;循环换行,清除一些屏幕显示    
        loop  line
        
        cli                 ;禁用16位中断
        
;8.将system模块移到正确的位置。
        ;bootsect引导程序会把 system 模块读入到内存 0x10000（64KB）开始的位置
        ;下面这段程序是再把整个system模块从 0x10000移动到 0x00000位置。即把从
        ;0x10000到0x8ffff 的内存数据块（512KB）整块地向内存低端移动了64KB字节。
        call  mov_system    ;会覆盖实模式下的中断区，BIOS中断再也无法使用 

	

;9.装载寄存器IDTR和GDTR 
	mov	ax,SETUPSEG	;ds指向本程序(setup)段
	mov	ds,ax
	lidt	[idt_48]	;加载IDTR 
	lgdt	[gdt_48]	;加载GDTR
	
;10.现开启A20地址线	
       
       call empty_8042          ;8042状态寄存器，等待输入缓冲器空。
                                ;只有当输入缓冲器为空时才可以对其执行写命令。
       mov al,0xD1              ;0xD1命令码-表示要写数据到
       out 0x64,al              ;8042的P2端口。P2端口位1用于A20线的选通。
       call empty_8042          ;等待输入缓冲器空，看命令是否被接受。
       mov al,0xDF              ;A20 on ! 选通A20地址线的参数。
       out 0x60,al              ;数据要写到0x60口。
       call empty_8042          ;若此时输入缓冲器为空，则表示A20线已经选通。
       
;11.设置8259A中断芯片,即int 0x20--0x2F   
       call  set_8259A                
       
;12.打开保护模式PE开关  
       mov	ax,0x0001	;保护模式比特位(PE)
       lmsw	ax		;就这样加载机器状态字!  
       

       
;13.跳转触发到32位保护模式代码
       ;jmp dword 1*8:inprotect+SETUPSEG*0x10 ;保护模式下的段基地址:0x90200  
                               ;这句是调试验证进入保护模式后系统是否正常                                
       jmp dword 1*8:0         ;setup程序到此结束 
                               ;跳转到0x00000,也即system程序(head.asm)                                 
       
    
;把整个system模块从 0x10000移动到 0x00000位置。 
mov_system:
        mov	ax,0x0000
	cld			;'direction'=0, movs moves forward
do_move:
	mov	es,ax		;es:di是目的地址(初始为0x0:0x0)
	add	ax,0x1000
	cmp	ax,0x9000       ;已把最后一段（从0x8000段开始的64KB）移动完？
	jz	end_move
	mov	ds,ax		;ds:si是源地址(初始为0x1000:0x0)
	sub	di,di
	sub	si,si
	mov 	cx,0x8000      ;移动0x8000字（64KB字节）。
	rep
	movsw
	jmp	do_move
end_move:  ret
 

;设置8259A中断芯片 
set_8259A: 	
        mov	al,0x11		 
	out	0x20,al	 
	dw	0x00eb,0x00eb	;jmp $+2, jmp $+2
	out	0xA0,al	 
	dw	0x00eb,0x00eb
	mov	al,0x20        ;Linux系统硬件中断号被设置成从0x20开始
	out	0x21,al
	dw	0x00eb,0x00eb
	mov	al,0x28		;start of hardware int's 2 (0x28)
	out	0xA1,al
	dw	0x00eb,0x00eb
	mov	al,0x04		;8259-1 is master
	out	0x21,al
	dw	0x00eb,0x00eb
	mov	al,0x02		;8259-2 is slave
	out	0xA1,al
	dw	0x00eb,0x00eb
	mov	al,0x01		;8086 mode for both
	out	0x21,al
	dw	0x00eb,0x00eb
	out	0xA1,al
	dw	0x00eb,0x00eb
	mov	al,0xFF		;屏蔽主芯片所有中断请求。
	out	0x21,al
	dw	0x00eb,0x00eb
	out	0xA1,al         ;屏蔽从芯片所有中断请求。 
        ret 
 
empty_8042:                     ;只有当输入缓冲器为空时（状态寄存器位1 = 0）
                                ;才可以对其执行写命令。
	dw	0x00eb,0x00eb
	in	al,0x64	        ;读AT键盘控制器状态寄存器。
	test	al,2		;测试位1，输入缓冲器满？
	jnz	empty_8042	;yes - loop
	ret 
     

idt_48:  dw 0x800              ;这里不能像书上设置成0,否则VMWARE调试会出错！ 
         dw 0,0                ;IDT全部中断都设置成无效 
gdt_48:  dw 0x800              ;GDT长度设置为 2KB（0x7ff）表中共可有 256项。
         dw 512+gdt,0x9        ;GDT物理地址：0x90200 + gdt
        
                
         
gdt:
	dw	0,0,0,0		;0#描述符，它是空描述符

	dw	0x07FF		;8Mb - limit=2047 (2048*4096=8Mb)
	dw	0x0000		;base address=0
        dw	0x9A00		;code read/exec 代码段为只读、可执行
	dw	0x00C0		;granularity=4096, 386 颗粒度为4096，32位模式

	dw	0x07FF		;8Mb - limit=2047 (2048*4096=8Mb)
	dw	0x0000		;base address=0
	dw	0x9200		;data read/write  数据段为可读可写
	dw	0x00C0		;granularity=4096, 386颗粒度为4096，32位模式

showmsg: 
     call  newline
     call  printstr
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

welcome db '(ii) Welcome Linux---setup!',0x0d,0x0a,'$'

msg1 db '1.Get memory size','$'
msg2 db '2.Check for EGA/VGA and some config parameters','$'
msg3 db '3.Get video-card data','$'
msg4 db '4.Get hd0 data','$'
msg5 db '5.Get hd1 data','$'
msg6 db '6.Check that there IS a hd1','$'
msg7 db '7.Move system from 0x10000 to 0x00000','$'
msg8 db '8.Now Ready to Protect Mode!','$' 


[bits 32]
inprotect:                          ;测试进入保护模式后是否正常                     
mov eax,2*8 ;加载数据段选择子(0x10)
mov ds,eax

mov  esi,sysmsg+SETUPSEG*0x10   ;保护模式DS=0,数据需跨过段基址用绝对地址访问 
mov  edi, 0xb8000+18*160        ;显示在第18行,显卡内存地址也需用绝对地址访问 
call printnew

mov  esi,promsg+SETUPSEG*0x10
mov  edi, 0xb8000+20*160        ;显示在第20行
call printnew

mov  esi,headmsg+SETUPSEG*0x10
mov  edi, 0xb8000+22*160        ;显示在第22行
call printnew

jmp  $


printnew:                       ;保护模式下显示字符串, 以'$'为结束标记
        mov  bl ,[ds:esi]
        cmp  bl, '$'
        je   printover
        mov  byte [ds:edi],bl
        inc  edi
        mov  byte [ds:edi],0x0c  ;字符红色 
        inc  esi
        inc  edi
        jmp  printnew
printover:
        ret



sysmsg  db '(iii) Welcome Linux---system!','$'
promsg  db '1.Now Already in Protect Mode','$'
headmsg db '2.Run head.asm in system program','$'

times 512*4-($-$$) db 0    ;控制setup最终的机器代码长度为4个扇区