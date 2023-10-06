bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input7.txt", 0
target_bag: db "shiny gold", 0

section .text

extern setup
extern print_u64
extern split
extern split_at
extern strlist_extract
extern strlist_sort
extern strfind
extern strlen
extern strcmp
extern binsearch

extern file_buffer
extern file_size
extern heap
extern HeapAlloc

global main

; rcx = ptr to line (first char of name)
; rsi = ptr to bag list
; rdi = total number of bags
can_hold_bag:
	push rbp
	push rbx
	sub rsp, 8
	mov rbp, rcx
	lea rdx, [target_bag]
	call strcmp
	cmp eax, 0
	je can_hold_bag_true
can_hold_bag_not_target:
	mov rcx, rbp
	call strlen
	mov rcx, rbp
	lea rbp, [rcx + rax + 1] ; After name
	mov rcx, rbp
	mov dl, " "
	call strfind
	lea rcx, [rax + 1]
	call strfind
	lea rbx, [rax + 1]
	cmp BYTE [rbx], "n"
	je can_hold_bag_false
	cmp BYTE [rbx], "y"
	je can_hold_bag_true
can_hold_bag_loop:
	lea rbp, [rax + 1]
	mov rcx, rbp
	mov dl, " "
	call strfind
	lea rbp, [rax + 1]
	mov rcx, rbp
	call strfind
	lea rcx, [rax + 1]
	call strfind
	mov BYTE [rax], 0x0
	mov rcx, rbp
	lea rbp, [rax + 1]
	mov rdx, rsi
	mov r8, rdi
	call binsearch
	mov rcx, QWORD [rax]
	call can_hold_bag
	cmp eax, 0
	je can_hold_bag_continue
	mov BYTE [rbx], "y"
	jmp can_hold_bag_true
can_hold_bag_continue:
	mov rcx, rbp
	mov dl, ","
	call strfind
	inc rax
	cmp rax, 1
	jne can_hold_bag_loop
	mov BYTE [rbx], "n"
can_hold_bag_false:
	xor rax, rax
	jmp can_hold_bag_exit
can_hold_bag_true:
	mov rax, 1
can_hold_bag_exit:
	add rsp, 8
	pop rbx
	pop rbp
	ret
	

; rsi = ptr to first 
; rdi = total number of lines
parse_names:
	push rsi
	push rdi
	sub rsp, 8
	lea rdi, [rsi + 8 * rdi]
parse_names_loop:
	cmp rsi, rdi
	je parse_names_exit
	mov rcx, QWORD [rsi]
	mov dl, " "
	call strfind
	lea rcx, [rax + 1]
	call strfind
	mov BYTE [rcx], 0
	add rsi, 8
	jmp parse_names_loop
parse_names_exit:
	add rsp, 8
	pop rdi
	pop rsi
	ret

main:
	push rdi
	push rsi
	push rbp
	push r12
	sub rsp, 40
	call setup
	cmp rax, 0
	jne main_exit
	mov rcx, QWORD [file_buffer]
	mov rdx, QWORD [file_size]
	call split
	mov rcx, QWORD [heap]
	xor rdx, rdx
	mov rdi, rax
	mov r8, rax
	shl r8, 3
	call HeapAlloc
	cmp rax, 0
	je main_exit
	mov rsi, rax
	mov rcx, rax
	mov rdx, QWORD [file_buffer]
	mov r8, rdi
	call strlist_extract
	call parse_names
	mov rcx, rsi
	mov rdx, rdi
	call strlist_sort
	xor rbp, rbp
	xor r12, r12
main_loop:
	cmp rbp, rdi
	je main_print
	mov rcx, QWORD [rsi + 8 * rbp]
	call can_hold_bag
	cmp rax, 0
	je main_loop_false
	inc r12
main_loop_false:
	inc rbp
	jmp main_loop
main_print:
	dec r12
	mov rcx, r12
	call print_u64
main_exit:
	xor rax, rax
	add rsp, 40
	pop r12
	pop rbp
	pop rsi
	pop rdi
	ret