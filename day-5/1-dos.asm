NUMsector      EQU    8       ; 设置读取到的软盘最大扇区编号(18) 
NUMheader      EQU    0        ; 设置读取到的软盘最大磁头编号(01)
NUMcylind      EQU    0        ; 设置读取到的软盘柱面编号

mbrseg         equ    7c0h     ; 启动扇区存放段地址
loaderseg      equ    800h     ; 从软盘读取LOADER到内存的段地址

jmp   start

welcome db 'Welcome Jiang OS!','$'
fyread  db 'Now Floppy Read Loader:','$'
cylind  db 'cylind:?? $',0    ; 设置开始读取的柱面编号
header  db 'header:?? $',0    ; 设置开始读取的磁头编号
sector  db 'sector:?? $',2    ; 设置开始读取的扇区编号；第1扇区是MBR，可以不读
FloppyOK db '---Floppy Read OK','$'
Fyerror db '---Floppy Read Error' ,'$'
Fycontent db 'Floppy Content is:' ,'$'


start:

call showwelcome    ;初始化寄存器，打印必要信息
call loader         ;执行loader,把现在这张软盘的数据全部读到8000h开始。
jmp  loaderseg:0    ;跳转到内核。执行之后CS=loaderseg=800H,IP=0
                    ;内核程序从物理地址8000开始放


showwelcome:
     mov   ax,mbrseg
     mov   ds,ax   ;为显示各种提示信息做准备
     mov   ax,loaderseg
     mov   es,ax   ;为读软盘数据到内存做准备，因为读软盘需地址控制---ES:BX

     mov   si,welcome
     call  printstr
     call  newline
     ret

loader:
     mov   si, fyread
     call  printstr
     call  newline
     call  folppyload    ;将软盘的数据全部load到内存，从物理地址8000h开始
     ;mov   si, Fycontent
     ;call  printstr
     ;call  showdata      ;可以验证一下从软盘读入的kernal程序数据是否正确(二进制)
     ret


showdata:  mov  si,0             ;验证显示从软盘读取到内存的数据
           mov  ax, 800h
           mov  es,ax
           mov  cx,50             ;控制输出的数据长度
nextchar:  mov al,[es:si]
           mov ah,0eh
           int 10h
           inc si
           loop nextchar
           RET

folppyload:
     call    read1sector
     MOV     AX,ES
     ADD     AX,0x0020
     MOV     ES,AX                ;一个扇区占512B=200H，刚好能被整除成完整的段,因此只需改变ES值，无需改变BP即可。
     inc   byte [sector+11]
     cmp   byte [sector+11],NUMsector+1
     jne   folppyload             ;读完一个扇区
     mov   byte [sector+11],1
     inc   byte [header+11]
     cmp   byte [header+11],NUMheader+1
     jne   folppyload             ;读完一个磁头
     mov   byte [header+11],0
     inc   byte [cylind+11]
     cmp   byte [cylind+11],NUMcylind+1
     jne   folppyload             ;读完一个柱面

     ret


numtoascii:     ;将2位数的10进制数分解成ASII码才能正常显示。如柱面56 分解成出口ascii: al:35,ah:36
     mov ax,0
     mov al,cl  ;输入cl
     mov bl,10
     div bl
     add ax,3030h
     ret

readinfo:       ;显示当前读到哪个扇区、哪个磁头、哪个柱面
     mov si,cylind
     call  printstr
     mov si,header
     call  printstr
     mov si,sector
     call  printstr
     ret



read1sector:                      ;读取一个扇区的通用程序。扇区参数由 sector header  cylind控制

       mov   cl, [sector+11]      ;为了能实时显示读到的物理位置
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

       MOV        CH,[cylind+11]    ; 柱面从0开始读
       MOV        DH,[header+11]    ; 磁头从0开始读
       mov        cl,[sector+11]    ; 扇区从1开始读

        call       readinfo        ;显示软盘读到的物理位置
        mov        di,0
retry:
        MOV        AH,02H            ; AH=0x02 : AH设置为0x02表示读取磁盘
        MOV        AL,1            ; 要读取的扇区数
        mov        BX,    0         ; ES:BX表示读到内存的地址 0x0800*16 + 0 = 0x8000
        MOV        DL,00H           ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
        INT        13H               ; 调用BIOS 13号中断，磁盘相关功能
        JNC        READOK           ; 未出错则跳转到READOK，出错的话则会使EFLAGS寄存器的CF位置1
           inc     di
           MOV     AH,0x00
           MOV     DL,0x00         ; A驱动器
           INT     0x13            ; 重置驱动器
           cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃
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



times 510-($-$$) db 0
                 db 0x55,0xaa

;-------------------------------------------------------------------------------
;------------------此为扇区分界线，线上为第1扇区，线下为第2扇区-----------------
;-------------------------------------------------------------------------------
jmp    kernal

rdataseg         equ    1000h         ;从硬盘读取出的数据存放段地址 20000h     
wdataseg         equ    2000h         ;写进硬盘的数据存放段地址 800h为内核程序段地址,也即8000h。 

hdNUMsector      EQU   1      ; 设置读取到的硬盘最大扇区编号    最大:191
hdNUMheader      EQU   1      ; 设置读取到的硬盘最大磁头编号  最大:255 
hdNUMcylind      EQU   0       ; 设置读取到的硬盘柱面编号  最大:198 

whdNUMsector      EQU    2        ; 设置写到硬盘的最大扇区编号
whdNUMheader      EQU    0        ; 设置写到硬盘的最大磁头编号
whdNUMcylind      EQU    0        ; 设置写到硬盘的柱面编号

