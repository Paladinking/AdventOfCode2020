bits 64
default rel

%define GENERIC_READ 0x80000000
%define OPEN_EXISTING 3
%define FILE_ATTRIBUTE_NORMAL 0x80
%define INVALID_HANDLE_VALUE 0xFFFFFFFFFFFFFFFF

%define PARSE_INT_ERROR 101
%define INVALID_SIZE 102

section .rdata
listx_contains: 
dq 0x0, listb_contains, listw_contains, 0x0, listd_contains, 0x0, 0x0, 0x0, listq_contains

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
global split_on
global strlen
global strcmp
global memcmp
global memset
global memcopy
global parse_u64_cstr
global parse_i64_cstr
global format_u64
global print_u64
global strfind
global strreplace
global strlist_extract
global strlist_sort
global strlist_contains
global list_contains
global listb_contains
global listw_contains
global listd_contains
global listq_contains
global binsearch
global binsearch_index

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

; Buffer rcx, len rdx (not including null)
; Returns number of strings
; null-terminates at '\n'.
; Original string should be null-terminated
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

; char* rcx, char dl
; Replaces '<dl>' with 0x0
; Returns number of strings
split_at:
	mov rax, 1
split_at_loop:
	mov r8b, BYTE [rcx]
	cmp r8b, 0x0
	je split_at_exit
	inc rcx
	cmp r8b, dl
	jne split_at_loop
	inc rax
	mov BYTE [rcx - 1], 0x0
	jmp split_at_loop
split_at_exit:
	ret

; In-buffer rcx, len rdx, string to split on r8.
; Returns number of strings.
split_on:
	push rbx
	push rsi
	push rdi
	push r12
	push r13
	mov rbx, rcx
	lea rsi, [rcx + rdx]
	mov rdi, r8
	mov r12, 1
	mov rcx, r8
	call strlen
	mov r13, rax
	inc rsi
	sub rsi, r13
split_on_loop:
	cmp rbx, rsi
	je split_on_exit
	mov rcx, rbx
	mov rdx, rdi
	mov r8, r13
	call memcmp
	cmp eax, 0
	jne split_on_next
	mov BYTE [rbx], 0x0
	add rbx, r13
	inc r12
	jmp split_on_loop
split_on_next:
	inc rbx
	jmp split_on_loop
split_on_exit:
	mov rax, r12
	pop r13
	pop r12
	pop rdi
	pop rsi
	pop rbx
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

; Converts a string to a 64 bit unsigned.
; rcx: ptr, will point at first non-number after.
parse_u64_cstr:
	xor rax, rax
	mov r9, 10
	mov r8b, BYTE [rcx]
	cmp r8b, 0x30
	jb parse_u64_cstr_error
	cmp r8b, 0x39
	ja parse_u64_cstr_error
parse_u64_cstr_loop:
	sub r8b, 0x30
	mul r9
	jc parse_u64_cstr_error
	and r8, 0xff ; Needed?
	add rax, r8
	inc rcx
	mov r8b, BYTE [rcx]
	cmp r8b, 0x30 
	jb parse_u64_cstr_exit
	cmp r8b, 0x39
	ja parse_u64_cstr_exit
	jmp parse_u64_cstr_loop
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
	mov BYTE [r9 + 1], 0x30
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

print_u64:
	sub rsp, 72
	lea rdx, [rsp + 51]
	mov r8, 20
	call format_u64
	lea rcx, [rsp + 51]
	lea rdx, [rax + 1]
	mov BYTE [rcx + rax], 0xA
	call print	
	add rsp, 72
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

; Set r8 characters from rcx to dl
memset:
	cmp r8, 0
	je memset_exit
	mov BYTE [rcx], dl
	inc rcx
	dec r8
	jmp memset
memset_exit:
	ret

; Move r8 potentialy overlapping characters from rcx to rdx
memmove:
	cmp rcx, rdx
	je memmove_exit
	ja memmove_greater
	lea rcx, [rcx + r8]
	lea rdx, [rdx + r8]
memmove_less:
	cmp r8, 0
	je memmove_exit
	dec rcx
	dec rdx
	dec r8
	mov r9b, BYTE [rcx]
	mov BYTE [rdx], r9b
	jmp memmove_less
memmove_greater:
	cmp r8, 0
	je memmove_exit
	mov r9b, BYTE [rcx]
	mov BYTE [rdx], r9b
	inc rcx
	inc rdx
	dec r8
	jmp memmove_greater
memmove_exit:
	ret



; rcx: buffer 1, rdx: buffer 2, r8: len
memcmp:
	xor eax, eax
	add r8, rcx
