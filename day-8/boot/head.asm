;*********************************************************
;****Linux操作系统Nasm引导程序:head,制作者:Mr.Jiang***
;*************2020-10-27**********************************

%include "config.inc"

SETUPSEG equ DEF_SETUPSEG  ;全部同bootsect和setup 
SYSSEG   equ DEF_SYSSEG

_pg_dir  equ  0x0000     ;页目录地址,大小4KB. 

pg0      equ  0x1000     ;第1个页表地址,大小4KB. 
pg1      equ  0x2000     ;第2个页表地址,大小4KB.
pg2      equ  0x3000     ;第3个页表地址,大小4KB.
pg3      equ  0x4000     ;第4个页表地址,大小4KB.

_tmp_floppy_area   equ  0x5000   ;软盘缓冲区地址. 
len_floppy_area   equ  0x400     ;软盘缓冲区大小1KB 

[bits 32]                        ;指定代码为32位保护模式   

jmp start

;这条伪指令不会执行任何操作，只在编译的时候起填充数字作用。 
times _tmp_floppy_area+len_floppy_area-($-$$) db 0  ;
;一个语句实现页目录和页表地址区域清0，省去程序后面Linux源代码中的清0部分 
;使head程序从0x5000+0x400位置开始放置（仅除第一条jmp指令外）。 


;这里已经处于32位运行模式,首先设置ds,es,fs,gs为setup.s中构造的内核数据段
;并将堆栈放置在stack_start指向的user_stack数组区，然后使用本程序后面定义的
;新中断描述符表和全局段描述表。新全局段描述表中初始内容与setup.s中的基本一样，
;仅段限长从8MB修改成了16MB。stack_start定义在kernel/sched.c。它指向user_stack
;数组末端的一个长指针。设置这里使用的栈，姑且称为系统栈。但在移动到任务0执行
;（init/main.c中137行）以后该栈就被用作任务0和任务1共同使用的用户栈了。

start:                          
mov eax,2*8                     ;加载数据段选择子(0x10)
mov ds,eax                      ;把所有数据类段寄存器全部指向GDT的数据段地址 
mov es,eax 
mov fs,eax
mov gs,eax
mov ss,eax


mov  esi,sysmsg                 ;保护模式DS=0,数据用绝对地址访问
mov  cl, 0x0c                   ;颜色红 
mov  edi, 0xb8000+13*160        ;显示在第18行,显卡内存地址也需用绝对地址访问
call printnew   

mov  esi,promsg 
mov  cl, 0x0c
mov  edi, 0xb8000+15*160        ;显示在第20行
call printnew

mov  esi,headmsg 
mov  cl, 0x0c
mov  edi, 0xb8000+16*160        ;显示在第22行   
call printnew

mov  esp,0x1e25c                ; 重新设置堆栈，暂时设置值参见书
                                ;《Linux内核设计的艺术_图解Linux操作系统架构
                                ; 设计与实现原理》P27
                                ; Linus源程序中是lss _stack_start,%esp 
                                ; _stack_start,。定义在kernel/sched.c，82-87行
                                ; 它是指向 user_stack数组末端的一个长指针                            
call setup_idt
call setup_gdt  

jmp  1*8:newgdt                   ;改变CS的值来触发新GDT表生效                      
     nop
     nop
newgdt:                         ;如能正常打印则表明程序正常运行,新GDT表无问题 
mov  esi,gdtmsg                 ;保护模式DS=0,数据用绝对地址访问
mov  cl, 0x09                   ;颜色蓝
mov  edi, 0xb8000+17*160        ;显示在第18行,显卡内存地址也需用绝对地址访问
call printnew    


;call test_keyboard            ;开键盘中断并按键测试,显示外部中断体系正常

sti ;开中断
int 00h                        ;手工系统中断调用,测试显示内部中断体系也正常 
cli ;关掉中断 
 

call  A20open
mov  esi,a20msg                 ;保护模式DS=0,数据用绝对地址访问
mov  cl, 0x09                   ;蓝色
mov  edi, 0xb8000+19*160        ;显示在第18行,显卡内存地址也需用绝对地址访问
call printnew
  