keralmsg   db 'Now You Have Comed Kernal!','$'
addrmsg    db 'Kernal Data Begins Address:8000h','$'
hdpara     db 'Now Hdisk Paras Read:','$'
hdwrite    db 'Now Hdisk Write Files:','$'
hdread     db 'Now Hdisk Read Files:','$'



pahdcylind  db 'cylind:?? $',0    ; 硬盘的柱面参数  0-6。共10bit，只取低8bit进行试验。 
pahdheader  db 'header:?? $',0    ; 硬盘的磁头参数  0-63
pahdsector  db 'sector:?? $',0    ; 硬盘的扇区参数  1-63
pahdOK      db '---Hdisk Paras Read OK','$'
pahderror   db '---Hdisk Paras Read Error' ,'$'



hdcylind  db 'cylind:?? $',0    ; 设置开始读取的柱面编号
hdheader  db 'header:?? $',0    ; 设置开始读取的磁头编号
hdsector  db 'sector:?? $',1    ; 设置开始读取的扇区编号
hdOK      db '---Hdisk Read OK','$'
hderror   db '---Hdisk Read Error' ,'$'  
hdcontent db 'Hdisk Content is:' ,'$'

whdcylind  db 'cylind:?? $',0    ; 设置开始写的柱面编号
whdheader  db 'header:?? $',0    ; 设置开始写的磁头编号
whdsector  db 'sector:?? $',1    ; 设置开始写的扇区编号
whdOK      db '---Hdisk Write OK','$'
whderror   db '---Hdisk Write Error' ,'$'

syscome    db '------------------------------------------------------',13,10,\
              'Now You Have Comed Jiang OS File System,Enjoy Youself!' ,13,10,\
              '------------------------------------------------------','$'
pwdinfo     db 'C:\>','$'
cdcom        db 'cd'
dircom       db 'dir'
clscom       db 'cls'
formatcom    db 'format'
mkdircom    db 'mkdir'              ;'deldir dir1????...'
deldircom    db 'deldir'   
inputcom    db '?????????????????'  ;'mkdir dir1????...' 
yescommsg    db 'True  Command','$'
nocommsg    db 'Bad   Command','$'
direrror    db 'Not Empty Directory,No Permited Delelte','$'
formatmsg   db 'Now Format Done,All Datas Lost!','$'

delname   db '????????'
bootname   db '/???????'
upname     db '..??????'
cdname     db '????????','$'       ;目录名最多8BIT
dirname    db '????????','$'       ;目录名最多8BIT 
filename  db '????????'

parentidmsg   db 'parentid:??','$'
diridmsg      db 'deldirid:??','$'

parentid   db -1 
dirid      db 0

deldirid   db 0
subdirid   db 0


kernal:     mov     ax,loaderseg     ;跳转到内核之后，全部寄存器启用新的段地址
                                     ;ES=CS=800H
            mov     es,ax              
            
            mov     ax,loaderseg
            sub     ax,20h
            mov     ds,ax            ;DS=800H-20H改变段地址之后，需要减去引导扇区的偏移量
                 
            mov     si, keralmsg  
            call    newline2
           call    printstr2
            call    newline2
           mov     si, addrmsg   
           call    printstr2
            call    newline2
            call    newline2

filesystem: call    newline2
            mov     si, pwdinfo
            call    printstr2
            
            mov     si, 0
usrinput: 
           mov ah,0
           int 16h                        ;从键盘读字符 ah=扫描码 al=字符码
           mov ah,0eh                     ;把键盘输入的字符显示出来 
           int 10h
           cmp    al, 0dh                 ;回车作为输入结束标记
           je     inputover
           mov    [inputcom+si],al
           inc    si
           jmp    usrinput

inputover: call   commanddeal 


           
           jmp    filesystem


showcsseg:   call     newline2
             mov  dx, cs
             mov al,dh
             add al,30h
             mov ah,0eh
             int 10h
             mov al,dl
             add al,30h
             mov ah,0eh
             int 10h
             call     newline2
             ret
             
      
commanddeal: 
           mov    si,0
           mov    cx,dircom-cdcom
nextcom3char:mov   ah, [cdcom+si]
           mov    al, [inputcom+si]
           cmp    ah, al
           jne    nextcom3
           inc    si
           loop   nextcom3char
           jmp    cd                    ;输入的是cd命令
           
nextcom3:           mov    si,0
           mov    cx,clscom-dircom
nextcom2char:mov   ah, [dircom+si]
           mov    al, [inputcom+si]
           cmp    ah, al
           jne    nextcom2
           inc    si
           loop   nextcom2char
           jmp    dir                    ;输入的是 dir命令

nextcom2:           mov    si,0
           mov    cx,formatcom-clscom
nextcom1char:mov   ah, [clscom+si]
           mov    al, [inputcom+si]
           cmp    ah, al
           jne    nextcom1
           inc    si
           loop   nextcom1char
           jmp    cls                    ;输入的是 cls命令
         
nextcom1:  mov    si,0
           mov    cx,mkdircom-formatcom
nextcomchar:mov    ah, [formatcom+si]
           mov    al, [inputcom+si]
           cmp    ah, al
           jne    nextcom 
           inc    si
           loop   nextcomchar 
           jmp    format                  ;输入的是 format命令   
                  
nextcom:   mov    si,0
           mov    cx,deldircom-mkdircom     
