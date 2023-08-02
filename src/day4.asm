bits 64
default rel

%define PARSE_INT_ERROR 101

section .rdata
global input
input: db "..\input\input_test.txt", 0
new_lines: db 0xA, 0xA, 0x0


field_count: dq 7
requred_fields: db "byr", 0x0, "iyr", 0x0, "eyr", 0x0, "hgt", 0x0, "hcl", 0x0, "ecl", 0x0, "pid", 0x0

section .bss
passport_count: resq 1

section .text

extern setup
extern strlen
extern split_on
extern print
extern strfind
extern strreplace
extern strlist_contains

extern file_buffer
extern file_size

global main

; rcx = ptr to input
valid_passport:
	push rbx
	push rsi
	xor rsi, rsi
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
	setne al
	and rax, 0xff
	add rsi, rax
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
	and rax, 0xff
	pop rsi
	pop rbx
	ret

; rcx = input buffer
; rdx = input count
parse:
	


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
	call valid_passport
main_exit:
	pop rsi
	add rsp, 32
	ret