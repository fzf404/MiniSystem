;%define   debug             ;不注释调试，注释用于生产
%ifdef    debug
isdebug   equ   1
%else
isdebug   equ   0
%endif


DEF_INITSEG	equ	0x9000    ;MBR程序挪动后的目标地址
DEF_SYSSEG	equ	0x1000    ;SYSEM模块放置地址
DEF_SETUPSEG	equ	0x9020    ;SETUP模块放置地址