nextcomch: mov    ah, [mkdircom+si]
           mov    al, [inputcom+si]
           cmp    ah, al
           jne    nextcom4  
           inc    si
           loop   nextcomch
           jmp    makedir                  ;输入的是mkdir命令  
           
          
nextcom4:   mov    si,0
           mov    cx,inputcom-deldircom
nextcomch4: mov    ah, [deldircom+si]
           mov    al, [inputcom+si]
           cmp    ah, al
           jne    badcom
           inc    si
           loop   nextcomch4
           jmp    deldir                  ;输入的是deldir命令           
           
            
cd:      
             call    cddeal
             jmp     comdealover

dir:     
             call    dirdeal
             jmp     comdealover
 
cls:       

             call    clsdeal
             jmp     comdealover             
format:    
             
             call    formatdeal 
             jmp     comdealover 
             
makedir:   
             call    makedirdeal                                    
             jmp     comdealover
             
deldir:     
             call    deldirdeal
             jmp     comdealover
             
badcom:      call    newline2      ;否则输入的非法命令 
             mov     si, nocommsg
             call    printstr2
             call    newline2

comdealover: mov    si,0                  ;命令处理完成之后，清空用户输入命令的缓冲区数据
             mov    cx,yescommsg-inputcom
nextinputcom:mov    byte [inputcom+si],'?'
             inc    si
             loop   nextinputcom 
             
             mov    si,0                  ;命令处理完成之后，清空用户输入dir命令目标文件夹的缓冲区数据
             mov    cx,dirname-cdname
             dec    cx                    ;多了一位'$' 
nextinputcom2:mov    byte [cdname+si],'?'
             inc    si
             loop   nextinputcom2
             
             mov    si,0                  ;命令处理完成之后，清空用户输入cd命令标文件夹的缓冲区数据
             mov    cx,filename-dirname
             dec    cx                     ;多了一位'$'
nextinputcom3:mov    byte [dirname+si],'?'
             inc    si
             loop   nextinputcom3 
             ret
             
             mov    si,0                  ;命令处理完成之后，清空用户输入deldir命令标文件夹的缓冲区数据
             mov    cx,bootname-delname
             dec    cx                     ;多了一位'$'
nextinputcom4:mov    byte [delname+si],'?'
             inc    si
             loop   nextinputcom4
             ret


cddeal:      call    getcdname    ;根据用户命令获取目录文件名cdname，并存入缓冲区
             ;mov     si, cdname
             ;call    printstr2
             ;call    newline2    
             
             mov    si,0
             mov    cx,8
goonboot:    mov    dh, [cdname+si]    ;用户输入
             cmp    [bootname+si],dh     ;标准输入
             jne    cdcomnext1
             inc    si
             loop   goonboot
             mov    byte [parentid],-1 ;用户输入的是:cd /
             call    dirdeal           ;cd到目标目录后，需要显示子目录
            
             jmp    cddealover

cdcomnext1:      mov    si,0
              mov    cx,8
 goonup:     mov    dh, [cdname+si]    ;用户输入
             cmp    [upname+si],dh       ;标准输入
             jne    cdcomnext2
             inc    si
             loop   goonup
             call   cdupcomdeal         ;用户输入的是:cd ..
             call    dirdeal            ;cd到目标目录后，需要显示子目录
             jmp     cddealover       
             
cdcomnext2:  call    commoncddeal  ;用户输入的是普通:cd dir1;遍历目录区，求出目标目录的newparentid 
             call    dirdeal       ;cd到目标目录后，需要显示子目录
             
cddealover:   ret

             
cdupcomdeal:    call    readdirdata

                mov     si,0
 cdupcom :      ;cmp     byte [es:si+1],'?'   ;遍历结束标志
                cmp     si,2000
                je      cdupcomdealover
                mov     dh,[parentid]
                cmp     byte [es:si], dh     ;找出目录区中dirid=当前parentid的目录 
                jne     cdupcomnext
                mov     dh,  [es:si+1]
                mov     [parentid], dh       ;将找到目录的parentid赋值给当前parentid 
                jmp     cdupcomdealover      ;一旦找到上层目录就结束 
    cdupcomnext:add     si,10
                jmp     cdupcom
 cdupcomdealover:
                ret 
             ret  
                           

getcdname:   mov     di,0
             mov     si,  2    ;                 cd标准命令的长度
cdnamenext:mov     al,  [inputcom+si+1]
             cmp     al,  '?'                    ;用户输入文件名的结束位置
             je      cdnameover
             mov     [cdname+di],al
             inc     si
             inc     di
             jmp     cdnamenext
   cdnameover:  ret
             

commoncddeal:                                  ;cd普通目录 
               call    readdirdata
               
                mov     si,0
 cdparentid:  cmp     si,2000  ;遍历结束标志
                je      cdparentidover
                mov     dh,[parentid]
                cmp     byte [es:si+1], dh     ;找出目录区中匹配当前parentid的目录 
                jne     cdnextparentid
                call    ifdestdir
cdnextparentid: add     si,10
                jmp     cdparentid
 cdparentidover: 
                ret

ifdestdir: mov    di,si
           mov    cx,8 
           mov    bx,0
destdir:   mov    ah, [cdname+bx]     ;用户输入的目标目录 
           mov    al, [es:di+2]      ;硬盘中目录区的目录
           cmp    ah, al
           jne    destdirover
            inc    di
            inc    bx
            loop   destdir
            mov    dh,[es:si]          ;用户cd的目录和目标目录完全匹配 
            mov    [parentid],dh       ;将dirid的值赋到parentid,完成cd目录切换
            ;call   showparentid
destdirover: ret 


