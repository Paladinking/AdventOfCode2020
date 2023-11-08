include 'format.inc'

section '.data' data readable writeable
	input: db "..\input\input1.txt", 0
	input_format: db "q"
include 'stddata.inc'
; section '.bss'	
	numbers: resq 1
	numbers_count: resq 1

section '.text' code readable executable
include 'stdasm.inc'

; rbx = ptr to numbers, rdi = numbers count
; res in rcx, rax = 0 on succes
proc solve uses rbx rdi
	sub rsp, 8
	lea rcx, [rbx + 8]
	lea rdi, [rbx + 8 * rdi]
 .loop:
	cmp rbx, rdi
	je .fail
 .loop_2:
	cmp rcx, rdi
	je .loop_next
	mov r8, QWORD [rbx]
	add r8, QWORD [rcx]
	cmp r8, 2020
	je .done
	add rcx, 8
	jmp .loop_2
 .loop_next:
	add rbx, 8
	lea rcx, [rbx + 8]
	jmp .loop
 .done:
	mov rax, QWORD [rbx]
	mov rcx, QWORD [rcx]
	mul rcx
	mov rcx, rax
	xor rax, rax
	jmp .exit
 .fail:
	mov rax, 3
 .exit:
	add rsp, 8
	ret
endp

; rbx = ptr to numbers, rdi = numbers count
; res in rcx, rax = 0 on succes
proc resolve uses rbx rdi
	sub rsp, 8
	lea rcx, [rbx + 8]
	lea rdx, [rbx + 16]
	lea rdi, [rbx + 8 * rdi]
 .loop:
	cmp rbx, rdi
	je .fail
 .loop_2:
	cmp rcx, rdi
	je .loop_next
 .loop_3:
	cmp rdx, rdi
	je .loop_2_next
	mov r8, QWORD [rbx]
	add r8, QWORD [rcx]
	add r8, QWORD [rdx]
	cmp r8, 2020
	je .done
	add rdx, 8
	jmp .loop_3
 .loop_2_next:
	add rcx, 8
	lea rdx, [rcx + 8]
	jmp .loop_2
 .loop_next:
	add rbx, 8
	lea rcx, [rbx + 8]
	lea rdx, [rbx + 16]
	jmp .loop
 .done:
	mov rax, QWORD [rbx]
	mul QWORD [rdx]
	mul QWORD [rcx]
	mov rcx, rax
	xor rax, rax
	jmp .exit
 .fail:
	mov rax, 3
 .exit:
	add rsp, 8
	ret
endp


proc main uses rbx rdi rbp
	mov rbp, rsp
	call split
	mov QWORD [numbers_count], rax
	shl rax, 3
	call stack_alloc
	mov rcx, QWORD [file_buffer]
	mov rdx, rsp
	mov r8, QWORD [numbers_count]
	lea r9, [input_format]
	call parse_lines
 .solve:
	mov rbx, rsp
	mov rdi, QWORD [numbers_count]
	call solve
	call print_u64
	call resolve
	call print_u64
	xor rax, rax
 .exit:
	mov rsp, rbp
	ret
endp
