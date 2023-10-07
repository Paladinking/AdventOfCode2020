bits 64
default rel

%define PARSE_INT_ERROR 101

%define PREAMBLE 25

section .rdata
global input
input: db "..\input\input9.txt", 0

section .text

extern setup
extern print_u64
extern parse_u64_cstr
extern split
extern stack_alloc

extern file_buffer
extern file_size
extern heap

global main

; rcx = ptr to input
; rdx = ptr to output
; r8 = line count
parse:
	push rsi
	push rbx
	sub rsp, 8
	mov rbx, rdx
	lea rsi, [rdx + 8 * r8]
parse_loop:
	cmp rbx, rsi
	je parse_exit
	call parse_u64_cstr
	mov QWORD [rbx], rax
	inc rcx
	add rbx, 8
	jmp parse_loop
parse_exit:
	add rsp, 8
	pop rbx
	pop rsi
	ret

; rcx = ptr to PREAMBLE last numbers
; rdx = number to check for, remains
contains_sum:
	xor r8, r8
contains_sum_outer:
	cmp r8, PREAMBLE
	je contains_sum_end
	mov rax, QWORD [rcx + 8 * r8]
	lea r9, [r8 + 1]
contains_sum_inner:
	cmp r9, PREAMBLE
	je contains_sum_outer_next
	mov r10, rax
	add r10, QWORD [rcx + 8 * r9]
	inc r9
	cmp r10, rdx
	jne contains_sum_inner
	mov rax, 1
	jmp contains_sum_exit
contains_sum_outer_next:
	inc r8
	jmp contains_sum_outer
contains_sum_end:
	xor rax, rax
contains_sum_exit:
	ret

; rcx = ptr to numbers
; Stack gets missaligned if PREAMBLE is even...
find_number:
	push rsi
	push rbx
	push rbp
	sub rsp, PREAMBLE * 8 + 8 
	xor rbx, rbx
	mov rsi, rcx
find_number_preamble_loop:
	mov rax, QWORD [rsi + 8 * rbx]
	mov QWORD [rsp + 8 * rbx], rax
	inc rbx
	cmp rbx, PREAMBLE
	jb find_number_preamble_loop
	xor rbp, rbp
find_number_loop:
	mov rdx, QWORD [rsi + 8 * rbx]
	mov rcx, rsp
	call contains_sum
	cmp rax, 0
	je find_number_found
	mov QWORD [rsp + 8 * rbp], rdx
	inc rbx
	inc rbp
	xor rdx, rdx
	cmp rbp, PREAMBLE
	cmove rbp, rdx
	jmp find_number_loop
find_number_found:
	mov rax, rdx
find_number_exit:
	add rsp, PREAMBLE * 8 + 8
	pop rbp
	pop rbx
	pop rsi
	ret

; rcx = ptr to numbers
; rdx = number to find
find_number_range:
	mov r8, rcx ; base
find_number_range_loop:
	mov rax, QWORD [r8]
	mov r9, rax
	mov r10, rax
	lea rcx, [r8 + 8]
	mov r8, rcx
find_number_range_inner:
	mov r11, QWORD [rcx]
	add rax, r11
	cmp r9, r11
	cmovb r9, r11
	cmp r10, r11
	cmova r10, r11
	cmp rax, rdx
	je find_number_range_exit
	ja find_number_range_loop
	add rcx, 8
	jmp find_number_range_inner
find_number_range_exit:
	add r9, r10
	mov rax, r9
	ret

main:
	push rbp
	push rdi
	mov rbp, rsp
	sub rsp, 40
	call setup
	cmp rax, 0
	jne main_exit
	mov rcx, QWORD [file_buffer]
	mov rdx, QWORD [file_size]
	call split
	mov rdi, rax
	shl rax, 3
	call stack_alloc
	mov rcx, QWORD [file_buffer]
	mov rdx, rsp
	mov r8, rdi
	call parse
	mov rcx, rsp
	call find_number
	mov rcx, rax
	mov rdi, rax
	call print_u64
	mov rcx, rsp
	mov rdx, rdi
	call find_number_range
	mov rcx, rax
	call print_u64
	xor rax, rax
main_exit:
	mov rsp, rbp
	pop rdi
	pop rbp
	ret