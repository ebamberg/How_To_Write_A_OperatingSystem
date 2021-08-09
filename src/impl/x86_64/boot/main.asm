global header_start
extern long_mode_start
section .text
bits 32

start:
    
    ; ---- set up stack pointer -------
    mov esp, stack_top          ; esp is the cpu stack-pointer, set stack pointer to our empty stack
    ; -------------------------------------
    ;  ----- setup virtual memory paging
    ; -------------------------------------
    ; virtual memory paging is necessary to enter long-mode (=64bit)
    ;
    call setup_page_tables
    call enable_paging

    ; start our 64bit code
	lgdt [gdt64.pointer]
	jmp gdt64.code_segment:long_mode_start          ; jump into 64bit assembler code; from here on we are running in 64bit mode

    
    hlt

setup_page_tables:

    ; we pick adress of page_table_level3, the first 12 bits of the adress are flags, so we or then
    ; then we can write this adress at the start of page_table_level4
    ; so page_table_level4[ adress 0] point to start of page_table_level3
    ; then page_table_level3 points to page_table_level2

    mov eax, page_table_level3
    ; first 12 bits are flags rest points to the table (ore entries are align to 4096)
    or eax, 0b11 ; set preset, writable
    mov [page_table_level4], eax      

    mov eax, page_table_level2
    or eax, 0b11 ; set present, writable
    mov [page_table_level3], eax     

    ; we map first GB of memory to 512 HugePage block of virtual memory
    ; so virtual memory address is = physical memory for all this 512 huge pages
    ; fill table 2 with pointer to 2MB blocks 512 time 2MB we end up with 1 GB of memory
    ; we have to set a point at every entry of the pagel_table_level2 
    mov ecx, 0
.loop:
    mov eax, 0x200000   ; 2 MB
    mul ecx             ; 2mb * Pointer = physical memory adress
    or eax, 0b10000011  ; set present, writable, huge page
    mov [page_table_level2+ecx*8], eax ; set the page address into  the page_table_level2
    inc ecx
    cmp ecx,512
    jne .loop

    ret

enable_paging:
    mov eax,page_table_level4
    mov cr3, eax                ; cr3 cpu register points to our page_table
    ; enable physical address extension
    mov eax, cr4
    or eax, 1<< 5       ; enable PAE by setting bit 5 of cr4-cpu-register
    mov cr4,eax

    ; enable long mode (64bit)
	mov ecx, 0xC0000080
	rdmsr
	or eax, 1 << 8
	wrmsr

	; enable paging
	mov eax, cr0
	or eax, 1 << 31
	mov cr0, eax

    ret
; --------------------------
;   RESERVED MEMORY
; --------------------------
;
section .bss
align 4096
;
; --------------------------
;   reserved Page Table
; --------------------------
;
page_table_level4:
    resb 4096
page_table_level3:
    resb 4096
page_table_level2:
    resb 4096
page_table_level1:
    resb 4096
       

;
; --------------------------
;   reserved Stack memory
; --------------------------
;
stack_bottom:
    resb 4096*4     ; 4kb * 4 (=32bit)
stack_top:          ; a stack is bottom up

section .rodata
gdt64:
	dq 0 ; zero entry
.code_segment: equ $ - gdt64
	dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; code segment
.pointer:
	dw $ - gdt64 - 1 ; length
	dq gdt64 ; address