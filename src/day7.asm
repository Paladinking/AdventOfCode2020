bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input7.txt", 0
target_bag: db "shiny gold", 0

section .bss

; Array, two byte elements, 0 = unknown, 1 = false, >= 2 true
bags: resq 1

section .text

extern print_u64
extern parse_u64_cstr
extern split
extern split_at
extern strlist_extract
extern strlist_sort
extern strfind
extern strlen
extern strcmp
extern binsearch_index
extern memset

extern file_buffer
extern file_size
extern heap
extern HeapAlloc

global main

; rcx = index to line
; rsi = ptr to bag list
; rdi = total number of bags
can_hold_bag:
	push rbp
	push rbx
	push r12
	push r13
	sub rsp, 8
	mov r12, rcx
	mov rbp, QWORD [rsi + 8 * r12]
	mov rcx, QWORD [bags]
	cmp DWORD [rcx + 8 * r12], 0
	jne can_hold_bag_exit
can_hold_bag_unknown:
	inc DWORD [rcx + 8 * r12]
	mov rcx, rbp
	lea rdx, [target_bag]
	call strcmp
	cmp eax, 0
	jne can_hold_bag_not_target
	mov rcx, QWORD [bags]
	inc DWORD [rcx + 8 * r12]
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
	cmp BYTE [rax + 1], "n"
	je can_hold_bag_exit
can_hold_bag_loop:
	lea rbp, [rax + 1]
	mov rcx, rbp
	call parse_u64_cstr
	lea rbp, [rcx + 1]
	mov r13, rax
	mov rcx, rbp
	mov dl, " "
	call strfind
	lea rcx, [rax + 1]
	call strfind
	mov BYTE [rax], 0x0
	mov rcx, rbp
	lea rbp, [rax + 1]
	mov rdx, rsi
	mov r8, rdi
	call binsearch_index
	mov rcx, rax
	mov rbx, rax
	call can_hold_bag
	mov rcx, QWORD [bags]
	mov eax, DWORD [rcx + 8 * rbx + 4]
	mul r13d
	add eax, r13d
	add DWORD [rcx + 8 * r12 + 4], eax
	cmp DWORD [rcx + 8 * rbx], 1
	jbe can_hold_bag_continue
	inc DWORD [rcx + 8 * r12]
can_hold_bag_continue:
	mov rcx, rbp
	mov dl, ","
	call strfind
	inc rax
	cmp rax, 1
	jne can_hold_bag_loop
can_hold_bag_exit:
	add rsp, 8
	pop r13
	pop r12
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
	mov rcx, QWORD [heap]
	xor rdx, rdx
	lea r8, [rdi * 8]
	call HeapAlloc
	cmp rax, 0
	je main_exit
	mov QWORD [bags], rax
	mov rcx, rax
	xor dl, dl
	lea r8, [rdi * 8]
	call memset
	mov rcx, rsi
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
	je main_count
	mov rcx, rbp
	call can_hold_bag
	mov rcx, QWORD [bags]
	mov eax, DWORD [rcx + 8 * rbp]
	cmp eax, 1
	jbe main_loop_false
	inc r12
main_loop_false:
	inc rbp
	jmp main_loop
main_count:
	lea rcx, [target_bag]
	mov rdx, rsi
	mov r8, rdi
	call binsearch_index
	mov rcx, QWORD [bags]
	mov ebp, DWORD [rcx + 8 * rax + 4]
main_print:
	dec r12
	mov rcx, r12
	call print_u64
	mov rcx, rbp
	call print_u64
main_exit:
	xor rax, rax
	add rsp, 40
	pop r12
	pop rbp
	pop rsi
	pop rdi
	ret