showparentid:
       mov   cl, [parentid]      ;为了能实时显示parentid
       call  numtoascii2
       mov   [parentidmsg+9],al
       mov   [parentidmsg+10],ah 
       call     newline2
       mov   si,  parentidmsg
       call    printstr2 
       call     newline2
       ret
       

readdirdata:                               ;读取目录数据结构区数据，在第12-15扇区
               mov byte [hdsector+11],12  ;目录数据结构区在第12-15扇区
                mov byte [hdheader+11],0
                mov byte [hdcylind+11],0
                mov     ax,rdataseg
                mov     es,ax
dirhdiskread:
                call    read1sector2        ;把目录数据区的扇区全部读出来
                MOV     AX,ES
                ADD     AX,0x0020
                MOV     ES,AX                ;一个扇区占512B=200H，刚好能被整除成完整的段,因此只需改变ES值，无需改变BP即可。
                inc   byte [hdsector+11]
                cmp   byte [hdsector+11],16
                jne   dirhdiskread

                mov     ax,rdataseg
                mov     es,ax
                ;call     newline2
                ;call     showdata2
                ;call     newline2                                
                ret 
                
                                            
dirdeal:        call    readdirdata

                mov     si,0
 goonparentid:  cmp     si,2000   ;遍历结束标志
                je      parentidover      
                mov     dh,[parentid]
                cmp     byte [es:si+1], dh
                jne     nextparentid
                call    showdirname 
nextparentid:   add     si,10 
                jmp     goonparentid
 parentidover:  ret
               
showdirname:    call    newline2
                mov  di, si
 nextdirname:   mov al,[es:di+2]   ;显示目录名称, 以'?'为结束标记
                cmp al,'?'    
                je showdirnameover
                mov ah,0eh
                int 10h
                inc di
                jmp  nextdirname
 showdirnameover:;call    newline2
                 ret  
                              
 
clsdeal:                    ;清屏
             mov ah,00h
             mov al,03h  ;80*25标准彩色文本
             int 10h
             ret     


getdelname:  mov     di,0
             mov     si,  inputcom-deldircom    ; 排除掉 mkdir标准命令的长度
delnamenextc:mov     al,  [inputcom+si+1]
             cmp     al,  '?'                    ;用户输入文件名的结束位置
             je      getdelnameover
             mov     [delname+di],al
             inc     si
             inc     di
             jmp     delnamenextc
   getdelnameover:  ret
            
deldirdeal:  call    getdelname    ;根据用户命令获取目录文件名dirname，并存入缓冲区
             ;mov     si, dirname
             ;call    printstr2
             ;call    newline2
             call    deldestdir   ;删除目标目录 
             ret
             
 
 deldestdir:    call   posdeldir        ;定位目标目录，出口为deldirid 

               call    readdirdata  
               mov     si,0
 godeldestdir:                         ;还需要判断是否空目录执行删除操作   
                cmp     si,2000              ;遍历结束标志
                je      deldestdirall
                mov     dh,[deldirid]
                cmp     byte [es:si+1], dh     ;找出目录区中匹配当前parentid的目录为子目录 
                je      notemptydir            ;一旦发现有子目录        
                add     si,10
                jmp     godeldestdir
              
notemptydir: ;call    newline2   
             mov     si,direrror  
             call    printstr2
             call    newline2   
             jmp     deldestdirover
                         
deldestdirall:  call    deldestdirdeal      ;遍历完说明是空目录，可以执行删除操作 
deldestdirover: ret
                

deldestdirdeal: 
               mov    ah,0
               mov    al,[deldirid] 
               call   delonedirdata    ;删除一个目录,以al为目录ID参数 
               
               mov    ah,0
               mov    al,[deldirid]
               call   delonedirno      ;清除一个目录编号占用标记，以al为目录ID参数
               ;call    showdeldirid
               ret
               
              
delonedirno: push   ax               ;把参数带进函数    
             
             mov  byte [hdsector+11],1   ;从目录文件控制信息扇区（第1扇区）读取目录编号占用标记
             mov  byte [hdheader+11],0
             mov  byte [hdcylind+11],0

             mov     ax,rdataseg       ;8000开始存放程序,10000开始存放硬盘读进的数据
             mov     es,ax
             call    read1sector2

             ;call     newline2
             ;call     numshow2
             ;call     newline2

             ;mov   ah,0
             ;mov   al,[deldirid]        ;要删除的目录编号 
             pop   ax                ;把调用此函数的参数带进来 
             mov   bl,8
             div   bl                ;假如目录编号为1，1/8,商al=0,余数ah=1

               mov   ch,0
               mov   cl,ah         ;用余数定位目录编号di占用标记在字节内的位置
               inc   cl
               mov   dl,0111_1111b
               rol   dl,cl          ;循环右移余数+1次,把0移到了需要的位置 
               mov   bh,0
               mov   bl, al          ;用商定位目录编号id占用标记所在的字节放在BX
               and   byte [es:bx],dl  ;更新占用标记1bit  相当于置0 

              mov byte [whdsector+11],1  ;往目录文件控制信息扇区（第1扇区）写目录编号占用标记
              mov byte [whdheader+11],0
              mov byte [whdcylind+11],0

              mov     ax,rdataseg       ;把先前读进来的数据又写回去（只有1个字节的里面的1 bit有更新）
              mov     es,ax
              call    write1sector2
              
              mov     byte [dirid],0         ;最后必须把dirid置0，为创建新目录命令mkdir做好准备。 

             ; call    read1sector2
             ; call     newline2
             ; call     numshow2
             ; call     newline2
             ; call     newline2
              ret

