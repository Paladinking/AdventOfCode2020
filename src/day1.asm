bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input1.txt", 0
new_line: db 0xA

section .bss
numbers: resq 1
numbers_count: resq 1

section .text

extern heap
extern setup
extern print
extern split
extern file_buffer
extern file_size
extern parse_u64_cstr
extern format_u64

extern error_byte

extern HeapAlloc
extern HeapFree
extern GetLastError

global main

main:
	push rbx
	push rdi
	sub rsp, 40
	call setup
	mov rcx, QWORD [file_buffer]
	mov rdx, QWORD [file_size]
	call split
	mov QWORD [numbers_count], rax
	mov rdi, rax
	mov rcx, QWORD [heap]
	xor rdx, rdx
	lea r8, [rax * 8]
	call HeapAlloc
	mov QWORD [numbers], rax
	mov rbx, rax
	cmp rax, 0
	jne main_parse
	mov rax, 1
	jmp main_exit
main_parse:
	mov rcx, QWORD [file_buffer]
	lea rdi, [rbx + 8 * rdi]
main_parse_loop:
	cmp rbx, rdi
	je main_solve
	call parse_u64_cstr
	cmp BYTE [error_byte], PARSE_INT_ERROR
	jne main_parse_loop_inc
	mov rax, 2
	jmp main_free
main_parse_loop_inc:
	mov QWORD [rbx], rax
	add rbx, 8
	inc rcx
	jmp main_parse_loop
main_solve:
	mov rbx, QWORD [numbers]
	lea rcx, [rbx + 8]
	mov rdi, QWORD [numbers_count]
	lea rdi, [rbx + 8 * rdi]
main_solve_loop:
	cmp rbx, rdi
	je main_solve_fail
main_solve_loop_inner:
	cmp rcx, rdi
	je main_solve_loop_next_outer
	mov r8, QWORD [rbx]
	add r8, QWORD [rcx]
	cmp r8, 2020
	je main_solve_done
	add rcx, 8
	jmp main_solve_loop_inner
main_solve_loop_next_outer:
	add rbx, 8
	lea rcx, [rbx + 8]
	jmp main_solve_loop
main_solve_fail:
	mov rax, 3
	jmp main_free
main_solve_done:
	mov rax, QWORD [rbx]
	mov rcx, QWORD [rcx]
	mul rcx
	mov rcx, rax
	mov rdx, QWORD [file_buffer]
	mov r8, QWORD [file_size]
	call format_u64
	cmp rax, 0
	jne main_print
	mov rax, 4
	jmp main_free
main_print:
	mov rcx, QWORD [file_buffer]
	mov rdx, rax
	call print
	lea rcx, [new_line]
	mov rdx, 1
	call print
main_free_end:
	xor rax, rax
main_free:
	mov QWORD [rsp + 32], rax
	mov rcx, QWORD [heap]
	xor rdx, rdx
	mov r8, QWORD [numbers]
	call HeapFree
	mov rax, QWORD [rsp + 32]
	jmp main_exit
main_end:
	xor rax, rax
main_exit:
	add rsp, 40
	pop rdi
	pop rbx
	ret