include 'format.inc'

section '.rdata' data readable
input: db "..\input\input3.txt", 0
new_line: db 0xA

include 'stddata.inc'

section '.text' code readable executable

include 'stdasm.inc'

; rcx = base_ptr, rdx = rows, r8 = columns
; r13 = down, r14 = right
proc parse uses r12 rdi rbx rsi
	sub rsp, 8
	mov rbx, rdx
	xor r12, r12
	xor rsi, rsi
	xor r9, r9
 .loop:
	; Get offset = row * (columns + 1) + (col % columns)
	xor rdx, rdx
	mov rax, rsi
	div r8
	mov rdi, rdx
	lea rax, [r8 + 1]
	mul r9
	add rax, rdi

	cmp BYTE [rcx + rax], 0x23
	jne .loop_next
	inc r12
 .loop_next:
	add r9, r13
	add rsi, r14
	cmp r9, rbx
	jbe .loop
 .exit:
	mov rax, r12
	add rsp, 8
	ret
endp

proc main uses r13 r14 rbx rsi
	local result:QWORD
	call split
	mov rsi, rax
	mov rcx, QWORD [file_buffer]
	call strlen
 .one_parse:
	mov rcx, QWORD [file_buffer]
	mov rbx, rax
	mov rdx, rsi
	mov r8, rax
	mov r13, 1
	mov r14, 3
	call parse
	mov QWORD [result], rax
	mov rcx, rax
	call print_u64
 .two_parse:
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	mov r8, rbx
	mov r13, 1
	mov r14, 1
	call parse
	mul QWORD [result]
	mov QWORD [result], rax
 .three_parse:
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	mov r8, rbx
	mov r13, 1
	mov r14, 5
	call parse
	mul QWORD [result]
	mov QWORD [result], rax
 .four_parse:
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	mov r8, rbx
	mov r13, 1
	mov r14, 7
	call parse
	mul QWORD [result]
	mov QWORD [result], rax
 .five_parse:
	mov rcx, QWORD [file_buffer]
	mov rdx, rsi
	mov r8, rbx
	mov r13, 2
	mov r14, 1
	call parse
	mul QWORD [result]
	mov rcx, rax
	call print_u64
 .exit:
	xor rax, rax
	ret
endp