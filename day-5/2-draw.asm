jmp start

start:
  call   windows    ; 绘图
  ; 带返回值中断
  mov ah,4ch
  int 21h

windows:
  call setmode
  call alllines    ; 打印背景
  call win1
  call win2
  call win3
  call win4
  ret


setmode:
  mov  bx,0x4105    ; 设置图形模式：1024×768 256色
  mov  ax,0x4f02
  int  10h
  ret

alllines: 
  mov  dx,0        ; 列计数
goon2:   
  mov  cx,0       ; 行计数
  call oneline
  inc  dx
  cmp  dx,767
  jne  goon2
  ret

oneline:           ; 第dx行画水平线
  ;mov cx,0        ; x坐标
  ;mov dx,0        ; y坐标
  mov al,00010001b     ; 写入像素 xxxxARGB
  mov ah,0ch       ; 
goon:   
  inc cx
  cmp cx,1023
  int 10h
  jne goon
  ret

win1:    
  mov dx,200      ; 200行开始
linew1:  
  mov cx,300      ; 300列
goonw1: 
  mov al,0100b     ;颜色
  mov ah,0ch       ;写入点像
  inc cx
  int 10h
  cmp cx,500      ; 至500
  jne goonw1
  inc dx
  cmp dx,400      ; 至400
  jne linew1
  ret

win2:    
  mov dx,200      
linew2:  
  mov cx,520
goonw2: 
  mov al,0010b     
  mov ah,0ch       
  inc cx
  int 10h
  cmp cx,720
  jne goonw2
  inc dx
  cmp dx,400
  jne linew2
  ret

win3:    
  mov dx,420      
linew3:  
  mov cx,300
goonw3: 
  mov al,0001b     
  mov ah,0ch       
  inc cx
  cmp cx,500
  int 10h
  jne goonw3
  inc dx
  cmp dx,620
  jne linew3
  ret

win4:    
  mov dx,420      
linew4:  
  mov cx,520
goonw4: 
  mov al,0110b     
  mov ah,0ch       
  inc cx
  cmp cx,720
  int 10h
  jne goonw4
  inc dx
  cmp dx,620
  jne linew4
  ret