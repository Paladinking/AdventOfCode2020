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
extern listb_contains

global main


; rcx = ptr to group
count_group:
	sub rsp, 40
	push rsi
	push rbx
	mov rbx, rcx
	xor rsi, rsi
count_group_loop:
	mov cl, BYTE [rbx]
	cmp cl, 0
	je count_group_exit
	cmp cl, 0x61
	jb count_group_next
	cmp cl, 0x7a
	ja count_group_next
	lea rdx, [rsp + 16]
	mov r8, rsi
	call listb_contains
	cmp rax, 0
	jne count_group_next
	lea rdx, [rsp + rsi + 16]
	mov cl, BYTE [rbx]
	mov BYTE [rdx], cl
	inc rsi
count_group_next:
	inc rbx
	jmp count_group_loop
count_group_exit:
	mov rax, rsi
	mov rcx, rbx
	pop rbx
	pop rsi
	add rsp, 40
	ret


count_group_all:
	sub rsp, 40
	push rsi
	push rbx
	mov rbx, rcx
	mov rsi, 1
	vpxor ymm0, ymm0
	vmovdqu YWORD [rsp + 16], ymm0
count_group_all_loop:
	mov cl, BYTE [rbx]
	cmp cl, 0
	je count_group_all_sum
	cmp cl, 0xA
	jne count_group_all_az
	inc rsi
	jmp count_group_all_next
count_group_all_az:
	sub cl, 0x61
	and rcx, 0xff
	inc BYTE [rsp + rcx + 16]
count_group_all_next:
	inc rbx
	jmp count_group_all_loop
count_group_all_sum:
	movq xmm0, rsi
	vpbroadcastb ymm0, xmm0
	vpcmpeqb ymm0, YWORD [rsp + 16]
	vpmovmskb rax, ymm0
	popcnt rax, rax 
count_group_all_exit:
	mov rcx, rbx
	pop rbx
	pop rsi
	add rsp, 40
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
main_exit:
	xor rax, rax
	pop rsi
	add rsp, 32
	ret