segment code
global main
org   100H
main:
mov  ax, cs
mov  ds, ax
mov  ah, 9
mov  dx, MSG
int  21h
mov  ah, 4ch
int  21h
MSG  db 'Hello World!',0dh,0ah,'$'