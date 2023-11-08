include 'format.inc'


section '.rdata' data readable
input: db "..\input\input11.txt", 0

include 'stddata.inc'
; section '.bss'
rows: resq 1
collumns: resq 1


section '.text' code readable executable

include 'stdasm.inc'

macro can_see_seat_def name, deltaX, deltaY {
; rcx = grid base ptr
; rdx = row
; r8 = col
can_see_seat_#name:
	xor r10, r10
	mov r11, QWORD [collumns]
	mov r9, rdx
 .loop:
	match =-1, deltaX \{
		dec r8
		jl .exit
	\}
	match =1, deltaX \{
		inc r8
		cmp r8, r11
		je .exit
	\}
	match =-1, deltaY \{
		dec r9
		jl .exit
	\}
	match =1, deltaY \{
		inc r9
		cmp r9, QWORD [rows]
		je .exit
	\}
	lea rax, [r11 + 1]
	mul r9
	add rax, r8
	mov dl, BYTE [rcx + rax]
	cmp dl, '.'
	je .loop
	cmp dl, 'L'
	je .exit
	inc r10
 .exit:
	mov rax, r10
	ret
}
can_see_seat_def zp, 0, 1
can_see_seat_def zn, 0, -1
can_see_seat_def pz, 1, 0
can_see_seat_def nz, -1, 0
can_see_seat_def nn, -1, -1
can_see_seat_def np, -1, 1
can_see_seat_def pn, 1, -1
can_see_seat_def pp, 1, 1

proc new_value_sight uses rdi rbx r12 rbp
	sub rsp, 8
	mov rdi, rdx
	mov rbx, r8
	xor r12, r12
	mov r11, QWORD [collumns]
	lea rax, [r11 + 1]
	mul rdi
	add rax, rbx
	mov bpl, BYTE [rcx + rax]
	cmp bpl, '.'
	je .exit
	fastcall can_see_seat_zp, rcx, rdi, rbx
	add r12, rax
	fastcall can_see_seat_zn, rcx, rdi, rbx
	add r12, rax
	fastcall can_see_seat_pz, rcx, rdi, rbx
	add r12, rax
	fastcall can_see_seat_nz, rcx, rdi, rbx
	add r12, rax
	fastcall can_see_seat_nn, rcx, rdi, rbx
	add r12, rax
	fastcall can_see_seat_np, rcx, rdi, rbx
	add r12, rax
	fastcall can_see_seat_pn, rcx, rdi, rbx
	add r12, rax
	fastcall can_see_seat_pp, rcx, rdi, rbx
	add r12, rax
	cmp bpl, '#'
	je .occupied
	cmp r12, 0
	ja .exit
	mov bpl, '#'
	jmp .exit
 .occupied:
	cmp r12, 5
	jb .exit
	mov bpl, 'L'
 .exit:
	mov al, bpl
	add rsp, 8
	ret
endp