delonedirdata:  
             ;mov   ah,0
             ;mov   al,[deldirid]     ;要删除的目录编号
             mov   bl,50             ;目录编号/50，用商找到目录编号所在扇区
             div   bl                ;假如目录编号为1，1/50,商al=0,余数ah=1

             push  ax                ;把定位数据保存下来 ,商al=0,余数ah=1
             push  ax
             push  ax

             add  al, 12             ;al为目录编号所在扇区 12为目录编号大区扇区基础计数
             mov  byte [hdsector+11],al   ;
             mov  byte [hdheader+11],0
             mov  byte [hdcylind+11],0

             mov     ax,rdataseg       ;8000开始存放程序,10000开始存放硬盘读进的数据
             mov     es,ax
             call    read1sector2

             pop   ax                  ;目录编号/50，用余数*10，找到目录所在扇区内的偏移位置

             mov   al,ah               ;ah为余数
             mov   ah,0
             mov   bl,10
             mul   bl
             
             mov   bx, ax
             mov   cx, 10             ;一个目录10B 
delonedir:   mov  byte [es:bx], '?'   ;从硬盘上清空目录数据区的数据 
             inc  bx
             loop delonedir

writedeldir:

             pop  ax
             add  al, 12             ;al为目录编号所在扇区   12为目录编号大区扇区计数

              mov byte [whdsector+11],al  ;往目录编号所在扇区写目录编号数据
              mov byte [whdheader+11],0
              mov byte [whdcylind+11],0

            mov     ax,rdataseg       ;把先前读进来的数据又写回去（只有10个字节有更新）
            mov     es,ax
            call    write1sector2


             pop  ax
             add  al, 12             ;al为目录编号所在扇区   12为目录编号大区扇区计数
             mov  byte [hdsector+11],al   ;从硬盘读出目录编号所在扇区      验证数据
             mov  byte [hdheader+11],0
             mov  byte [hdcylind+11],0
              ;call    read1sector2
              ;call     newline2
              ;call     showdata2
              ;call     newline2
            ret
            
            
posdeldir: 
              call    readdirdata
              mov     si,0
 goposdeldir:  ;cmp     byte [es:si+1],'?'
                cmp     si,2000  ;遍历结束标志
                je      posdeldirover
                mov     dh,[parentid]
                cmp     byte [es:si+1], dh     ;找出目录区中匹配当前parentid的目录
                jne     posdeldirnext
                call    ifdeldestdir
posdeldirnext: add     si,10
                jmp     goposdeldir
posdeldirover:
                ret

ifdeldestdir: 
           mov    di,si
           mov    cx,8
           mov    bx,0
goifdeldest:   mov    ah, [delname+bx]     ;用户输入的目标目录
           mov    al, [es:di+2]      ;硬盘中目录区的目录
           cmp    ah, al
           jne    ifdeldestover
            inc    di
            inc    bx
            loop   goifdeldest
            mov    dh,  [es:si]
            mov    [deldirid],dh        ;找到要删除目录的dirid,先保存起来 
ifdeldestover:  
            ret     
             

showdeldirid:
       mov   cl, [deldirid]      
       call  numtoascii2
       mov   [diridmsg+9],al
       mov   [diridmsg+10],ah 
       call     newline2
       mov   si,  diridmsg
       call    printstr2 
       call     newline2
       ret             
                            
        
makedirdeal: call    getdirname    ;根据用户命令获取目录文件名dirname，并存入缓冲区
             ;mov     si, dirname
             ;call    printstr2
             ;call    newline2
             
             call    newdirid     ;遍历目录编号占用标记,确定新目录编号dirid,并更新目录占用标记
             call    writedir     ;把新建目录写进目录数据结构 
             
             ;call    showparentid
             ret                                 

writedir:    mov   ah,0
             mov   al,[dirid]        ;目录编号
             mov   bl,50             ;目录编号/50，用商找到目录编号所在扇区 
             div   bl                ;假如目录编号为1，1/50,商al=0,余数ah=1

             push  ax                ;把定位数据保存下来 ,商al=0,余数ah=1
             push  ax
             push  ax

             add  al, 12             ;al为目录编号所在扇区   12为目录编号大区扇区计数 
             mov  byte [hdsector+11],al   ;从硬盘读出目录编号所在扇区
             mov  byte [hdheader+11],0
             mov  byte [hdcylind+11],0
             
             mov     ax,rdataseg       ;8000开始存放程序,10000开始存放硬盘读进的数据
             mov     es,ax
             call    read1sector2
             
             pop   ax                  ;目录编号/50，用余数*10，找到目录所在扇区内的偏移位置     
              
             mov   al,ah               ;ah为余数 
             mov   ah,0
             mov   bl,10
             mul   bl                  
             
             mov   bx, ax
             mov  dh, [dirid]
             mov  [es:bx], dh
             inc  bx
             mov  dh, [parentid]
             mov  [es:bx],dh
             
             inc  bx             
             mov  si,0
writedirname:
             mov dl,[dirname+si]    ;写目录名 
             cmp dl,'?'
             je overwritedir 
             mov [es:bx],dl
             inc si
             inc bx
             jmp writedirname
              
