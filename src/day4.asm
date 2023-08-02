bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input4.txt", 0
new_lines: db 0xA, 0xA, 0x0


field_count: dq 7
requred_fields: db "byr", 0x0, "iyr", 0x0, "eyr", 0x0, "hgt", 0x0, "hcl", 0x0, "ecl", 0x0, "pid", 0x0

field_validations: dq validate_byr, validate_iyr, validate_eyr, validate_hgt, validate_hcl, validate_ecl, validate_pid

eye_color_count: dq 7
eye_color_valid: db "amb", 0x0, "blu", 0x0, "brn", 0x0, "gry", 0x0, "grn", 0x0, "hzl", 0x0, "oth", 0x0
section .bss
passport_count: resq 1

section .text

extern setup
extern strlen
extern split_on
extern strfind
extern strreplace
extern strlist_contains
extern print_u64
extern parse_u64_cstr

extern file_buffer
extern file_size
extern error_byte

global main

; rcx = ptr, rdx = min, r8 = max
validate_year:
	push rbx
	push rsi
	push rdi
	mov rbx, rcx
	mov rsi, rdx
	mov rdi, r8
	mov BYTE [error_byte], 0
	call parse_u64_cstr
	cmp BYTE [error_byte], PARSE_INT_ERROR
	je validate_year_false
	sub rcx, rbx
	cmp rcx, 4
	jne validate_year_false
	cmp rax, rsi
	jb validate_year_false
	cmp rax, rdi
	ja validate_year_false
	mov rax, 1
	jmp validate_year_exit
validate_year_false:
	xor rax, rax
validate_year_exit:
	pop rdi
	pop rsi
	pop rbx
	ret

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

validate_hgt:
	push rbx
	mov rbx, rcx
	mov BYTE [error_byte], 0
	call parse_u64_cstr
	cmp BYTE [error_byte], PARSE_INT_ERROR
	je validate_hgt_false
	cmp BYTE [rcx], 0x63
	je validate_hgt_cm
	cmp BYTE [rcx], 0x69
	jne validate_hgt_false
	cmp BYTE [rcx + 1], 0x6e
	jne validate_hgt_false
	cmp rax, 59
	jb validate_hgt_false
	cmp rax, 76
	ja validate_hgt_false
validate_hgt_true:
	mov rax, 1
	jmp validate_hgt_exit
validate_hgt_cm:
	cmp BYTE [rcx + 1], 0x6d
	jne validate_hgt_false
	cmp rax, 150
	jb validate_hgt_false
	cmp rax, 193
	jbe validate_hgt_true
validate_hgt_false:
	xor rax, rax
validate_hgt_exit:
	pop rbx
	ret

validate_hcl:
	cmp BYTE [rcx], 0x23
	jne validate_hcl_false
	lea rdx, [rcx + 7]
	mov rax, 1
validate_hcl_loop:
	inc rcx
	cmp rcx, rdx
	je validate_hcl_exit
	mov r8b, BYTE [rcx]
	cmp r8b, 0x30
	jb validate_hcl_false
	cmp r8b, 0x39
	jbe validate_hcl_loop
	cmp r8b, 0x61
	jb validate_hcl_false
	cmp r8b, 0x66
	jbe validate_hcl_loop
validate_hcl_false:
	xor rax, rax
validate_hcl_exit:
	ret

validate_ecl:
	sub rsp, 16
	push rbx
	mov rbx, rcx
	call strlen
	cmp rax, 3
	je validate_ecl_good_len
	mov rcx, rbx
	mov rdx, 0x20
	call strfind
	sub rax, rbx
	cmp rax, 3
	jne validate_ecl_false
validate_ecl_good_len:
	mov eax, DWORD [rbx]
	mov DWORD [rsp + 8], eax
	mov BYTE [rsp + 11], 0
	lea rcx, [rsp + 8]
	lea rdx, [eye_color_valid]
	mov r8, QWORD [eye_color_count]
	call strlist_contains
	cmp rax, 0
	je validate_ecl_false
	mov rax, 1
	jmp validate_ecl_exit
validate_ecl_false:
	xor rax, rax
validate_ecl_exit:
	pop rbx
	add rsp, 16
	ret

validate_pid:
	xor r8, r8
validate_pid_loop:
	cmp BYTE [rcx], 0x20
	je validate_pid_done
	cmp BYTE [rcx], 0x0
	je validate_pid_done
	cmp BYTE [rcx], 0x30
	jb validate_pip_false
	cmp BYTE [rcx], 0x39
	ja validate_pip_false
	inc r8
	inc rcx
	jmp validate_pid_loop
validate_pid_done:
	mov rax, 1
	cmp r8, 9
	je validate_pid_exit
validate_pip_false:
	xor rax, rax
validate_pid_exit:
	ret

; rcx = ptr to input
valid_passport:
	push rbx
	push rsi
	push rdi
	xor rsi, rsi
	xor rdi, rdi
	mov rbx, rcx
	mov dl, 0xA
	mov r8b, 0x20
	call strreplace ; Replace '\n' with ' '
valid_passport_loop:
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
	je valid_passport_next
	add rsi, 1
	lea rcx, [requred_fields]
	sub rax, rcx
	lea rcx, [field_validations]
	lea rax, [rcx + 2 * rax]
	mov rcx, rbx
	call QWORD [rax]
	cmp eax, 0
	je valid_passport_next
valid_passport_valid_field:
	inc rdi
valid_passport_next:
	mov rcx, rbx
	mov dl, 0x20
	call strfind
	cmp rax, 0
	je valid_passport_exit
	lea rbx, [rax + 1]
	jmp valid_passport_loop
valid_passport_exit:
	cmp rsi, 7
	sete al
	cmp rdi, 7
	sete cl
	pop rdi
	pop rsi
	pop rbx
	ret

; rcx = input buffer
; rdx = input count
parse:
	sub rsp, 8
	push r12
	push rbx
	push rsi
	push rdi
	mov rbx, rcx 
	mov rsi, rdx
	xor rdi, rdi
parse_loop:
	cmp rsi, 0
	je parse_exit
	mov rcx, rbx
	call strlen
	mov rcx, rbx
	lea rbx, [rbx + rax + 2]
	call valid_passport
	cmp al, 0
	je parse_loop_next
	inc rdi
	cmp cl, 0
	je parse_loop_next
	inc r12
parse_loop_next:
	dec rsi
	jmp parse_loop
parse_exit:
	mov rax, rdi
	mov rcx, r12
	pop rdi
	pop rsi
	pop rbx
	pop r12
	add rsp, 8
	ret


main:
	sub rsp, 32
	push rsi
	call setup
	cmp rax, 0
	jne main_exit
	mov rcx, QWORD [file_buffer]
	mov rdx, QWORD [file_size]
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
main_exit:
	pop rsi
	add rsp, 32
	ret