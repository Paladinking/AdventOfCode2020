include 'format.inc'

define PREAMBLE 25

section '.rdata' data readable
input: db "..\input\input9.txt", 0

include 'stddata.inc'

section '.text' code readable executable

include 'stdasm.inc'

; rcx = ptr to input
; rdx = ptr to output
; r8 = line count
proc parse uses rsi rbx
	sub rsp, 8
	mov rbx, rdx
	lea rsi, [rdx + 8 * r8]
 .loop:
	cmp rbx, rsi
	je .exit
	call parse_u64_cstr
	mov QWORD [rbx], rax
	inc rcx
	add rbx, 8
	jmp .loop
 .exit:
	add rsp, 8
	ret
endp

; rcx = ptr to PREAMBLE last numbers
; rdx = number to check for, remains
contains_sum:
	xor r8, r8
 .outer:
	cmp r8, PREAMBLE
	je .end
	mov rax, QWORD [rcx + 8 * r8]
	lea r9, [r8 + 1]
 .inner:
	cmp r9, PREAMBLE
	je .outer_next
	mov r10, rax
	add r10, QWORD [rcx + 8 * r9]
	inc r9
	cmp r10, rdx
	jne .inner
	mov rax, 1
	jmp .exit
 .outer_next:
	inc r8
	jmp .outer
 .end:
	xor rax, rax
 .exit:
	ret

; rcx = ptr to numbers
; Stack gets missaligned if PREAMBLE is even...
proc find_number uses rsi rbx rbp
	sub rsp, PREAMBLE * 8 + 8 
	xor rbx, rbx
	mov rsi, rcx
 .preamble_loop:
	mov rax, QWORD [rsi + 8 * rbx]
	mov QWORD [rsp + 8 * rbx], rax
	inc rbx
	cmp rbx, PREAMBLE
	jb .preamble_loop
	xor rbp, rbp
 .loop:
	mov rdx, QWORD [rsi + 8 * rbx]
	mov rcx, rsp
	call contains_sum
	cmp rax, 0
	je .found
	mov QWORD [rsp + 8 * rbp], rdx
	inc rbx
	inc rbp
	xor rdx, rdx
	cmp rbp, PREAMBLE
	cmove rbp, rdx
	jmp .loop
 .found:
	mov rax, rdx
 .exit:
	add rsp, PREAMBLE * 8 + 8
	ret
endp

; rcx = ptr to numbers
; rdx = number to find
find_number_range:
	mov r8, rcx ; base
 .loop:
	mov rax, QWORD [r8]
	mov r9, rax
	mov r10, rax
	lea rcx, [r8 + 8]
	mov r8, rcx
 .inner:
	mov r11, QWORD [rcx]
	add rax, r11
	cmp r9, r11
	cmovb r9, r11
	cmp r10, r11
	cmova r10, r11
	cmp rax, rdx
	je .exit
	ja .loop
	add rcx, 8
	jmp .inner
 .exit:
	add r9, r10
	mov rax, r9
	ret

proc main uses rbp rdi
	mov rbp, rsp
	sub rsp, 40
	call split
	mov rdi, rax
	shl rax, 3
	call stack_alloc
	mov rcx, QWORD [file_buffer]
	mov rdx, rsp
	mov r8, rdi
	call parse
	mov rcx, rsp
	call find_number
	mov rcx, rax
	mov rdi, rax
	call print_u64
	mov rcx, rsp
	mov rdx, rdi
	call find_number_range
	mov rcx, rax
	call print_u64
	xor rax, rax
 .exit:
	mov rsp, rbp
	ret
endp