memcmp_loop:
	cmp rcx, r8
	je memcmp_exit
	mov al, BYTE [rcx]
	sub al, BYTE [rdx]
	jne memcmp_exit
	inc rcx
	inc rdx
	jmp memcmp_loop
memcmp_exit:
	movsx eax, al
	ret

; Compare two null-terminated strings
; Destroys: rcx, rdx, r8, r9, rax
strcmp:
	mov r8b, BYTE [rcx]
	mov r9b, BYTE [rdx]
	mov al, r8b
	sub al, r9b
	jne strcmp_exit
	cmp r8b, 0
	je strcmp_exit
	cmp r9b, 0
	je strcmp_exit
	inc rcx
	inc rdx
	jmp strcmp
strcmp_exit:
	movsx eax, al
	ret

; rcx = ptr to string, dl = BYTE to replace, r8b = BYTE to write
strreplace:
	cmp BYTE [rcx], 0x0
	je strreplace_end
	cmp BYTE [rcx], dl
	jne strreplace_next
	mov BYTE [rcx], r8b
strreplace_next:
	inc rcx
	jmp strreplace
strreplace_end:
	ret
	
	

; rcx = null-terminated input string
; dl = BYTE to find 
; Returns 0 on fail, ptr on find
strfind:
	xor rax, rax
strfind_loop:
	cmp BYTE [rcx], dl
	je strfind_found
	cmp BYTE [rcx], 0
	je strfind_exit
	inc rcx
	jmp strfind_loop
strfind_found:
	mov rax, rcx
strfind_exit:
	ret



; rcx - value
; rdx - ptr to list
; r8 - length of list
; r9 - size of element (1, 2, 4, 8)
list_contains:
	push rsi
	cmp r9, 8
	ja list_contains_error
	lea rsi, [listx_contains]
	lea rsi, [rsi + r9 * 8]
	cmp QWORD [rsi], 0
	je list_contains_error
	call QWORD [rsi]
	jmp list_contains_exit
list_contains_error:
	mov BYTE [error_byte], INVALID_SIZE
list_contains_exit:
	pop rsi
	ret

listb_contains:
	xor rax, rax
	lea r8, [rdx + r8]
listb_contains_loop:
	cmp rdx, r8
	je listb_contains_exit
	cmp cl, BYTE [rdx]
	je listb_contains_true
	inc rdx
	jmp listb_contains_loop
listb_contains_true:
	mov rax, rdx
listb_contains_exit:
	ret

listw_contains:
	xor rax, rax
	lea r8, [rdx + 2 * r8]
listw_contains_loop:
	cmp rdx, r8
	je listw_contains_exit
	cmp cx, WORD [rdx]
	je listw_contains_true
	add rdx, 2
	jmp listw_contains_loop
listw_contains_true:
	mov rax, rdx
listw_contains_exit:
	ret

listd_contains:
	xor rax, rax
	lea r8, [rdx + 4 * r8]
listd_contains_loop:
	cmp rdx, r8
	je listd_contains_exit
	cmp ecx, DWORD [rdx]
	je listd_contains_true
	add rdx, 4
	jmp listd_contains_loop
listd_contains_true:
	mov rax, rdx
listd_contains_exit:
	ret

listq_contains:
	xor rax, rax
	lea r8, [rdx + 8 * r8]
listq_contains_loop:
	cmp rdx, r8
	je listq_contains_exit
	cmp ecx, DWORD [rdx]
	je listq_contains_true
	add rdx, 8
	jmp listq_contains_loop
listq_contains_true:
	mov rax, rdx
listq_contains_exit:
	ret

; rcx = null-terminated input string
; rdx = ptr to string set
; r8 = size of string set
; Return 0 on fail, ptr on find
strlist_contains:
	push rsi
	push rdi
	push rbx
	mov rsi, rcx
	mov rdi, rdx
	mov rbx, r8
strlist_contains_loop:
	cmp rbx, 0
	je strlist_contains_not_found
	mov rcx, rsi
	mov rdx, rdi
	call strcmp
	cmp rax, 0
	je strlist_contains_found
strlist_contains_next_loop:
	cmp BYTE [rdi], 0
	je strlist_contains_next
	inc rdi
	jmp strlist_contains_next_loop
strlist_contains_next:
	inc rdi
	dec rbx
	jmp strlist_contains_loop
strlist_contains_found:
	mov rax, rdi
	jmp strlist_contains_exit
strlist_contains_not_found:
	xor rax, rax
strlist_contains_exit:
	pop rbx
	pop rdi
	pop rsi
	ret

; Gets a list of pointers from a continuous list of strings.
; rcx = ptr to output
; rdx = ptr to string set
; r8 = length of string set
strlist_extract:
	mov r9, rcx
