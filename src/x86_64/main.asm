global header_start
section .text
bits 32
start:
    ; print "OK"
    ; write directly  to video memory
    mov dword [0xb8000], 0x2f4b2f4f
    
    hlt