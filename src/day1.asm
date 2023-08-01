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
extern print_u64

extern error_byte

extern HeapAlloc
extern HeapFree
extern GetLastError

global main


; rbx = ptr to out, rcx = ptr to input, 
parse:
	sub rsp, 8
	push rbx
	push rdi
	lea rdi, [rbx + 8 * rdi]
parse_loop:
	cmp rbx, rdi
	je parse_done
	call parse_u64_cstr
	cmp BYTE [error_byte], PARSE_INT_ERROR
	jne parse_loop_next
	mov rax, 2
	jmp parse_exit
parse_loop_next:
	mov QWORD [rbx], rax
	add rbx, 8
	inc rcx
	jmp parse_loop
parse_done:
	xor rax, rax
parse_exit:
	pop rdi
	pop rbx
	add rsp, 8
	ret

; rbx = ptr to numbers, rdi = numbers count
; res in rcx, rax = 0 on succes
solve:
	sub rsp, 8
	push rbx
	push rdi
	lea rcx, [rbx + 8]
	lea rdi, [rbx + 8 * rdi]
solve_loop:
	cmp rbx, rdi
	je solve_fail
solve_loop_2:
	cmp rcx, rdi
	je solve_loop_next
	mov r8, QWORD [rbx]
	add r8, QWORD [rcx]
	cmp r8, 2020
	je solve_done
	add rcx, 8
	jmp solve_loop_2
solve_loop_next:
	add rbx, 8
	lea rcx, [rbx + 8]
	jmp solve_loop
solve_done:
	mov rax, QWORD [rbx]
	mov rcx, QWORD [rcx]
	mul rcx
	mov rcx, rax
	xor rax, rax
	jmp solve_exit
solve_fail:
	mov rax, 3
solve_exit:
	pop rdi
	pop rbx
	add rsp, 8
	ret


; rbx = ptr to numbers, rdi = numbers count
; res in rcx, rax = 0 on succes
resolve:
	sub rsp, 8
	push rbx
	push rdi
	lea rcx, [rbx + 8]
	lea rdx, [rbx + 16]
	lea rdi, [rbx + 8 * rdi]
resolve_loop:
	cmp rbx, rdi
	je resolve_fail
resolve_loop_2:
	cmp rcx, rdi
	je resolve_loop_next
resolve_loop_3:
	cmp rdx, rdi
	je resolve_loop_2_next
	mov r8, QWORD [rbx]
	add r8, QWORD [rcx]
	add r8, QWORD [rdx]
	cmp r8, 2020
	je resolve_done
	add rdx, 8
	jmp resolve_loop_3
resolve_loop_2_next:
	add rcx, 8
	lea rdx, [rcx + 8]
	jmp resolve_loop_2
resolve_loop_next:
	add rbx, 8
	lea rcx, [rbx + 8]
	lea rdx, [rbx + 16]
	jmp resolve_loop
resolve_done:
	mov rax, QWORD [rbx]
	mul QWORD [rdx]
	mul QWORD [rcx]
	mov rcx, rax
	xor rax, rax
	jmp resolve_exit
resolve_fail:
	mov rax, 3
resolve_exit:
	pop rdi
	pop rbx
	add rsp, 8
	ret


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
	call parse
	cmp rax, 0
	jne main_free
main_solve:
	mov rbx, QWORD [numbers]
	mov rdi, QWORD [numbers_count]
	call solve
	cmp rax, 0
	jne main_free
	call print_u64
main_resolve:
	call resolve
	cmp rax, 0
	jne main_free
	call print_u64
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