;前面3个入栈0值分别表示main函数的参数envp、argv指针和argc，但main()没有用到。
;push _main入栈操作是模拟调用main时将返回地址入栈的操作，所以如果main.c程序
;真的退出时，就会返回到这里的标号L6处继续执行下去，也即死循环。push _main将
;main.c的地址压入堆栈。这样，在设置分页处理（setup_paging）结束后执行'ret'
;返回指令时就会将main.c;程序的地址弹出堆栈，并去执行main.c程序了。

push 0 ;These are the parameters to main :-)
push 0 ;这些是调用main程序的参数（指init/main.c）。
push 0  
push L6 ;return address for main, if it decides to.
push _main ;'_main'是编译程序对main的内部表示方法。
jmp  setup_paging   ;这里用的JMP而不是call，就是为了在setup_paging结束后的
                    ;ret指令能去执行C程序的main() 
L6:
jmp L6 ;main程序绝对不应该返回到这里。不过为了以防万一，
     ;所以添加了该语句。这样我们就知道发生什么问题了。
     
     
     


_main:      ;这里暂时模拟出C程序main() 
     mov  esi,mainmsg                ;保护模式DS=0,数据用绝对地址访问
     mov  cl, 0x09                   ;蓝色
     mov  edi, 0xb8000+22*160        ;指定显示在某行,显卡内存地址需用绝对地址
     call printnew                   ;0xb8000为字符模式下显卡映射到的内存地址 
     ret  
     
     
test_keyboard:       ; 测试键盘中断
mov al, 11111101b  ; 开启键盘中断开关 
out 021h, al       ; 主8259, OCW1.
dw  0x00eb,0x00eb   ;时延
mov al, 11111111b   ; 屏蔽从芯片所有中断请求
out 0A1h, al       ; 从8259, OCW1.
dw	0x00eb,0x00eb  ;时延
ret


;Linux将内核的内存页表直接放在页目录之后，使用了4个表来寻址16 MB的物理内存。
;如果你有多于16 Mb的内存，就需要在这里进行扩充修改。
;每个页表长为4KB（1页内存页面），而每个页表项需要4个字节，因此一个页表共可存
;1024个表项。一个页表项寻址4KB的地址空间，则一个页表就可以寻址4MB的物理内存。
setup_paging:

;首先对5页内存（1页目录 + 4页页表）清零。由于在程序第一行已经实现，此处可省。 
;mov ecx,10
;xor eax,eax
;xor edi,edi  ;页目录从0x000地址开始。  
;cld          ;edi按递增方向 
;rep
;stosd         ;eax内容存到es:edi所指内存位置处，且edi增4。

;下面4句设置页目录表中的项。因为内核共有4个页表，所以只需设置4项(索引)。
;页目录项的结构与页表中项的结构一样，4个字节为1项。
;例如"pg0+7"表示：0x00001007，是页目录表中的第1项。
;则第1个页表所在的地址 = 0x00001007 & 0xfffff000 = 0x1000；
;第1个页表的属性标志 = 0x00001007&0x00000fff = 0x07,表示该页存在、用户可读写。
;一句指令就把页表的地址和属性完全完整定义了，这个写法设计得有点巧妙。    
mov dword [_pg_dir],pg0+7       ;页表0索引 将直接覆盖0地址处的3字节长度jmp指令 
mov dword [_pg_dir+4],pg1+7     ;页表1索引
mov dword [_pg_dir+8],pg2+7     ;页表2索引
mov dword [_pg_dir+12],pg3+7    ;页表3索引 


