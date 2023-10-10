bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input3.txt", 0
new_line: db 0xA

section .text

extern split
extern strlen
extern file_buffer
extern file_size
extern print_u64

global main

; rcx = base_ptr, rdx = rows, r8 = columns
; r13 = down, r14 = right
parse:
	sub rsp, 8
	push r12
	push rdi
	push rbx
	push rsi
	mov rbx, rdx
	xor r12, r12
	xor rsi, rsi
	xor r9, r9
parse_loop:
	; Get offset = row * (columns + 1) + (col % columns)
	xor rdx, rdx
	mov rax, rsi
	div r8
	mov rdi, rdx
	lea rax, [r8 + 1]
	mul r9
	add rax, rdi

	cmp BYTE [rcx + rax], 0x23
	jne parse_loop_next
	inc r12
parse_loop_next:
	add r9, r13
	add rsi, r14
	cmp r9, rbx
	jbe parse_loop
parse_exit:
	mov rax, r12
	pop rsi
	pop rbx
	pop rdi
	pop r12
	add rsp, 8
	ret

main:
	sub rsp, 16
	push r13
	push r14
	push rbx
	push rsi
	call split
	mov rsi, rax
	mov rcx, QWORD [file_buffer]
	call strlen
main_one_parse:
	mov rcx, QWORD [file_buffer]
	mov rbx, rax
	mov rdx, rsi
	mov r8, rax
	mov r13, 1
	mov r14, 3
	call parse
	mov QWORD [rsp + 8], rax
	mov rcx, rax
	call print_u64
main_two_parse:
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	mov r8, rbx
	mov r13, 1
	mov r14, 1
	call parse
	mul QWORD [rsp + 8]
	mov QWORD [rsp + 8], rax
main_three_parse:
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	mov r8, rbx
	mov r13, 1
	mov r14, 5
	call parse
	mul QWORD [rsp + 8]
	mov QWORD [rsp + 8], rax
main_four_parse:
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	mov r8, rbx
	mov r13, 1
	mov r14, 7
	call parse
	mul QWORD [rsp + 8]
	mov QWORD [rsp + 8], rax
main_five_parse:
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	mov r8, rbx
	mov r13, 2
	mov r14, 1
	call parse
	mul QWORD [rsp + 8]
	mov rcx, rax
	call print_u64
main_exit:
	xor rax, rax
	pop rsi
	pop rbx
	pop r14
	pop r13
	add rsp, 16
	ret