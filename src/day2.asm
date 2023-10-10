bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input2.txt", 0
new_line: db 0xA
format: db "qpqpcppsl", 0x0, 0x0

section .text

extern split
extern file_buffer
extern file_size
extern parse_u64_cstr
extern print_u64
extern stack_alloc
extern parse_lines

global main

; rcx = in, rdx = line_count 
parse:
	sub rsp, 16
	push rdi
	push rbx
	push rsi
	mov rbx, rdx
	xor rdi, rdi
	xor rsi, rsi
parse_loop:
	cmp rbx, 0
	je parse_exit
	call parse_u64_cstr
	mov DWORD [rsp + 24], eax
	inc rcx
	call parse_u64_cstr
	mov DWORD [rsp + 28], eax
	mov r8d, DWORD [rsp + 24]
	mov r8b, BYTE [rcx + r8 + 3]
	mov al, BYTE [rcx + rax + 3]
	mov r9b, BYTE [rcx + 1]
	cmp al, r8b
	je parse_validate_pre_loop
	cmp r9b, al
	sete al
	cmp r9b, r8b
	sete r8b
	and rax, 0xff
	and r8b, 0xff
	add rsi, rax
	add rsi, r8
parse_validate_pre_loop:
	add rcx, 3
	xor eax, eax
parse_validate_loop:
	inc rcx
	cmp BYTE [rcx], 0
	je parse_validate_done
	cmp BYTE [rcx], r9b
	jne parse_validate_loop
	inc eax
	jmp parse_validate_loop
parse_validate_done:
	inc rcx
	dec rbx
	cmp eax, DWORD [rsp + 24]
	jb parse_loop
	cmp eax, DWORD  [rsp + 28]
	ja parse_loop
	inc rdi
	jmp parse_loop
parse_exit:
	mov rax, rdi
	mov rcx, rsi
	pop rsi
	pop rbx
	pop rdi
	add rsp, 16
	ret

main:
	sub rsp, 32
	push rsi
	call split
	mov rcx, QWORD [file_buffer]
	mov rdx, rax
	call parse
	mov rsi, rcx
	mov rcx, rax
	call print_u64
	mov rcx, rsi
	call print_u64
main_exit:
	pop rsi
	add rsp, 32
	ret