;下面填写4个页表中所有项的内容，共有：4(页表)*1024(项/页表)=4096项(0-0xfff)，
;也即能映射物理内存 4096*4Kb = 16Mb。
;每项的内容是：当前项所映射的物理内存地址 + 该页的标志（这里均为7）。
;填写使用的方法是从最后一个页表的最后一项开始按倒退顺序填写。
;每一个页表中最后一项在表中的位置是1023*4 = 4092.
;此最后一页的最后一项的位置就是pg3+4092。
mov edi,pg3+4092;edi->最后一页的最后一项。
mov eax,0xfff007;16Mb - 4096 + 7 (r/w user,p) */
;最后1项对应物理内存页面的地址是0xfff000，
;加上属性标志7，即为0xfff007。
std ;方向位置位，edi值递减(4字节)。
goon:
stosd  
sub eax,0x1000;每填写好一项，物理地址值减0x1000。
jge goon ;如果小于0则说明全添写好了。  jge是大于或等于转移指令


;现在设置页目录表基址寄存器cr3，指向页目录表。cr3中保存的是页目录表的物理地址
;再设置启动使用分页处理（cr0的PG标志，位31）
xor eax,eax ;pg_dir is at 0x0000 */ # 页目录表在0x0000处。
mov cr3,eax ;cr3 - page directory start */
mov eax,cr0
or eax,0x80000000  ;添上PG标志。
mov cr0,eax ; set paging (PG) bit */

# 软盘缓冲区: 共保留1024项，填充数值0。在程序第一行已经实现，此处可省。
;mov ecx,1024/4; 
;xor eax,eax
;mov edi,_tmp_floppy_area  ;软盘缓冲区从0x5000地址开始。
;cld                      ;edi按递增方向
;rep
;stosd                    ;eax内容存到es:edi所指内存位置处，且edi增4。


mov  esi,pagemsg                ;保护模式DS=0,数据用绝对地址访问
mov  cl, 0x09                   ;蓝色字体 
mov  edi, 0xb8000+20*160        ;指定显示在某行,显卡内存地址也需用绝对地址访问
call printnew 
 
mov  esi,asmmsg                 ;保护模式DS=0,数据用绝对地址访问
mov  cl, 0x09                   ;蓝色字体
mov  edi, 0xb8000+21*160        ;指定显示在某行,显卡内存地址也需用绝对地址访问     
call printnew
     
ret  ;setup_paging这里用的是返回指令ret。
;该返回指令的另一个作用是将压入堆栈中的main程序的地址弹出，
;并跳转到/init/main.c程序去运行。本程序到此就真正结束了。      
 
;用于测试A20地址线是否已经开启。采用的方法是向内存地址0x000000处写入任意
;一个数值，然后看内存地址0x100000(1M)处是否也是这个数值。如果一直相同的话，
;就一直比较下去，也即死循环表示地址A20线没有选通，就不能使用1MB以上内存。
A20open:
       xor   eax, eax
       inc   eax 
       mov   [0x000000],eax   
       cmp   eax,[0x100000]
       je    A20open
       ret

printnew:                       ;保护模式下显示字符串, 以'$'为结束标记
        mov  bl ,[ds:esi]
        cmp  bl, '$'
        je   printover
        mov  byte [ds:edi],bl
        inc  edi
        mov  byte [ds:edi],cl  ;字符颜色
        inc  esi
        inc  edi
        jmp  printnew
printover:
        ret

setup_idt:
          ;暂时将所有的中断全部指向一个中断服务程序:ignore_int 
          lea  edx,[ignore_int]   ;将ignore_int的有效地址（偏移值）值送edx 
          mov  eax,0x00080000  ;将选择符0x0008置入eax的高16位中。
          mov  ax,dx           ;selector = 0x0008 = cs */
                               ;偏移值的低16位置入eax的低16位中。此时eax含有门
                               ;描述符低4字节的值。
          mov dx,0x8E00        ;interrupt gate - dpl=0, present 
                               ;此时edx含有门描述符高4字节值,偏移地址高16位是0 
          lea edi,[_idt]       ;_idt是中断描述符表的地址。
          ;以上为单独一个中断描述符的设置方法 
          
          mov ecx,256          ;IDT表中创建256个中断描述符 
