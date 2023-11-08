include 'format.inc'

section '.rdata' data readable
input: db "..\input\input5.txt", 0
new_line: db 0xA

include 'stddata.inc'

;section '.bss'
seats: resq 1024

section '.text' code readable executable

include 'stdasm.inc'

; rcx - ptr to seat
proc parse_seat uses rsi
	sub rsp, 8
	mov rsi, 128
	xor edx, edx
	mov r8d, 128
	mov r9d, 7
 .loop:
	mov eax, edx
	add eax, r8d
	shr eax, 1
	cmp BYTE [rcx], 0x46
	je .loop_forward
	cmp BYTE [rcx], 0x4c
	je .loop_forward
	mov edx, eax
	jmp .loop_next
 .loop_forward:
	mov r8d, eax
 .loop_next:
	inc rcx
	dec r9d
	cmp r9d, 0
	ja .loop
	cmp rsi, 128
	jne .done
	mov rsi, rdx
	xor edx, edx
	mov r8d, 8
	mov r9d, 3
	jmp .loop
 .done:
	shl rsi, 3
	add rsi, rdx
	mov rax, rsi
 .exit:
	add rsp, 8
	ret
endp

; rcx: ptr to input, rdx: length
proc parse uses rdi rsi rbx
	lea rdi, [seats]
	xor rbx, rbx
	mov rsi, rdx
 .loop:
	cmp rsi, 0
	je .exit
	call parse_seat
	inc rcx
	dec rsi
	mov QWORD [rdi], rax
	add rdi, 8
	cmp rax, rbx
	cmova rbx, rax
	jmp .loop
 .exit:
	lea rcx, [seats]
	sub rdi, rcx
	shr rdi, 3
	mov rcx, rdi
	mov rax, rbx
	ret
endp

	; rcx - number of seats
proc find_seat uses rdi rbx rsi
	xor rsi, rsi
	mov rbx, rcx
	xor dil, dil
 .loop:
	cmp rsi, 1024
	je .exit
	mov rcx, rsi
	lea rdx, [seats]
	mov r8, rbx
	call listq_contains
	cmp rax, 0
	je .not_found
	mov dil, 1
	jmp .next
 .not_found:
	cmp dil, 0
	jne .exit
	xor dil, dil
 .next:
	inc rsi
	jmp .loop
 .exit:
	mov rax, rsi
	ret
endp

proc main uses rsi rbx
	sub rsp, 24
	call split
	mov rcx, QWORD [file_buffer]
	mov rdx, rax
	call parse
	mov rsi, rax
	mov rbx, rcx
	mov rcx, rax
	call print_u64
	mov rcx, rbx
	call find_seat
	mov rcx, rax
	call print_u64
	xor rax, rax
	add rsp, 24
	ret
endp