strlist_extract_loop:
	cmp r8, 0
	je strlist_extract_exit
	mov QWORD [r9], rdx
	add r9, 8
	dec r8
	mov rcx, rdx
	call strlen
	add rdx, rax
	inc rdx
	jmp strlist_extract_loop
strlist_extract_exit:
	ret

; Sorts a list of ptr to null terminated strings
; rcx = ptr to input
; rdx = length of input
strlist_sort:
	push rbp
	mov rbp, rsp
	mov r8, rdx
	inc rdx
	shr rdx, 1
	shl rdx, 4
	sub rsp, rdx
	mov rdx, rsp
	call mergesort
strlist_sort_exit:
	mov rsp, rbp
	pop rbp
	ret


; rcx = ptr to first element of input
; rdx = ptr to second buffer
; r8 = length of input
mergesort:
	push rsi
	push rdi
	push rbp
	cmp r8, 1
	je mergesort_exit
	mov rsi, rcx
	cmp r8, 2
	jne mergesort_divide
	mov rcx, QWORD [rsi]
	mov rdx, QWORD [rsi + 8]
	call strcmp
	cmp eax, 0
	jle mergesort_exit
	mov rcx, QWORD [rsi]
	mov rdx, QWORD [rsi + 8]
	mov QWORD [rsi + 8], rcx
	mov QWORD [rsi], rdx
	jmp mergesort_exit
mergesort_divide:
	mov rdi, rdx
	mov rbp, r8
	shl r8, 3
	call memcopy
	mov rcx, rdi
	mov rdx, rsi
	mov r8, rbp
	shr r8, 1
	call mergesort
	mov r8, rbp
	mov r9, rbp
	shr r9, 1
	sub r8, r9
	lea rcx, [rdi + 8 * r9]
	mov rdx, rsi
	call mergesort
	mov r10, rbp
	mov r11, rbp
	shr r10, 1
	sub r11, r10
	lea rbp, [rdi + 8 * r10]
	mov r10, rbp
	lea r11, [rbp + 8 * r11]
mergesort_merge:
	cmp rdi, r10
	je mergesort_merge_check_second
	cmp rbp, r11
	jne mergesort_merge_cmp
mergesort_merge_first:
	mov rcx, QWORD [rdi]
	mov QWORD [rsi], rcx
	add rsi, 8
	add rdi, 8
	jmp mergesort_merge
mergesort_merge_check_second:
	cmp rbp, r11
	je mergesort_exit
mergesort_merge_second:
	mov rcx, QWORD [rbp]
	mov QWORD [rsi], rcx
	add rsi, 8
	add rbp, 8
	jmp mergesort_merge
mergesort_merge_cmp:
	mov rcx, QWORD [rdi]
	mov rdx, QWORD [rbp]
	call strcmp
	cmp eax, 0
	jle mergesort_merge_first
	jmp mergesort_merge_second
mergesort_exit:
	pop rbp
	pop rdi
	pop rsi
	ret

; rcx = target string
; rdx = ptr to string list
; r8 = size of string list
; Returns: index to target, or -1
binsearch_index:
	push rsi
	mov rsi, rdx
	call binsearch
	cmp rax, 0
	jne binsearch_index_convert
	dec rax
	jmp binsearch_index_exit
binsearch_index_convert:
	sub rax, rsi
	shr rax, 3
binsearch_index_exit:
	pop rsi
	ret

; rcx = target string
; rdx = ptr to string list
; r8 = size of string list
; Returns: ptr to target, or null
binsearch:
	push rsi
	push rdi
	push rbp
	push r12
	push r13
	mov rsi, rcx
	mov rdi, rdx
	mov rbp, r8 ; high
	xor r12, r12 ; low
binsearch_loop:
	lea r13, [rbp + r12]
	shr r13, 1
	cmp r13, r12
	je binsearch_last
	mov rcx, rsi
	mov rdx, QWORD [rdi + 8 * r13]
	call strcmp
	cmp eax, 0
	je binsearch_found
	jg binsearch_greater
	mov rbp, r13
	jmp binsearch_loop
binsearch_greater:
	mov r12, r13
	jmp binsearch_loop
binsearch_last:
	mov rcx, rsi
	mov rdx, QWORD [rdi + 8 * r13]
	call strcmp
	cmp eax, 0
	je binsearch_found
	xor rax, rax
	jmp binsearch_exit
binsearch_found:
	lea rax, [rdi + 8 * r13]
binsearch_exit:
	pop r13
	pop r12
	pop rbp
	pop rdi
	pop rsi
	ret

