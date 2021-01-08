colorfuncport equ 3c8h   ; 设置调色板功能端口
colorsetport equ 3c9h    ;设置调色板颜色端口
displayadd equ 0xa000    ;图像模式显存起始地址


call  setmode     ; 显示模式 320*200
call  backgroud   ; 背景色设置
call  colorset
call  win1
call  win2
call  win3
call  win4
; call drawimg
mov   ax,0ch
int   21h
jmp   $

setmode:
  mov ah,0
  mov al,13h         
  int 10h
  ret

setmode2:         ; 1024*768
  mov AX,4F02H
  mov bx,4105H       
  int 10h
  ret

backgroud:         
  mov dx, colorfuncport
  mov al, 0               ; 建调色板索引0号

  ; 外设的操作通过专门的端口读写指令来完成
  out dx,al               ; Out: al的值写入显卡调色板功能端口

  mov dx, colorsetport    ;设置黑灰色背景
  mov al,8                ; R分量
  out dx,al
  mov al,8                ; G分量
  out dx,al
  mov al,8               ; B分量
  out dx,al
  ret

colorset:                 ; 显示色设置
  mov dx, colorfuncport
  mov al, 1               ; 建调色板索引1号
  out dx, al
  mov dx, colorsetport    ;设置红色调色板
  mov al,32               
  out dx,al
  mov al,0               
  out dx,al
  mov al,0               
  out dx,al

  mov dx, colorfuncport
  mov al, 2                 ; 建调色板索引2号
  out dx,al
  mov dx,  colorsetport     ;设置蓝色调色板
  mov al,0          
  out dx,al
  mov al,0           
  out dx,al
  mov al,32         
  out dx,al

  mov dx,  colorfuncport
  mov al, 3                 ;建调色板索引3号
  out dx,al
  mov dx,  colorsetport     ;设置绿色
  mov al,0           
  out dx,al
  mov al,32           
  out dx,al
  mov al,0          
  out dx,al

  mov dx, colorfuncport
  mov al, 4                 ;建调色板索引4号
  out dx,al

  mov dx,  colorsetport     ;设置黄色
  mov al,32              
  out dx,al
  mov al,32           
  out dx,al
  mov al,0          
  out dx,al

  ret


drawimg:           ; 满屏画同一颜色
  mov bl,4
  mov ax,displayadd
  mov es,ax
  mov cx,0xffff    ; 设置距离
  mov di,0
  
nextpoint:
  mov  [es:di],bl   ; 调色板颜色索引送往显存地址
  inc  di
  loop nextpoint
  ret

win1:
  mov bl,1              ; 填充颜色
  mov dx,50             ; 起始行
  mov ax,320*50/10h     ; 起始行前像素点数量
  add ax,displayadd
  mov es,ax
win1line:
  mov cx,50           ; 矩形长度 es:di计数
  mov di,100          ; 起始列
win1point:
  mov  [es:di],bl     ; 调色板颜色索引送往显存地址
  inc di
  loop win1point
  inc dx
  mov ax,es
  add ax,0x14         ; 显卡内存每一行增加一次es段地址   320*x+y 320=140h
  mov es,ax
  cmp dx,100          ; 矩形高度
  jne win1line
  ret

win2:
  mov bl,2
  mov dx,110         ; 起始行
  mov ax,320*110/10h
  add ax,displayadd
  mov es,ax
  win2line:
  mov cx,50         
  mov di,100          ; 起始列     
  win2point:
  mov  [es:di],bl   
  inc di
  loop win2point
  inc dx
  mov ax,es
  add ax,0x14      
  mov es,ax
  cmp dx,160       
  jne win2line
  ret

win3:
  mov bl,3
  mov dx,50         ; 起始行
  mov ax,320*50/10h
  add ax,displayadd
  mov es,ax
  win3line:
  mov cx,50          
  mov di,160         ; 起始列
  win3point:
  mov  [es:di],bl    
  inc di
  loop win3point
  inc dx
  mov ax,es
  add ax,0x14      
  mov es,ax
  cmp dx,100       
  jne win3line
  ret

win4:
  mov bl,4
  mov dx,110         ; 起始行
  mov ax,320*110/10h
  add ax,displayadd
  mov es,ax
  win4line:
  mov cx,50         
  mov di,160         ; 起始列
  win4point:
  mov  [es:di],bl  
  inc di
  loop win4point
  inc dx
  mov ax,es
  add ax,0x14     
  mov es,ax
  cmp dx,160      
  jne win4line
  ret