overwritedir:

             pop  ax 
             add  al, 12             ;al为目录编号所在扇区   12为目录编号大区扇区计数
            
              mov byte [whdsector+11],al  ;往目录编号所在扇区写目录编号数据 
              mov byte [whdheader+11],0
              mov byte [whdcylind+11],0
            
            mov     ax,rdataseg       ;把先前读进来的数据又写回去（只有10个字节有更新）
            mov     es,ax
            call    write1sector2
            
            
             pop  ax
             add  al, 12             ;al为目录编号所在扇区   12为目录编号大区扇区计数
             mov  byte [hdsector+11],al   ;从硬盘读出目录编号所在扇区      验证数据 
             mov  byte [hdheader+11],0
             mov  byte [hdcylind+11],0
            
              ;call    read1sector2
             ; call     newline2
              ;call     showdata2
              ;call     newline2
           
            ret 
                          
             
newdirid:    
             mov  byte [hdsector+11],1   ;从目录文件控制信息扇区（第1扇区）读取目录编号占用标记
             mov  byte [hdheader+11],0
             mov  byte [hdcylind+11],0
        
             mov     ax,rdataseg       ;8000开始存放程序,10000开始存放硬盘读进的数据
             mov     es,ax
             call    read1sector2  
             
             ;call     newline2
             ;call     numshow2
             ;call     newline2
                              
nextdirno:   
             mov   ah,0
             mov   al,[dirid]        ;起始目录编号
             mov   bl,8
             div   bl                ;假如目录编号为1，1/8,商al=0,余数ah=1 
             
             push  ax                ;把定位数据保存下来 ,商al=0,余数ah=1  
             
             mov   bh,0
             mov   bl, al           ;先用商定位目录编号id占用标记所在的字节放在BX
             mov   dh,[es:bx]       
             
             mov   ch,0           
             mov   cl,ah         ;再用余数定位目录编号di占用标记在字节内的位置
             inc   cl            ;右移余数+1次
             shr   dh,cl          ;右移1位，0位将移到CF
             jnc   nozhan
             inc   byte [dirid]    ;占用了则下一个目录编号 
             pop   ax             ;同时需要POP出AX，因为在当前dirid已经被占用的情况下，后面会走不到POP命令。
;而POP命令和PUSH命令必须成对使用，因此这里做一个无效执行。就因为少了这行代码引起程序乱飞，导致我耽误了2周时间！ 
             jmp   nextdirno      ;注意这里有一个死循环，直到找到一个未占用的目录编号为止  
            
 nozhan:     mov al,[dirid]        ;转换成ASCII码显示输出验证
            ; add al,30h
             ;mov ah,0eh
            ; int 10h
              ;call     newline2
                                   ;还要将新的目录编号占用标记打成占用
              pop   ax             ;还原定位数据 
                    
               mov   ch,0                         
               mov   cl,ah         ;再用余数定位目录编号di占用标记在字节内的位置
               inc   cl
               mov   dl,1000_0000b
               rol   dl,cl          ;循环右移余数+1次,把1移到了需要的位置 
               mov   bh,0
               mov   bl, al          ;商定位目录编号di占用标记所在的字节
               or    byte [es:bx],dl           ;更新占用标记1bit

              mov byte [whdsector+11],1  ;往目录文件控制信息扇区（第1扇区）写目录编号占用标记
              mov byte [whdheader+11],0
              mov byte [whdcylind+11],0

              mov     ax,rdataseg       ;把先前读进来的数据又写回去（只有1个字节的里面的1 bit有更新） 
              mov     es,ax
              call    write1sector2   
              
              ;call    read1sector2
              ;call     newline2
              ;call     numshow2
              ;call     newline2             
              ;call     newline2
                  
              ret  
          
                        
numshow2:
           mov  si,0              ;验证显示从软盘读取到内存的数据
           mov  cx,80             ;控制输出的数据长度
numnext2:  mov al,[es:si]
           add al,30h             ;转换成ASCII码输出
           mov ah,0eh
           int 10h
           inc si
           loop numnext2
           ret     
          
          
                
getdirname:  mov     di,0
             mov     si,  deldircom- mkdircom    ; 排除掉 mkdir标准命令的长度 
namenextchar:mov     al,  [inputcom+si+1]
             cmp     al,  '?'                    ;用户输入文件名的结束位置 
             je      dirnameover
             mov     [dirname+di],al
             inc     si
             inc     di
             jmp     namenextchar
   dirnameover:  ret

        
formatdeal:  call    controlclear         ;目录文件控制信息数据结构区清0 
             call    sectorbusycl         ;扇区占用标记区数据清0
             call    dirstrclear          ;目录数据结构区数据清0
             call    filestrclear         ;文件数据结构区数据清0
             
             call    newline2
             mov     si, formatmsg
             call    printstr2
             call    newline2
                                
             ret      
             
             
controlclear: mov byte [whdsector+11],1  ;目录文件控制信息数据结构区在第1扇区
              mov byte [whdheader+11],0
              mov byte [whdcylind+11],0      
              
             mov     ax,wdataseg       ;8000开始存放程序,10000开始存放要写硬盘的数据
             mov     es,ax
             call    writereadydata    ; 1个扇区在写数据之前，都要在内存es:bx的地方先准备好数据
             call    write1sector2     ;写1个扇区，全写0
              
             ;call    numshow2          ;显示扇区数据（原始数据为数字非ASCII码）
             ;call    newline2
             ret
             
sectorbusycl:   mov byte [whdsector+11],2  ;目录文件控制信息数据结构区在第2-11扇区
                mov byte [whdheader+11],0
                mov byte [whdcylind+11],0
                
                
                mov     ax,wdataseg       ;8000开始存放程序,10000开始存放要写硬盘的数据
                mov     es,ax
  w10sectors:   call    writereadydata    ;每个扇区在写数据之前，都要在内存es:bx的地方先准备好数据 
                call    write1sector2
                inc     byte [whdsector+11] 
                cmp     byte [whdsector+11],12
                jne     w10sectors
                ;call    numshow2          ;显示扇区数据（原始数据为数字非ASCII码）
                ;call    newline2
                ret  

