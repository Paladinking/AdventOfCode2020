bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input11.txt", 0
format: db "q", 0

section .text

extern print_u64
extern split
extern strlen
extern stack_alloc

extern file_buffer

global main

; rcx = ptr to buffer
; rdx = output buffer
; r8 = number of lines
; r9 = line width
tick_grid:
	push rsi
	push rdi
	push rbx
	mov rsi, rcx
	mov rbx, 1
	dec r8
	dec r9
tick_grid_loop:
	cmp rbx, r8
	je tick_grid_done
	mov rdi, 1
tick_grid_loop_inner:
	cmp rdi, r9
	je tick_grid_loop_next
	mov rax, r9
	mul rbx
	add rax, rdi
	mov cl, BYTE  [rsi + rax]
	xor edx, edx
	cmp cl, "."
	je tick_grid_loop_inner_next
	cmp r9, 0
	je tick_grid_loop_inner_bottom
	lea r10, [rax - 1]
	sub r10, r8		; x, y - 1
	
tick_grid_loop_inner_next:
	mov BYTE [rsi + rax], cl
	inc r9
	jmp tick_grid_loop_inner
tick_grid_loop_next:
	inc rbx
	jmp tick_grid_loop
tick_grid_done:

tick_grid_exit:
	pop rbx
	pop rdi
	pop rsi
	ret


main:
	push rsi
	push rdi
	push rbx
	mov rsi, rcx
	call split
	mov rdi, rax
	mov rcx, rsi
	call strlen
	mov rbx, rax
	
	pop rbx
	pop rdi
	pop rsi
	ret