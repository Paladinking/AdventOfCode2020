bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input10.txt", 0
format: db "q", 0

section .text

extern setup
extern print_u64
extern parse_u64_cstr
extern split
extern memset
extern stack_alloc
extern listq_sort

extern file_buffer
extern file_size
extern parse_lines

global main

; rcx = ptr to list
; rdx = length
count_steps:
	mov r8, 1
	mov r9, 1
	mov r10, 1
count_steps_loop:
	cmp rdx, 1
	jbe count_steps_exit
	mov rax, QWORD [rcx + 8]
	sub rax, QWORD [rcx]
	add rcx, 8
	dec rdx
	cmp rax, 2
	je count_steps_loop
	jb count_steps_one
	add r9, 1
	jmp count_steps_loop
count_steps_one:
	add r8, 1
	jmp count_steps_loop
count_steps_exit:
	mov rax, r8
	mul r9
	ret


; rcx = ptr to list
; rdx = length
; r8 = last plug
; r9 = save buffer
; r10 = index
count_possibilites:
	push rsi
	push rdi
	push rbx
	push rbp
	push r12
	push r13
	push r14
	mov r13, r9
	mov r14, r10
	mov rsi, rcx
	mov rdi, rdx
	mov rbp, r8
	xor rbx, rbx
	xor r12, r12
	cmp rdx, 0
	je count_possibilites_final
	mov rcx, QWORD [r9 + 8 * r10]
	cmp rcx, 0
	je count_possibilites_loop
	lea r12, [rcx - 1]
	jmp count_possibilites_exit
count_possibilites_loop:
	mov r8, QWORD [rsi + 8 * rbx]
	mov rcx, r8
	sub rcx, rbp
	cmp rcx, 3
	ja count_possibilites_done
	inc rbx
	lea rcx, [rsi + 8 * rbx]
	mov rdx, rdi
	sub rdx, rbx
	mov r9, r13
	lea r10, [r14 + rbx]
	call count_possibilites
	add r12, rax
	cmp rbx, rdi
	jb count_possibilites_loop
	jmp count_possibilites_done
count_possibilites_final:
	mov r12, 1
count_possibilites_done:
	lea rcx, [r12 + 1]
	mov QWORD [r13 + 8 * r14], rcx
count_possibilites_exit:
	mov rax, r12
	pop r14
	pop r13
	pop r12
	pop rbp
	pop rbx
	pop rdi
	pop rsi
	ret


main:
	push rbp
	push rdi
	mov rbp, rsp
	sub rsp, 40
	call split
	mov rdi, rax
	shl rax, 4
	add rax, 8
	call stack_alloc
	mov rcx, QWORD [file_buffer]
	mov rdx, rsp
	mov r8, rdi
	lea r9, [format]
	call parse_lines
	mov rcx, rsp
	mov rdx, rdi
	call listq_sort
	mov rcx, rsp
	mov rdx, rdi
	call count_steps
	mov rcx, rax
	call print_u64
	lea rcx, [rsp + 8 * rdi]
	mov dl, 0
	lea r8, [8 + 8 * rdi]
	call memset
	mov rcx, rsp
	mov rdx, rdi
	xor r8, r8
	lea r9, [rsp + 8 * rdi]
	xor r10, r10
	call count_possibilites
	mov rcx, rax
	call print_u64
main_exit:
	mov rsp, rbp
	pop rdi
	pop rbp
	ret
