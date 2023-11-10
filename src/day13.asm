include 'format.inc'

section '.rdata' data readable
input: db "..\input\input13.txt", 0x0
include 'stddata.inc'

section '.text' code readable executable

include 'stdasm.inc'

; rcx = indata
; rdx = length
proc find_time uses rsi rdi rbx rbp r12
	mov rbp, rcx
	mov rsi, QWORD [rbp]
	mov rdi, QWORD [rbp + 8]
	mov rbx, 2
	mov r12, rdx
 .loop:
	cmp rbx, r12
	je .exit
	xor r8, r8		; a.pos = 0
	xor r9, r9		; b.pos = 0
	mov r11, QWORD [rbp + rbx * 8 + 8]
	mov r10, QWORD [rbp + rbx * 8]
 .inner_loop:
	mov rax, rsi	;
	mul r8			; val_a = a.id * a.pos - a.offset
	sub rax, rdi	; 
	mov rdx, r10		;
	mulx rcx, rdx, r9	; val_b = b.id * b.pos - b.offset
	sub rdx, r11		;
	cmp rax, rdx
	je .loop_next
	jl .inner_loop_lesser
 .inner_loop_greater:
	sub rax, rdx
	xor rdx, rdx
	div r10
	mov rdx, 1
	cmp rax, 0
	cmova rdx, rax
	add r9, rdx
	jmp .inner_loop
 .inner_loop_lesser:
	sub rdx, rax
	mov rax, rdx
	xor rdx, rdx
	div rsi
	mov rdx, 1
	cmp rax, 0
	cmova rdx, rax
	add r8, rdx
	jmp .inner_loop
 .loop_next:
	mov rcx, rsi
	mov rdx, r10 
	mov rdi, rax
	neg rdi
	call lcm
	mov rsi, rax
	add rbx, 2
	jmp .loop
 .exit:
	neg rdi
	mov rax, rdi
	ret
endp

; rcx = departure time
; r8 = bus id
depart_diff:
	xor rdx, rdx
	mov rax, rcx
	div r8
	mov rax, r8
	sub rax, rdx
 .exit:
	ret

; rcx = departure time
; rdx = ptr to input row
; r8 = input length
proc find_route uses rdi rsi rbx
	mov rbx, 0xffffffffffffffff
	mov rsi, rcx
	mov rdi, rdx
	mov r9, r8
 .loop:
	cmp r9, 0
	je .exit
	mov r8, QWORD [rdi]
	call depart_diff
	cmp rbx, rax
	cmova rbx, rax
	cmova r10, r8
	add rdi, 16
	dec r9
	jmp .loop
 .exit:
	mov rax, r10
	mul rbx
	ret
endp

; rcx = ptr to input
; rdx = ptr to output
proc parse uses rdi rsi rbx
	xor rbx, rbx
	mov rsi, rcx
	mov rdi, rdx
 .loop:
	mov dl, BYTE [rsi]
	cmp dl, 'x'
	je .next
	mov rcx, rsi
	call parse_u64_cstr
	mov rsi, rcx
	mov QWORD [rdi], rax
	mov QWORD [rdi + 8], rbx
	add rdi, 16
	dec rsi
 .next:
	add rsi, 2
	inc rbx
	cmp BYTE [rsi - 1], ','
	je .loop
 .exit:
	ret
endp


proc main uses rdi rsi rbx rbp
	sub rsp, 8
	mov rsi, rcx
	mov rdi, rdx
	mov dl, ','
	mov r8, rdi
	call memcount
	mov rbx, rax
	mov rcx, rsi
	mov dl, 'x'
	mov r8, rdi
	call memcount
	sub rbx, rax
	lea rbp, [rbx * 2 + 2]
	lea rcx, [rbp * 8]
	call heap_alloc
	mov rbx, rax
	mov rcx, rsi
	call parse_u64_cstr
	inc rcx
	mov rsi, rcx
	mov rdi, rax
	mov rdx, rbx
	call parse
	mov rcx, rdi
	mov rdx, rbx
	mov r8, rbp
	shr r8, 1
	call find_route
	mov rcx, rax
	call print_u64
	mov rcx, rbx
	mov rdx, rbp
	call find_time
	mov rcx, rax
	call print_u64
 .exit:
	add rsp, 8
	ret
endp
