include 'format.inc'

section '.rdata' data readable
input: db "..\input\input6.txt", 0
new_lines: db 0xA, 0xA, 0x0

include 'stddata.inc'

section '.text' code readable executable

include 'stdasm.inc'

; rcx = ptr to group
count_group:
	mov r8, rcx
	xor rdx, rdx
 .loop:
	mov cl, BYTE [r8]
	cmp cl, 0
	je .exit
	inc r8
	cmp cl, 0xA
	je .loop
	sub cl, 0x61
	mov rax, 1
	shl rax, cl
	or  rdx, rax
	jmp .loop
 .exit:
	popcnt rax, rdx
	mov rcx, r8
	ret


count_group_all:
	mov r9, rcx
	mov r8, 0xffffffffffffffff
	xor rdx, rdx
 .loop:
	mov cl, BYTE [r9]
	cmp cl, 0
	je .sum
	inc r9
	cmp cl, 0xA
	jne .az
 .inc:
	and r8, rdx
	xor rdx, rdx
	jmp .loop
 .az:
	sub cl, 0x61
	mov rax, 1
	shl rax, cl
	or rdx, rax
	jmp .loop
 .sum:
	and r8, rdx
	popcnt rax, r8 
 .exit:
	mov rcx, r9
	ret


; rcx = ptr, rdx = count, r8 = funcptr
proc count_answers uses rdi rsi rbx
	xor rsi, rsi
	mov rbx, rdx
	mov rdi, r8
 .loop:
	cmp rbx, 0
	je .exit
	call rdi
	add rsi, rax
	add rcx, 2
	dec rbx
	jmp .loop
 .exit:
	mov rax, rsi
	ret
endp

proc main uses rsi
	sub rsp, 32
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
	add rsp, 32
	ret
endp
