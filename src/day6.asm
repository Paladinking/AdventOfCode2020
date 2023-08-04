bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input6.txt", 0
new_lines: db 0xA, 0xA, 0x0

section .text

extern setup
extern split_on
extern print_u64

extern file_buffer
extern file_size

global main


; rcx = ptr to group
count_group:
	mov r8, rcx
	xor rdx, rdx
count_group_loop:
	mov cl, BYTE [r8]
	cmp cl, 0
	je count_group_exit
	inc r8
	cmp cl, 0xA
	je count_group_loop
	sub cl, 0x61
	mov rax, 1
	shl rax, cl
	or  rdx, rax
	jmp count_group_loop
count_group_exit:
	popcnt rax, rdx
	mov rcx, r8
	ret


count_group_all:
	mov r9, rcx
	mov r8, 0xffffffffffffffff
	xor rdx, rdx
count_group_all_loop:
	mov cl, BYTE [r9]
	cmp cl, 0
	je count_group_all_sum
	inc r9
	cmp cl, 0xA
	jne count_group_all_az
count_group_all_inc:
	and r8, rdx
	xor rdx, rdx
	jmp count_group_all_loop
count_group_all_az:
	sub cl, 0x61
	mov rax, 1
	shl rax, cl
	or rdx, rax
	jmp count_group_all_loop
count_group_all_sum:
	and r8, rdx
	popcnt rax, r8 
count_group_all_exit:
	mov rcx, r9
	ret


; rcx = ptr, rdx = count, r8 = funcptr
count_answers:
	push rdi
	push rsi
	push rbx
	xor rsi, rsi
	mov rbx, rdx
	mov rdi, r8
count_answers_loop:
	cmp rbx, 0
	je count_answers_exit
	call rdi
	add rsi, rax
	add rcx, 2
	dec rbx
	jmp count_answers_loop
count_answers_exit:
	mov rax, rsi
	pop rbx
	pop rsi
	pop rdi
	ret

main:
	sub rsp, 32
	push rsi
	call setup
	cmp rax, 0
	jne main_exit
	mov rcx, QWORD [file_buffer]
	mov rdx, QWORD [file_size]
	lea r8, [new_lines]
	call split_on
	mov rsi, rax
	mov rcx, QWORD [file_buffer]
	mov rdx, rax
	lea r8, [count_group]
	call count_answers
	mov rcx, rax
	call print_u64
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	lea r8, [count_group_all]
	call count_answers
	mov rcx, rax
	call print_u64
	xor rax, rax
main_exit:
	pop rsi
	add rsp, 32
	ret