; rcx = grid base ptr
; Gets new value for (row, col) = (rdx, r8)
new_value_neighbors:
	mov r9, rdx ; r8 = col, r9 = row (rdx is destoryed by mul)
	mov rax, QWORD [collumns]
	inc rax			; Skip null byte
	mov r11, rax	; r11 = collumns + 1
	mul r9
	add rax, r8
	add rcx, rax
	mov r10b, BYTE [rcx]
	cmp r10b, '.'
	je .exit
	add r8, 2	; to compare with rows / collumns
	inc r9		; 
	xor rax, rax
	mov dl, '#'
	cmp r8, 2
	je .centre_noleft
	cmp r8, r11
	je .centre_noright
 .centre_both:
	mov r8, 2
	cmp dl, BYTE [rcx - 1]
	adc rax, 0
	cmp dl, BYTE [rcx + 1]
	adc rax, 0
	sub rcx, r11
	cmp r9, 1
	je .bottom_both
 .top_both:
	add r8, 3
	cmp dl, BYTE [rcx - 1]
	adc rax, 0
	cmp dl, BYTE [rcx]
	adc rax, 0
	cmp dl, BYTE [rcx + 1]
	adc rax, 0
	cmp r9, QWORD [rows]
	je .done
 .bottom_both:
	add r8, 3
	lea rcx, [rcx + 2 * r11]
	cmp dl, BYTE [rcx - 1]
	adc rax, 0
	cmp dl, BYTE [rcx]
	adc rax, 0
	cmp dl, BYTE [rcx + 1]
	adc rax, 0
	jmp .done
 .centre_noleft:
	mov r8, 1
	cmp dl, BYTE [rcx + 1]
	adc rax, 0
	sub rcx, r11
	cmp r9, 1
	je .bottom_noleft
 .top_noleft:
	add r8, 2
	cmp dl, BYTE [rcx]
	adc rax, 0
	cmp dl, BYTE [rcx + 1]
	adc rax, 0
	cmp r9, QWORD [rows]
	je .done
 .bottom_noleft:
	add r8, 2
	lea rcx, [rcx + 2 * r11]
	cmp dl, BYTE [rcx]
	adc rax, 0
	cmp dl, BYTE [rcx + 1]
	adc rax, 0
	jmp .done
 .centre_noright:
	mov r8, 1
	cmp dl, BYTE [rcx - 1]
	adc rax, 0
	sub rcx, r11
	cmp r9, 1
	je .bottom_noright
 .top_noright:
	add r8, 2
	cmp dl, BYTE [rcx]
	adc rax, 0
	cmp dl, BYTE [rcx - 1]
	adc rax, 0
	cmp r9, QWORD [rows]
	je .done
 .bottom_noright:
	add r8, 2
	lea rcx, [rcx + 2 * r11]
	cmp dl, BYTE [rcx]
	adc rax, 0
	cmp dl, BYTE [rcx - 1]
	adc rax, 0
 .done:
	cmp r10b, 'L'
	jne .occupied
	cmp rax, r8
	jne .exit
	mov r10b, '#'
	jmp .exit
 .occupied:
	sub r8, rax
	cmp r8, 4
	jb .exit
	mov r10b, 'L'
 .exit:
	mov al, r10b
	ret

; performs one iteration
; rcx = ptr to grid
; rdx = ptr to output
; r8 = ptr to next_value fn
; 0 on no change, >0 on changes
proc iterate_grid uses rsi rdi rbx r12 r13 r14 r15 rbp
	sub rsp, 8
	mov rsi, rcx
	mov rdi, rdx
	mov rbx, QWORD [collumns]
	mov r14, rcx
	xor r12, r12
	xor r15, r15
	mov rbp, r8
 .loop:
	xor r13, r13
 .inner:
	mov rcx, rsi
	mov rdx, r12
	mov r8, r13
	call rbp ; call new_value
	mov BYTE [rdi], al
	cmp al, BYTE [r14]
	je .inner_no_change
	inc r15
 .inner_no_change:
	mov rax, rdi
	inc r13
	inc rdi
	inc r14
	cmp r13, rbx ; x < collumns?
	jb .inner
	inc r12
	inc rdi ; Skip null byte
	inc r14
	cmp r12, QWORD [rows] ; y < rows?
	jb .loop
 .exit:
	mov rax, r15
	add rsp, 8
	ret
endp

; rcx = ptr to first buffer
; rdx = ptr to second buffer
; r8 = ptr to next_value fn
proc loop_grid uses rsi rdi rbx
	mov rsi, rcx
	mov rdi, rdx
	mov rbx, r8
 .loop:
	call iterate_grid
	cmp rax, 0
	je .done
	mov rdx, rsi
	mov rsi, rdi
	mov rdi, rdx
	mov rcx, rsi
	mov r8, rbx
	jmp .loop
 .done:
	mov rcx, rdi
	mov dl, '#'
	mov r8, QWORD [file_size]
	call memcount
 .exit:
	ret
endp

proc main uses rsi rdi rbx
	mov rsi, rcx
	call split
	mov QWORD [rows], rax
	mov rcx, rsi
	call strlen
	mov QWORD [collumns], rax
	mov rcx, QWORD [file_size]
	call heap_alloc
	mov rbx, rax
	mov rcx, QWORD [file_size]
	call heap_alloc
	mov rdi, rax
	mov rcx, rsi
	mov rdx, rax
	mov r8, QWORD [file_size]
	call memcopy
	mov rcx, rbx
	mov dl, 0
	mov r8, QWORD [file_size]
	call memset
	mov rcx, rsi
	mov rdx, rbx
	lea r8, [new_value_neighbors]
	call loop_grid
	mov rcx, rax
	call print_u64
	mov rcx, rdi
	mov rdx, rbx
	lea r8, [new_value_sight]
	call loop_grid
	mov rcx, rax
	call print_u64
 .exit:
	xor rax, rax
	ret
endp
