include 'format.inc'

section '.rdata' data readable
input: db "..\input\input12.txt", 0
input_format: db "cq", 0

include 'stddata.inc'

section '.text' code readable executable

include 'stdasm.inc'

; rcx = start of list
; rdx = number of lines
proc move_waypoint uses rbx rdi rsi
	xor r8, r8	; r8 = x
	xor r9, r9  ; r9 = y
	mov r11, rdx
	mov rdi, 10	; rdi = w_x
	mov rsi, 1	; rsi = w_y
	sub rcx, 9
	mov rbx, 90
 .loop:
	cmp r11, 0
	je .done
	dec r11
	add rcx, 9
	mov al, BYTE [rcx]
	cmp al, 'N'
	je .north
	cmp al, 'S'
	je .south
	cmp al, 'E'
	je .east
	cmp al, 'W'
	je .west
	cmp al, 'F'
	je .forward
	cmp al, 'R'
	je .right
	cmp al, 'L'
	je .left
	int3
 .north:
	add rsi, QWORD [rcx + 1]
	jmp .loop
 .south:
	sub rsi, QWORD [rcx + 1]
	jmp .loop
 .east:
	add rdi, QWORD [rcx + 1]
	jmp .loop
 .west:
	sub rdi, QWORD [rcx + 1]
	jmp .loop
 .forward:
	mov rax, QWORD [rcx + 1]
 .forward_loop:
	cmp rax, 0
	je .loop
	add r8, rdi
	add r9, rsi
	dec rax
	jmp .forward_loop
 .left:
	mov rax, QWORD [rcx + 1]
	xor rdx, rdx
	div rbx
	and rax, 3 ;
 .left_0:
	cmp rax, 0		 ; 90 =  (1) => (x = -y, y =  x)
	je .loop         ; 180 = (2) => (x = -x, y = -y)
 .left_90:           ; 270 = (3) => (x =  y, y = -x)
	cmp rax, 1
	jne .left_180
	neg rsi
	jmp .swap
 .left_180:        
	cmp rax, 2
	jne .left_270
	neg rdi
	neg rsi
	jmp .loop
 .left_270:
	neg rdi
	jmp .swap
 .right:
	mov rax, QWORD [rcx + 1]
	xor rdx, rdx
	div rbx
	and rax, 3
 .right_0:				; 90 =  (1) => (x =  y, y = -x)
	cmp rax, 0          ; 180 = (2) => (x = -x, y = -y)
	je .loop            ; 270 = (3) => (x = -y, y =  x)
 .right_90:
	cmp rax, 1
	jne .right_180
	neg rdi
	jmp .swap
 .right_180:
	cmp rax, 2
	jne .right_270
	neg rdi
	neg rsi
	jmp .loop
 .right_270:
	neg rsi
 .swap:
	mov rax, rsi
	mov rsi, rdi
	mov rdi, rax
	jmp .loop
 .done:
	xor rax, rax
	cmp r8, 0
	jl .x_negative
	add rax, r8
	jmp .add_y
 .x_negative:
	sub rax, r8
 .add_y:
	cmp r9, 0
	jl .y_negative
	add rax, r9
	jmp .exit
 .y_negative:
	sub rax, r9
 .exit:
	ret
endp

; rcx = start of list
; rdx = number of lines
proc move_ship uses rbx
	xor r8, r8	; r8 = x
	xor r9, r9  ; r9 = y
	xor r10, r10 ; 0 = east, 1 = south, 2 = west, 3 = north
	mov r11, rdx
	sub rcx, 9
	mov rbx, 90
 .loop:
	cmp r11, 0
	je .done
	dec r11
	add rcx, 9
	mov al, BYTE [rcx]
	cmp al, 'N'
	je .north
	cmp al, 'S'
	je .south
	cmp al, 'E'
	je .east
	cmp al, 'W'
	je .west
	cmp al, 'F'
	je .forward
	cmp al, 'R'
	je .right
	cmp al, 'L'
	je .left
	int3
 .north:
	add r9, QWORD [rcx + 1]
	jmp .loop
 .south:
	sub r9, QWORD [rcx + 1]
	jmp .loop
 .east:
	add r8, QWORD [rcx + 1]
	jmp .loop
 .west:
	sub r8, QWORD [rcx + 1]
	jmp .loop
 .forward:
	cmp r10, 0
	je .east
	cmp r10, 1
	je .south
	cmp r10, 2
	je .west
	jmp .north
 .left:
	mov rax, QWORD [rcx + 1]
	xor rdx, rdx
	div rbx
	sub r10, rax
	and r10, 3 ; mod 4
	jmp .loop
 .right:
	mov rax, QWORD [rcx + 1]
	xor rdx, rdx
	div rbx
	add r10, rax
	and r10, 3 ; mod 4
	jmp .loop
 .done:
	xor rax, rax
	cmp r8, 0
	jl .x_negative
	add rax, r8
	jmp .add_y
 .x_negative:
	sub rax, r8
 .add_y:
	cmp r9, 0
	jl .y_negative
	add rax, r9
	jmp .exit
 .y_negative:
	sub rax, r9
 .exit:
	ret
endp

proc main uses rsi rdi rbx rbp
	mov rbp, rsp
	sub rsp, 8
	mov rsi, rcx
	mov rdi, rdx
	call split
	mov rbx, rax
	mov rcx, 9
	mul rcx
	call stack_alloc
	mov rcx, rsi
	mov rdx, rsp
	mov r8, rbx
	lea r9, [input_format]
	call parse_lines
	mov rcx, rsp
	mov rdx, rbx
	call move_ship
	mov rcx, rax
	call print_u64
	mov rcx, rsp
	mov rdx, rbx
	call move_waypoint
	mov rcx, rax
	call print_u64
 .exit:
	xor rax, rax
	mov rsp, rbp
	ret
endp
