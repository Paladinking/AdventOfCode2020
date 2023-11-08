include 'format.inc'

section '.rdata' data readable
input: db "..\input\input8.txt", 0

include 'stddata.inc'

section '.text' code readable executable

include 'stdasm.inc'

; rcx = ptr to input
; rdx = ptr to save visited
; r8 = length of program
; rax => acc, rcx => index
proc parse uses rsi rdi rbx rbp r12
	mov rsi, rcx
	mov rdi, rdx
	mov r12, r8
	xor rbx, rbx
	xor rbp, rbp
 .loop:
	cmp rbx, r12
	jae .exit
	cmp BYTE [rdi + rbx], 1
	je .exit
	mov BYTE [rdi + rbx], 1
	mov rcx, QWORD [rsi + 8 * rbx]
	mov edx, DWORD [rcx]
	cmp edx, "nop "
	je .loop_nop
	add rcx, 4
	cmp edx, "acc "
	je .loop_acc
	call parse_i64_cstr
	add rbx, rax
	jmp .loop
 .loop_acc:
	call parse_i64_cstr
	add rbp, rax
 .loop_nop:
	inc rbx
	jmp .loop
 .exit:
	mov rax, rbp
	mov rcx, rbx
	ret
endp


; rcx = ptr to input
; rdx = ptr to save visited
; r8 = length of program
; returns final acc
proc fix_program uses rsi rdi rbx r12 r13
	mov rsi, rcx
	mov rdi, rdx
	mov rbx, r8
	xor r12, r12
 .loop:
	mov rcx, QWORD [rsi + 8 * r12]
	mov r13d, DWORD [rcx]
	cmp r13d, "acc "
	je .loop_next
	mov eax, "jmp "
	mov edx, "nop "
	cmp r13d, "nop "
	cmove edx, eax
	mov DWORD [rcx], edx
	mov rcx, rdi
	mov dl, 0
	mov r8, rbx
	call memset
	mov rcx, rsi
	mov rdx, rdi
	mov r8, rbx
	call parse
	cmp rcx, rbx
	jae .exit
	mov rcx, QWORD [rsi + 8 * r12]
	mov DWORD [rcx], r13d
 .loop_next:
	inc r12
	jmp .loop
 .exit:
	ret
endp

proc main uses rbp rdi rsi
	mov rbp, rsp
	sub rsp, 32
	call split
	mov rdi, rax
	lea rax, [rax + 8 * rax]
	call stack_alloc
	lea rcx, [rsp + 8 * rdi]
	mov dl, 0
	lea r8, [rdi]
	call memset
	mov rcx, rsp
	mov rdx, QWORD [file_buffer]
	mov r8, rdi
	call strlist_extract
	mov rcx, rsp
	lea rdx, [rsp + 8 * rdi]
	mov r8, rdi
	call parse
	mov rcx, rax
	call print_u64
	mov rcx, rsp
	lea rdx, [rsp + 8 * rdi]
	mov r8, rdi
	call fix_program
	mov rcx, rax 
	call print_u64
	xor rax, rax
 .exit:
	mov rsp, rbp
	ret
endp