dirstrclear:    mov byte [whdsector+11],12  ;目录数据结构区在第12-15扇区
                mov byte [whdheader+11],0
                mov byte [whdcylind+11],0
                
                 mov     ax,wdataseg       ;8000开始存放程序,10000开始存放要写硬盘的数据
              mov     es,ax
f10sectors: call    writereadydata?    ; 1个扇区在写数据之前，都要在内存es:bx的地方先准备好数据
             call    write1sector2     ;写1个扇区，全写0

                inc     byte [whdsector+11]
                cmp     byte [whdsector+11],16
                jne     f10sectors
                ;call    showdata2          ;显示扇区数据（原始数据为数字非ASCII码）
                ;call    newline2            
             ret

filestrclear:
                mov byte [whdsector+11],16  ;目录文件控制信息数据结构区在第16-25扇区
                mov byte [whdheader+11],0
                mov byte [whdcylind+11],0
                mov     ax,wdataseg       ;8000开始存放程序,10000开始存放要写硬盘的数据
                mov     es,ax
  file10sectors: call    writereadydata    ;每个扇区在写数据之前，都要在内存es:bx的地方先准备好数据
                call    write1sector2
                inc     byte [whdsector+11]
                cmp     byte [whdsector+11],26
                jne     file10sectors
                ;call    numshow2          ;显示扇区数据（原始数据为数字非ASCII码）
                ;call    newline2
                ret                        
        
        
readhdpara:                         ;读取硬盘的扇区数、磁头数、柱面数等参数
        mov        di,0
paretry:
        MOV        AH,08H             
        MOV        DL,80H           ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
        INT        13H                                        
        JNC        paREADOK           ; 未出错则跳转到READOK，出错的话则会使EFLAGS寄存器的CF位置1
           inc     di
           MOV     AH,0x00
           MOV     DL,0x80         ; A驱动器
           INT     0x13            ; 重置驱动器
           cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃
           jne     paretry
           mov     si, pahderror
           call    printstr2
           call    newline2
           jmp     paexitread
paREADOK: mov     si, pahdOK
           call    printstr2
           call    newline2
                                             ;以下为显示出读出的磁盘参数
       and   cl, 00111111b
       mov   [pahdsector+11],cl              ;CL的位5-0＝扇区数
       mov   cl, [pahdsector+11]        
       call  numtoascii2
       mov   [pahdsector+7],al
       mov   [pahdsector+8],ah
           
     mov   [pahdheader+11],dh     
       mov   cl,[pahdheader+11]        ;DH＝磁头数  DL＝驱动器数
      call  numtoascii2
      mov   [pahdheader+7],al
      mov   [pahdheader+8],ah    
       
     mov  [pahdcylind+11],ch
     mov   cl,[pahdcylind+11]     ;CH＝柱面数的低8位 CL的位7-6＝柱面数的高2位,
      call  numtoascii2
      mov   [pahdcylind+7],al
     mov   [pahdcylind+8],ah
       
        call       pareadinfo        ;显示读到的硬盘参数
        
paexitread:  ret



pareadinfo:       ;显示当前读到哪个扇区、哪个磁头、哪个柱面
     mov si,pahdcylind
     call  printstr2
     mov si,pahdheader
     call  printstr2
     mov si,pahdsector
     call  printstr2
     ret
           

writereadydata:                         ;准备好写入硬盘的数据
            MOV  bx,0
nextrebit:
            mov  byte [ES:BX],0         ;全部初始化成0 
            INC  bx
            cmp  bx,512
            jne  nextrebit
            ret
            
            
writereadydata?:                         ;准备好写入硬盘的数据
            MOV  bx,0
nextrebit?:
            mov  byte [ES:BX],'?'         ;全部初始化成'?'
            INC  bx
            cmp  bx,512
            jne  nextrebit?
            ret



writetestdata:                      ;测试写入硬盘的数据 
            MOV  bx,0
nextbit:   
            mov  byte [ES:BX],'T'
            INC  bx
            cmp  bx,512
            jne  nextbit 
            
            mov  ax,es
            add  ax,20h
            mov  es,ax
            mov  bx,0
nextbit2 :  mov  byte [ES:BX],'Y'
            inc  bx
            cmp  bx,512
            jne  nextbit2
            ret

                       
showdata2: 
           mov  si,0             ;验证显示从软盘读取到内存的数据
           mov  cx,80             ;控制输出的数据长度
nextchar2:  mov al,[es:si]
           mov ah,0eh
           int 10h
           inc si
           loop nextchar2
          RET


hdiskwrite:
     call    write1sector2
     MOV     AX,ES
     ADD     AX,0x0020
     MOV     ES,AX                ;一个扇区占512B=200H，刚好能被整除成完整的段,因此只需改变ES值，无需改变BP即可。
     inc   byte [whdsector+11]
     cmp   byte [whdsector+11],whdNUMsector+1
     jne   hdiskwrite             ;写完一个扇区
     mov   byte [whdsector+11],1
     inc   byte [whdheader+11]
     cmp   byte [whdheader+11],whdNUMheader+1
     jne   hdiskwrite             ;写完一个磁头
     mov   byte [whdheader+11],0
     inc   byte [whdcylind+11]
     cmp   byte [whdcylind+11],whdNUMcylind+1
     jne   hdiskwrite             ;写完一个柱面

     ret



