bits 64
default rel

%define GENERIC_READ 0x80000000
%define OPEN_EXISTING 3
%define FILE_ATTRIBUTE_NORMAL 0x80
%define INVALID_HANDLE_VALUE 0xFFFFFFFFFFFFFFFF

%define PARSE_INT_ERROR 101

section .data
global error_byte
error_byte: db 0 

section .bss
global heap
global stdout
heap: resq 1
stdout: resq 1

file_size: resq 1
file_buffer: resq 1

section .text

global file_buffer
global file_size

global setup
global print
global split
global strlen
global strcmp
global memcopy
global parse_u64_cstr
global parse_i64_cstr
global format_u64

extern GetProcessHeap
extern HeapAlloc
extern CreateFileA
extern GetFileSizeEx
extern ReadFile
extern GetLastError
extern CloseHandle
extern HeapFree
extern GetStdHandle
extern WriteConsoleA

extern input

; Opens a file, char* in rcx, mode in rdx
file_open:
	sub rsp, 56
	mov r8, 0
	mov r9, 0
	mov QWORD [rsp + 32], OPEN_EXISTING
	mov QWORD [rsp + 40], FILE_ATTRIBUTE_NORMAL
	mov QWORD [rsp + 48], 0
	call CreateFileA
file_open_exit:
	add rsp, 56
	ret

; Read a file to a buffer, rcx file handle, rdx output buffer, r8, size
; Returns bytes read.
file_read:
	sub rsp, 56
	lea r9, [rsp + 48]
	mov QWORD [rsp + 32], 0
	call ReadFile
	cmp rax, 0
	jne file_read_succes
	xor rax, rax
	jmp file_read_exit
file_read_succes:
	mov rax, QWORD [rsp + 48]
file_read_exit:
	add rsp, 56
	ret

print:
	sub rsp, 40
	mov r8, rdx
	mov rdx, rcx
	mov rcx, QWORD [stdout]
	mov r9, 0
	mov QWORD [rsp + 32], 0
	call WriteConsoleA
	add rsp, 40
	ret

; Buffer rcx, len rdx
; Returns number of strings
; null-terminates at '\n'.
split:
	mov rax, 1
	add rdx, rcx
	dec rcx
split_loop:
	inc rcx
	cmp rcx, rdx
	je split_exit
	cmp BYTE [rcx], 0xA ; 0xA == '\n'
	jne split_loop
	inc rax
	mov BYTE [rcx], 0x0
	jmp split_loop
split_exit:
	ret

; Get heap, reads input into file_buffer, 
; size into file_size, gets std_handle
setup:
	sub rsp, 56
	mov QWORD [rsp + 48], 0
	call GetProcessHeap
	mov QWORD [heap], rax
	lea rcx, [input]
	mov rdx, GENERIC_READ
	call file_open
	cmp rax, INVALID_HANDLE_VALUE
	jne setup_get_size
	call GetLastError
	jmp setup_exit
setup_get_size:
	mov QWORD [rsp + 40], rax
	mov rcx, rax
	lea rdx, [file_size]
	call GetFileSizeEx
	cmp rax, 0
	jne setup_heap_alloc
	call GetLastError
	mov QWORD [rsp + 48], rax
	jmp setup_close_file
setup_heap_alloc:
	mov rcx, QWORD [heap]
	mov rdx, 0
	mov r8, QWORD [file_size]
	inc r8
	call HeapAlloc
	cmp rax, 0
	jne setup_read_file
	mov QWORD [rsp + 48], 1
	jmp setup_close_file
setup_read_file:
	mov QWORD [file_buffer], rax
	mov rdx, rax
	mov r8, QWORD [file_size]
	lea rcx, [rax + r8]
	mov BYTE [rcx], 0
	mov rcx, QWORD [rsp + 40]
	call file_read
	cmp rax, 0
	jne setup_stdin
	call GetLastError
	mov QWORD [rsp + 48], rax
	jmp setup_free
setup_stdin:
	mov rcx, 0xfffffff5
	call GetStdHandle
	mov QWORD [stdout], rax
	cmp rax, INVALID_HANDLE_VALUE
	jne setup_close_file
	call GetLastError
	mov QWORD [rsp + 48], rax