;将上面的中断描述符重复放置256次，让所有的中断全部指向一个中断服务程序:哑中断
 rp_sidt:
          mov [edi],eax       ;将哑中断门描述符存入表中。
          mov [edi+4],edx     ;edx内容放到 edi+4 所指内存位置处。
          add  edi,8           ; edi指向表中下一项。
          loop rp_sidt    
              
          lidt [idt_descr]       ;加载中断描述符表寄存器值。
          ret          
                               
 
;让所有的256中断都指向这个统一的中断服务程序                        
ignore_int:
           cli               ;首先应禁止中断,以免中断嵌套 
           pushad            ;进入中断服务程序首先保存32位寄存器

           push ds           ;再保存所有的段寄存器
	   push es
	   push fs
	   push gs
	   push ss
	   mov  eax,2*8      ;进入断服务程序后所有数据类段寄存器都转到内核段
           mov ds,eax
           mov es,eax
           mov fs,eax
           mov gs,eax
           mov ss,eax

	  mov  esi,intmsg                ;保护模式DS=0,数据用绝对地址访问
          mov  cl, 0x09                  ;蓝色
          mov  edi, 0xb8000+18*160       ;指定显示在某行,显卡内存需用绝对地址
          call printnew

           pop ss             ;恢复所有的段寄存器
	   pop gs
	   pop fs
	   pop es
	   pop ds
	   
           popad              ; 所有32位寄存器出栈恢复
           iret                ;中断服务返回指令 


align 2 ;按4字节方式对齐内存地址边界。
dw    0 ;这里先空出2字节，这样_idt长字是4字节对齐的。 
                               
;下面是加载中断描述符表寄存器idtr的指令lidt要求的6字节操作数。
;前2字节是idt表的限长，后4字节是idt表在线性地址空间中的32位基地址。
idt_descr:
         dw 256*8-1 ;idt contains 256 entries # 共256项，限长=长度 - 1。
         dd _idt                               
         ret
         

    
setup_gdt:

        lgdt [gdt_descr] ;加载全局描述符表寄存器。
        ret


align 2 ;按4字节方式对齐内存地址边界。
dw    0 ;这里先空出2字节，这样_gdt长字是4字节对齐的。

;加载全局描述符表寄存器gdtr的指令lgdt要求的6字节操作数。前2字节是gdt表的限长，
;后4字节是gdt表的线性基地址。因为每8字节组成一个描述符项，所以表中共可有256项。
;符号_gdt是全局表在本程序中的偏移位置。
gdt_descr:
        dw 256*8-1  
        dd _gdt 
 
 


sysmsg  db '(iii) Welcome Linux---system!','$'
promsg  db '1.Now Already in Protect Mode','$'
headmsg db '2.Run head.asm in system program','$'
gdtmsg  db '3.Reset GDT success:New CS\EIP normal','$'
intmsg  db '4.Reset IDT success:Unknown interrupt','$'  
a20msg  db '5.Check A20 Address Line Stdate:Open','$'
pagemsg db '6.Memory Page Store:Page Tables is set up','$'
asmmsg  db '7.Pure Asm Program:bootsect->setup->head(system) is Finished','$'
mainmsg db '8.Now Come to C program entry:Main()','$'
      
 
;IDT表和GDT表放在程序head的最末尾

;中断描述符表：256个，全部初始化为0。        
_idt:    times 256  dq 0  ;idt is uninitialized # 256项，每项8字节，填0。

 
;全局描述符表。其前4项分别是：空项、代码段、数据段、系统调用段描述符，
;后面还预留了252项的空间，用于放置新创建任务的局部描述符(LDT)和对应的
;任务状态段TSS的描述符。
;(0-nul,1-cs,2-ds,3-syscall,4-TSS0,5-LDT0,6-TSS1,7-LDT1,8-TSS2 etc...)        
_gdt: dq 0x0000000000000000 ;NULL descriptor */
      dq 0x00c09a0000000fff ;16Mb */ # 0x08，内核代码段最大长度16MB。
      dq 0x00c0920000000fff ;16Mb */ # 0x10，内核数据段最大长度16MB。
      dq 0x0000000000000000 ;TEMPORARY - don't use */
      times 252 dq 0        ;space for LDT's and TSS's etc */ # 预留空间。