hdiskread:
     call    read1sector2
     MOV     AX,ES
     ADD     AX,0x0020
     MOV     ES,AX                ;一个扇区占512B=200H，刚好能被整除成完整的段,因此只需改变ES值，无需改变BP即可。
     inc   byte [hdsector+11]
     cmp   byte [hdsector+11],hdNUMsector+1
     jne   hdiskread             ;读完一个扇区
     mov   byte [hdsector+11],1
     inc   byte [hdheader+11]
     cmp   byte [hdheader+11],hdNUMheader+1
     jne   hdiskread             ;读完一个磁头
     mov   byte [hdheader+11],0
     inc   byte [hdcylind+11]
     cmp   byte [hdcylind+11],hdNUMcylind+1
     jne   hdiskread             ;读完一个柱面

     ret


newline2:                     ;显示回车换行
      mov ah,0eh
      mov al,0dh
      int 10h
      mov al,0ah
      int 10h
      ret

printstr2:                  ;显示指定的字符串, 以'$'为结束标记
      mov al,[si]
      cmp al,'$'
      je disover2
      mov ah,0eh
      int 10h
      inc si
      jmp printstr2
disover2:
      ret


write1sector2:                           ;读取一个扇区的通用程序。扇区参数由 sector header  cylind控制

       mov   cl, [whdsector+11]      ;为了能实时显示读到的物理位置
       call  numtoascii2
       mov   [whdsector+7],al
       mov   [whdsector+8],ah

       mov   cl,[whdheader+11]
       call  numtoascii2
       mov   [whdheader+7],al
       mov   [whdheader+8],ah

       mov   cl,[whdcylind+11]
       call  numtoascii2
       mov   [whdcylind+7],al
       mov   [whdcylind+8],ah

       MOV        CH,[whdcylind+11]    
       MOV        DH,[whdheader+11]    
       mov        cl,[whdsector+11]    

       ;call    writeinfo2        ;显示写到的物理位置

        mov        di,0
wretry2:
        MOV        AH,03H            ; AH=0x03 : AH设置为0x02表示写磁盘
        MOV        AL,1            ; 要写的扇区数
        mov        BX,    0         ; ES:BX表示取数据从内存的地址 0x1000*16 + 0 = 0x10000
        MOV        DL,80H           ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
        INT        13H               ; 调用BIOS 13号中断，磁盘相关功能
        JNC        writeOK2           ; 未出错则跳转到writeOK2，出错的话则会使EFLAGS寄存器的CF位置1
           inc     di
           MOV     AH,0x00
           MOV     DL,0x80         ; A驱动器
           INT     0x13            ; 重置驱动器
           cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃
           jne     wretry2

        
           mov     si, whderror
           call    printstr2
           call    newline2
           jmp     exitwrite2
writeOK2: 
           ;mov     si, whdOK
           ;call    printstr2
           call    newline2
           
exitwrite2:         
           
           ret




read1sector2:                           ;读取一个扇区的通用程序。扇区参数由 sector header  cylind控制

       mov   cl, [hdsector+11]      ;为了能实时显示读到的物理位置
       call  numtoascii2
       mov   [hdsector+7],al
       mov   [hdsector+8],ah

       mov   cl,[hdheader+11]
       call  numtoascii2
       mov   [hdheader+7],al
       mov   [hdheader+8],ah

       mov   cl,[hdcylind+11]
       call  numtoascii2
       mov   [hdcylind+7],al
       mov   [hdcylind+8],ah

       MOV        CH,[hdcylind+11]    ; 柱面从0开始读
       MOV        DH,[hdheader+11]    ; 磁头从0开始读
       mov        cl,[hdsector+11]    ; 扇区从1开始读   
       
        ;call       readinfo2        ;显示软盘读到的物理位置
        
        mov        di,0
retry2:
        MOV        AH,02H            ; AH=0x02 : AH设置为0x02表示读取磁盘
        MOV        AL,1            ; 要读取的扇区数
        mov        BX,    0         ; ES:BX表示读到内存的地址 0x0800*16 + 0 = 0x8000
        MOV        DL,80H           ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
        INT        13H               ; 调用BIOS 13号中断，磁盘相关功能
        JNC        READOK2           ; 未出错则跳转到READOK，出错的话则会使EFLAGS寄存器的CF位置1
           inc     di
           MOV     AH,0x00
           MOV     DL,0x80         ; A驱动器
           INT     0x13            ; 重置驱动器
           cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃
           jne     retry2

           mov     si, hderror
           call    printstr2
           call    newline2
           jmp     exitread2
READOK2:    ;mov     si, hdOK
           ;call    printstr2
           call    newline2
exitread2:
           ret
           
 
 
           
numtoascii2:     ;将2位数的10进制数分解成ASII码才能正常显示。如柱面56 分解成出口ascii: al:35,ah:36
     mov ax,0
     mov al,cl  ;输入cl
     mov bl,10
     div bl
     add ax,3030h
     ret
     


writeinfo2:       ;显示当前读到哪个扇区、哪个磁头、哪个柱面
     mov si,whdcylind
     call  printstr2
     mov si,whdheader
     call  printstr2
     mov si,whdsector
     call  printstr2
     ret     
     
readinfo2:       ;显示当前读到哪个扇区、哪个磁头、哪个柱面
     mov si,hdcylind
     call  printstr2
     mov si,hdheader
     call  printstr2
     mov si,hdsector
     call  printstr2
     ret