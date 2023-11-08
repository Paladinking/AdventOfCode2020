include 'format.inc'

section '.rdata' data readable
input: db "..\input\input4.txt", 0
new_lines: db 0xA, 0xA, 0x0


field_count: dq 7
requred_fields: db "byr", 0x0, "iyr", 0x0, "eyr", 0x0, "hgt", 0x0, "hcl", 0x0, "ecl", 0x0, "pid", 0x0

field_validations: dq validate_byr, validate_iyr, validate_eyr, validate_hgt, validate_hcl, validate_ecl, validate_pid

eye_color_count: dq 7
eye_color_valid: db "amb", 0x0, "blu", 0x0, "brn", 0x0, "gry", 0x0, "grn", 0x0, "hzl", 0x0, "oth", 0x0

include 'stddata.inc'
;section '.bss'
passport_count: resq 1

section '.text' code readable executable

include 'stdasm.inc'

; rcx = ptr, rdx = min, r8 = max
proc validate_year uses rbx rsi rdi
	mov rbx, rcx
	mov rsi, rdx
	mov rdi, r8
	mov BYTE [error_byte], 0
	call parse_u64_cstr
	cmp BYTE [error_byte], PARSE_INT_ERROR
	je .false
	sub rcx, rbx
	cmp rcx, 4
	jne .false
	cmp rax, rsi
	jb .false
	cmp rax, rdi
	ja .false
	mov rax, 1
	jmp .exit
 .false:
	xor rax, rax
 .exit:
	ret
endp

validate_byr:
	mov rdx, 1920
	mov r8, 2002
	call validate_year
	ret
	
validate_iyr:
	mov rdx, 2010
	mov r8, 2020
	call validate_year
	ret

validate_eyr:
	mov rdx, 2020
	mov r8, 2030
	call validate_year
	ret

proc validate_hgt uses rbx
	mov rbx, rcx
	mov BYTE [error_byte], 0
	call parse_u64_cstr
	cmp BYTE [error_byte], PARSE_INT_ERROR
	je .false
	cmp BYTE [rcx], 0x63
	je .cm
	cmp BYTE [rcx], 0x69
	jne .false
	cmp BYTE [rcx + 1], 0x6e
	jne .false
	cmp rax, 59
	jb .false
	cmp rax, 76
	ja .false
 .true:
	mov rax, 1
	jmp .exit
 .cm:
	cmp BYTE [rcx + 1], 0x6d
	jne .false
	cmp rax, 150
	jb .false
	cmp rax, 193
	jbe .true
 .false:
	xor rax, rax
 .exit:
	ret
endp

validate_hcl:
	cmp BYTE [rcx], 0x23
	jne .false
	lea rdx, [rcx + 7]
	mov rax, 1
 .loop:
	inc rcx
	cmp rcx, rdx
	je .exit
	mov r8b, BYTE [rcx]
	cmp r8b, 0x30
	jb .false
	cmp r8b, 0x39
	jbe .loop
	cmp r8b, 0x61
	jb .false
	cmp r8b, 0x66
	jbe .loop
 .false:
	xor rax, rax
 .exit:
	ret

proc validate_ecl uses rbx
	sub rsp, 16
	mov rbx, rcx
	call strlen
	cmp rax, 3
	je .good_len
	mov rcx, rbx
	mov rdx, 0x20
	call strfind
	sub rax, rbx
	cmp rax, 3
	jne .false
 .good_len:
	mov eax, DWORD [rbx]
	mov DWORD [rsp + 8], eax
	mov BYTE [rsp + 11], 0
	lea rcx, [rsp + 8]
	lea rdx, [eye_color_valid]
	mov r8, QWORD [eye_color_count]
	call strlist_contains
	cmp rax, 0
	je .false
	mov rax, 1
	jmp .exit
 .false:
	xor rax, rax
 .exit:
	add rsp, 16
	ret
endp

validate_pid:
	xor r8, r8
 .loop:
	cmp BYTE [rcx], 0x20
	je .done
	cmp BYTE [rcx], 0x0
	je .done
	cmp BYTE [rcx], 0x30
	jb .false
	cmp BYTE [rcx], 0x39
	ja .false
	inc r8
	inc rcx
	jmp .loop
 .done:
	mov rax, 1
	cmp r8, 9
	je .exit
 .false:
	xor rax, rax
 .exit:
	ret

; rcx = ptr to input
proc valid_passport uses rbx rsi rdi
	xor rsi, rsi
	xor rdi, rdi
	mov rbx, rcx
	mov dl, 0xA
	mov r8b, 0x20
	call strreplace ; Replace '\n' with ' '
 .loop:
	mov rcx, rbx
	mov dl, 0x3a ; ':'
	call strfind
	mov BYTE [rax], 0x0
	mov rcx, rbx
	lea rbx, [rax + 1]
	lea rdx, [requred_fields]
	mov r8, QWORD [field_count]
	call strlist_contains
	cmp rax, 0
	je .next
	add rsi, 1
	lea rcx, [requred_fields]
	sub rax, rcx
	lea rcx, [field_validations]
	lea rax, [rcx + 2 * rax]
	mov rcx, rbx
	call QWORD [rax]
	cmp eax, 0
	je .next
 .valid_field:
	inc rdi
 .next:
	mov rcx, rbx
	mov dl, 0x20
	call strfind
	cmp rax, 0
	je .exit
	lea rbx, [rax + 1]
	jmp .loop
 .exit:
	cmp rsi, 7
	sete al
	cmp rdi, 7
	sete cl
	ret
endp

; rcx = input buffer
; rdx = input count
proc parse uses r12 rbx rsi rdi
	sub rsp, 8
	mov rbx, rcx 
	mov rsi, rdx
	xor rdi, rdi
 .loop:
	cmp rsi, 0
	je .exit
	mov rcx, rbx
	call strlen
	mov rcx, rbx
	lea rbx, [rbx + rax + 2]
	call valid_passport
	cmp al, 0
	je .loop_next
	inc rdi
	cmp cl, 0
	je .loop_next
	inc r12
 .loop_next:
	dec rsi
	jmp .loop
 .exit:
	mov rax, rdi
	mov rcx, r12
	add rsp, 8
	ret
endp

main:
	sub rsp, 32
	push rsi
	lea r8, [new_lines]
	call split_on
	mov QWORD [passport_count], rax
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
	add rsp, 32
	ret