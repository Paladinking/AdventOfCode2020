bits 64
default rel

section .rdata
global input
input: db "..\input\input1.txt", 0
format: db "q"


section .bss
numbers: resq 1
numbers_count: resq 1

section .text

extern stack_alloc
extern setup
extern print
extern split
extern file_buffer
extern file_size
extern parse_u64_cstr
extern print_u64
extern parse_lines

global main

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
	push rbp
	mov rbp, rsp
	sub rsp, 32
	call split
	mov QWORD [numbers_count], rax
	shl rax, 3
	call stack_alloc
	mov rcx, QWORD [file_buffer]
	mov rdx, rsp
	mov r8, QWORD [numbers_count]
	lea r9, [format]
	call parse_lines
main_solve:
	mov rbx, rsp
	mov rdi, QWORD [numbers_count]
	call solve
	call print_u64
	call resolve
	call print_u64
	xor rax, rax
main_exit:
	mov rsp, rbp
	pop rbp
	pop rdi
	pop rbx
	ret