setup_free:
	mov rcx, QWORD [heap]
	xor rdx, rdx
	mov r8, QWORD [file_buffer]
	call HeapFree
setup_close_file:
	mov rcx, QWORD [rsp + 40]
	call CloseHandle
	mov rax, QWORD [rsp + 48]
setup_exit:
	add rsp, 56
	ret

; Converts a null-terminated string to a 64 bit unsigned
; rcx: ptr, will point at null after.
parse_u64_cstr:
	xor rax, rax
	mov r9, 10
	mov r8b, BYTE [rcx]
	cmp r8b, 0
	je parse_u64_cstr_error
parse_u64_cstr_loop:
	cmp r8b, 0x30
	jb parse_u64_cstr_error
	cmp r8b, 0x39
	ja parse_u64_cstr_error
	sub r8b, 0x30
	mul r9
	jc parse_u64_cstr_error
	and r8, 0xff ; Needed?
	add rax, r8
	inc rcx
	mov r8b, BYTE [rcx]
	cmp r8b, 0
	jne parse_u64_cstr_loop
	jmp parse_u64_cstr_exit
parse_u64_cstr_error:
	mov BYTE [error_byte], PARSE_INT_ERROR
parse_u64_cstr_exit:
	ret

; Converts a null-terminated string to a 64 bit signed
; rcx: ptr, will point at null after.
parse_i64_cstr:
	cmp BYTE [rcx], 0x2d
	jne parse_i64_cstr_positive
parse_i64_cstr_negative:
	inc rcx
	call parse_u64_cstr
	cmp rax, 0
	js parse_i64_cstr_error
	xor r8, r8
	sub r8, rax
	mov rax, r8
	jmp parse_i64_cstr_exit
parse_i64_cstr_positive:
	call parse_u64_cstr
	cmp rax, 0
	jns parse_i64_cstr_exit
parse_i64_cstr_error:
	mov BYTE [error_byte], PARSE_INT_ERROR
parse_i64_cstr_exit:
	ret

; rcx: value, rdx: buffer, r8: buffer size
format_u64:
	push rbx
	xor rbx, rbx
	mov r9, rdx
	dec r9
	mov rax, rcx
	mov rcx, 10
	cmp r8, 0
	je format_u64_error
	add r8, r9
	cmp rax, 0
	jne format_u64_loop
	mov BYTE [r9], 0
	mov rbx, 1
	jmp format_u64_exit
format_u64_loop:
	cmp rax, 0
	je format_u64_move
	cmp r9, r8
	je format_u64_error
	xor rdx, rdx
	div rcx
	add rdx, 0x30
	mov BYTE [r8], dl
	inc rbx
	dec r8
	jmp format_u64_loop
format_u64_error:
	xor rbx, rbx
format_u64_move:
	lea rcx, [r8 + 1]
	lea rdx, [r9 + 1]
	mov r8, rbx
	call memcopy
format_u64_exit:
	mov rax, rbx
	pop rbx
	ret
	

; stdcall DWORD strlen(BYTE* string)
; Returns the length of a given null-terminated string.
; Destroys: rax, rcx
strlen:
	mov rax, rcx
strlen_loop:
	cmp BYTE [rcx], 0
	je strlen_exit
	inc rcx
	jmp strlen_loop
strlen_exit:
	sub rcx, rax
	mov rax, rcx
	ret

; Copy r8 characters from rcx to rdx
; Destroys: rcx, rdx, r8, r9
memcopy:
	cmp r8, 0
	je memcopy_exit
	mov r9b, BYTE [rcx]
	mov BYTE [rdx], r9b
	inc rcx
	inc rdx
	dec r8
	jmp memcopy
memcopy_exit:
	ret

; Compare two null-terminated strings
; Destroys: rcx, rdx, r8, r9, rax
strcmp:
	mov r8b, BYTE [rcx]
	mov r9b, BYTE [rdx]
	mov al, r8b
	sub al, r9b
	jne strcmp_end
	cmp r8b, 0
	je strcmp_end
	cmp r9b, 0
	je strcmp_end
	inc rcx
	inc rdx
	jmp strcmp
strcmp_end:
	movsx eax, al
	ret
	
	