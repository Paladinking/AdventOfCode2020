bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input8.txt", 0

section .text

extern print_u64
extern parse_i64_cstr
extern split
extern stack_alloc
extern memset
extern strlist_extract

extern file_buffer
extern file_size
extern heap

global main

; rcx = ptr to input
; rdx = ptr to save visited
; r8 = length of program
; rax => acc, rcx => index
parse:
	push rsi
	push rdi
	push rbx
	push rbp
	push r12
	mov rsi, rcx
	mov rdi, rdx
	mov r12, r8
	xor rbx, rbx
	xor rbp, rbp
parse_loop:
	cmp rbx, r12
	jae parse_exit
	cmp BYTE [rdi + rbx], 1
	je parse_exit
	mov BYTE [rdi + rbx], 1
	mov rcx, QWORD [rsi + 8 * rbx]
	mov edx, DWORD [rcx]
	cmp edx, "nop "
	je parse_loop_nop
	add rcx, 4
	cmp edx, "acc "
	je parse_loop_acc
	call parse_i64_cstr
	add rbx, rax
	jmp parse_loop
parse_loop_acc:
	call parse_i64_cstr
	add rbp, rax
parse_loop_nop:
	inc rbx
	jmp parse_loop
parse_exit:
	mov rax, rbp
	mov rcx, rbx
	pop r12
	pop rbp
	pop rbx
	pop rdi
	pop rsi
	ret


; rcx = ptr to input
; rdx = ptr to save visited
; r8 = length of program
; returns final acc
fix_program:
	push rsi
	push rdi
	push rbx
	push r12
	push r13
	mov rsi, rcx
	mov rdi, rdx
	mov rbx, r8
	xor r12, r12
fix_program_loop:
	mov rcx, QWORD [rsi + 8 * r12]
	mov r13d, DWORD [rcx]
	cmp r13d, "acc "
	je fix_program_loop_next
	mov eax, "jmp "
	mov edx, "nop "
	cmp r13d, "nop "
	cmove edx, eax
	mov DWORD [rcx], edx
	mov rcx, rdi
	mov dl, 0
	mov r8, rbx
	call memset
	mov rcx, rsi
	mov rdx, rdi
	mov r8, rbx
	call parse
	cmp rcx, rbx
	jae fix_program_exit
	mov rcx, QWORD [rsi + 8 * r12]
	mov DWORD [rcx], r13d
fix_program_loop_next:
	inc r12
	jmp fix_program_loop
fix_program_exit:
	pop r13
	pop r12
	pop rbx
	pop rdi
	pop rsi
	ret

main:
	push rbp
	push rdi
	push rsi
	mov rbp, rsp
	sub rsp, 32
	call split
	mov rdi, rax
	lea rax, [rax + 8 * rax]
	call stack_alloc
	lea rcx, [rsp + 8 * rdi]
	mov dl, 0
	lea r8, [rdi]
	call memset
	mov rcx, rsp
	mov rdx, QWORD [file_buffer]
	mov r8, rdi
	call strlist_extract
	mov rcx, rsp
	lea rdx, [rsp + 8 * rdi]
	mov r8, rdi
	call parse
	mov rcx, rax
	call print_u64
	mov rcx, rsp
	lea rdx, [rsp + 8 * rdi]
	mov r8, rdi
	call fix_program
	mov rcx, rax 
	call print_u64
	xor rax, rax
main_exit:
	mov rsp, rbp
	pop rsi
	pop rdi
	pop rbp
	ret