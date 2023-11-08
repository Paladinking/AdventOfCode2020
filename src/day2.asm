include 'format.inc'

section '.rdata' data readable
input: db "..\input\input2.txt", 0
new_line: db 0xA

include 'stddata.inc'

section '.text' code readable executable

include 'stdasm.inc'

; rcx = in, rdx = line_count 
proc parse uses rdi rbx rsi
	local range_start:DWORD, range_end:DWORD, _align:QWORD
	mov rbx, rdx
	xor rdi, rdi
	xor rsi, rsi
 .loop:
	cmp rbx, 0
	je .exit
	call parse_u64_cstr
	mov DWORD [range_start], eax
	inc rcx
	call parse_u64_cstr
	mov DWORD [range_end], eax
	mov r8d, DWORD [range_start]
	mov r8b, BYTE [rcx + r8 + 3]
	mov al, BYTE [rcx + rax + 3]
	mov r9b, BYTE [rcx + 1]
	cmp al, r8b
	je .validate_pre_loop
	cmp r9b, al
	sete al
	cmp r9b, r8b
	sete r8b
	and rax, 0xff
	and r8b, 0xff
	add rsi, rax
	add rsi, r8
 .validate_pre_loop:
	add rcx, 3
	xor eax, eax
 .validate_loop:
	inc rcx
	cmp BYTE [rcx], 0
	je .validate_done
	cmp BYTE [rcx], r9b
	jne .validate_loop
	inc eax
	jmp .validate_loop
 .validate_done:
	inc rcx
	dec rbx
	cmp eax, DWORD [range_start]
	jb .loop
	cmp eax, DWORD  [range_end]
	ja .loop
	inc rdi
	jmp .loop
 .exit:
	mov rax, rdi
	mov rcx, rsi
	ret
endp

main:
	push rsi
	call split
	mov rcx, QWORD [file_buffer]
	mov rdx, rax
	call parse
	mov rsi, rcx
	mov rcx, rax
	call print_u64
	mov rcx, rsi
	call print_u64
 .exit:
	pop rsi
	ret