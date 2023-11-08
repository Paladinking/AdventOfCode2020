include 'format.inc'

section '.rdata' data readable
input: db "..\input\input7.txt", 0
target_bag: db "shiny gold", 0

include 'stddata.inc'
;section '.bss'

; Array, two byte elements, 0 = unknown, 1 = false, >= 2 true
bags: resq 1

section '.text' code readable executable

include 'stdasm.inc'

; rcx = index to line
; rsi = ptr to bag list
; rdi = total number of bags
proc can_hold_bag uses rbp rbx r12 r13
	sub rsp, 8
	mov r12, rcx
	mov rbp, QWORD [rsi + 8 * r12]
	mov rcx, QWORD [bags]
	cmp DWORD [rcx + 8 * r12], 0
	jne .exit
 .unknown:
	inc DWORD [rcx + 8 * r12]
	mov rcx, rbp
	lea rdx, [target_bag]
	call strcmp
	cmp eax, 0
	jne .not_target
	mov rcx, QWORD [bags]
	inc DWORD [rcx + 8 * r12]
 .not_target:
	mov rcx, rbp
	call strlen
	mov rcx, rbp
	lea rbp, [rcx + rax + 1] ; After name
	mov rcx, rbp
	mov dl, " "
	call strfind
	lea rcx, [rax + 1]
	call strfind
	cmp BYTE [rax + 1], "n"
	je .exit
 .loop:
	lea rbp, [rax + 1]
	mov rcx, rbp
	call parse_u64_cstr
	lea rbp, [rcx + 1]
	mov r13, rax
	mov rcx, rbp
	mov dl, " "
	call strfind
	lea rcx, [rax + 1]
	call strfind
	mov BYTE [rax], 0x0
	mov rcx, rbp
	lea rbp, [rax + 1]
	mov rdx, rsi
	mov r8, rdi
	call binsearch_index
	mov rcx, rax
	mov rbx, rax
	call can_hold_bag
	mov rcx, QWORD [bags]
	mov eax, DWORD [rcx + 8 * rbx + 4]
	mul r13d
	add eax, r13d
	add DWORD [rcx + 8 * r12 + 4], eax
	cmp DWORD [rcx + 8 * rbx], 1
	jbe .continue
	inc DWORD [rcx + 8 * r12]
 .continue:
	mov rcx, rbp
	mov dl, ","
	call strfind
	inc rax
	cmp rax, 1
	jne .loop
 .exit:
	add rsp, 8
	ret
endp


; rsi = ptr to first 
; rdi = total number of lines
proc parse_names uses rsi rdi
	sub rsp, 8
	lea rdi, [rsi + 8 * rdi]
 .loop:
	cmp rsi, rdi
	je .exit
	mov rcx, QWORD [rsi]
	mov dl, " "
	call strfind
	lea rcx, [rax + 1]
	call strfind
	mov BYTE [rcx], 0
	add rsi, 8
	jmp .loop
 .exit:
	add rsp, 8
	ret
endp

proc main uses rdi rsi rbp r12
	sub rsp, 40
	call split
	mov rdi, rax
	mov rcx, rax
	shl rcx, 3
	call heap_alloc
	cmp rax, 0
	je .exit
	mov rsi, rax
	lea rcx, [rdi * 8]
	call heap_alloc
	cmp rax, 0
	je .exit
	mov QWORD [bags], rax
	mov rcx, rax
	xor dl, dl
	lea r8, [rdi * 8]
	call memset
	mov rcx, rsi
	mov rdx, QWORD [file_buffer]
	mov r8, rdi
	call strlist_extract
	call parse_names
	mov rcx, rsi
	mov rdx, rdi
	call strlist_sort
	xor rbp, rbp
	xor r12, r12
 .loop:
	cmp rbp, rdi
	je .count
	mov rcx, rbp
	call can_hold_bag
	mov rcx, QWORD [bags]
	mov eax, DWORD [rcx + 8 * rbp]
	cmp eax, 1
	jbe .loop_false
	inc r12
 .loop_false:
	inc rbp
	jmp .loop
 .count:
	lea rcx, [target_bag]
	mov rdx, rsi
	mov r8, rdi
	call binsearch_index
	mov rcx, QWORD [bags]
	mov ebp, DWORD [rcx + 8 * rax + 4]
 .print:
	dec r12
	mov rcx, r12
	call print_u64
	mov rcx, rbp
	call print_u64
 .exit:
	xor rax, rax
	add rsp, 40
	ret
endp
