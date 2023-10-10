bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input5.txt", 0
new_line: db 0xA

section .bss
seats: resq 1024

section .text

extern split
extern print_u64
extern listq_contains

extern file_buffer
extern file_size


global main

; rcx - ptr to seat
parse_seat:
	sub rsp, 8
	push rsi
	mov rsi, 128
	xor edx, edx
	mov r8d, 128
	mov r9d, 7
parse_seat_loop:
	mov eax, edx
	add eax, r8d
	shr eax, 1
	cmp BYTE [rcx], 0x46
	je parse_seat_loop_forward
	cmp BYTE [rcx], 0x4c
	je parse_seat_loop_forward
	mov edx, eax
	jmp parse_seat_loop_next
parse_seat_loop_forward:
	mov r8d, eax
parse_seat_loop_next:
	inc rcx
	dec r9d
	cmp r9d, 0
	ja parse_seat_loop
	cmp rsi, 128
	jne parse_seat_done
	mov rsi, rdx
	xor edx, edx
	mov r8d, 8
	mov r9d, 3
	jmp parse_seat_loop
parse_seat_done:
	shl rsi, 3
	add rsi, rdx
	mov rax, rsi
parse_seat_exit:
	pop rsi
	add rsp, 8
	ret

; rcx: ptr to input, rdx: length
parse:
	push rdi
	push rsi
	push rbx
	lea rdi, [seats]
	xor rbx, rbx
	mov rsi, rdx
parse_loop:
	cmp rsi, 0
	je parse_exit
	call parse_seat
	inc rcx
	dec rsi
	mov QWORD [rdi], rax
	add rdi, 8
	cmp rax, rbx
	cmova rbx, rax
	jmp parse_loop
parse_exit:
	lea rcx, [seats]
	sub rdi, rcx
	shr rdi, 3
	mov rcx, rdi
	mov rax, rbx
	pop rbx
	pop rsi
	pop rdi
	ret


	; rcx - number of seats
find_seat:
	push rdi
	push rbx
	push rsi
	xor rsi, rsi
	mov rbx, rcx
	xor dil, dil
find_seat_loop:
	cmp rsi, 1024
	je find_seat_exit
	mov rcx, rsi
	lea rdx, [seats]
	mov r8, rbx
	call listq_contains
	cmp rax, 0
	je find_seat_not_found
	mov dil, 1
	jmp find_seat_next
find_seat_not_found:
	cmp dil, 0
	jne find_seat_exit
	xor dil, dil
find_seat_next:
	inc rsi
	jmp find_seat_loop
find_seat_exit:
	mov rax, rsi
	pop rsi
	pop rbx
	pop rdi
	ret

main:
	sub rsp, 24
	push rsi
	push rbx
	call split
	mov rcx, QWORD [file_buffer]
	mov rdx, rax
	call parse
	mov rsi, rax
	mov rbx, rcx
	mov rcx, rax
	call print_u64
	mov rcx, rbx
	call find_seat
	mov rcx, rax
	call print_u64
	xor rax, rax
	pop rbx
	pop rsi
	add rsp, 24
	ret