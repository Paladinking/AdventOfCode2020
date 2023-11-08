export_func file_open, file_read, print, strlen, memcmp, memcopy, split, split_at, split_on,\
	parse_u64_cstr, parse_i64_cstr, heap_alloc, heap_free, format_u64, print_u64, memset, memmove,\
	strcmp, strreplace, strfind, stack_alloc, chkstk, setup_main, setup

include 'parse.inc'	

; Opens a file, char* in rcx, mode in rdx
proc file_open
	extern_call CreateFileA, rcx, rdx, 0, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL
 .exit:
	ret
endp

; Read a file to a buffer, rcx file handle, rdx output buffer, r8, size
; Returns bytes read.
proc file_read
	local written:QWORD
	extern_call ReadFile, rcx, rdx, r8, addr written, 0
	cmp rax, 0
	jne .succes
	xor rax, rax
	jmp .exit
 .succes:
	mov rax, QWORD [written]
 .exit:
	ret
endp

; rcx =  ptr to string
; rdx = length of string
print:
	sub rsp, 104
	mov rax, [gs:0x60]			;
    mov rax, [rax + 0x20]		; Get stdout
    mov r10, [rax + 0x28]		;
	xorps xmm0, xmm0				;
	movups OWORD [rsp + 80], xmm0	; Zero memory for IO_STATUS_BLOCK
	xor r8, r8   ; Zero arguments
	xor r9, r9   ;
	lea rax, [rsp + 80]		  ;
	mov QWORD [rsp + 40], rax ; Give ptr to IO_STATUS_BLOCK 	;
	mov QWORD [rsp + 48], rcx	; Give ptr to string
	mov QWORD [rsp + 56], rdx ; Give string length
	xor rdx, rdx ; Zero argument
	mov QWORD [rsp + 64], r8  ;
	mov QWORD [rsp + 72], r8  ; Zero arguments
	mov rax, 0x8 ; syscall number NtWriteFile
	syscall
	add rsp, 104
	ret

; stdcall DWORD strlen(BYTE* string)
; Returns the length of a given null-terminated string.
; Destroys: rax, rcx
strlen:
	mov rax, rcx
 .loop:
	cmp BYTE [rcx], 0
	je .exit
	inc rcx
	jmp .loop
 .exit:
	sub rcx, rax
	mov rax, rcx
	ret

; rcx: buffer 1, rdx: buffer 2, r8: len
memcmp:
	xor eax, eax
	add r8, rcx
 .loop:
	cmp rcx, r8
	je .exit
	mov al, BYTE [rcx]
	sub al, BYTE [rdx]
	jne .exit
	inc rcx
	inc rdx
	jmp .loop
 .exit:
	movsx eax, al
	ret


; Copy r8 characters from rcx to rdx
; Destroys: rcx, rdx, r8, r9
memcopy:
	cmp r8, 0
	je .exit
	mov r9b, BYTE [rcx]
	mov BYTE [rdx], r9b
	inc rcx
	inc rdx
	dec r8
	jmp memcopy
 .exit:
	ret


; Buffer rcx, len rdx (not including null)
; Returns number of strings
; null-terminates at '\n'.
; Original string should be null-terminated
split:
	mov rax, 1
	add rdx, rcx
	dec rcx
 .loop:
	inc rcx
	cmp rcx, rdx
	je .exit
	cmp BYTE [rcx], 0xA ; 0xA == '\n'
	jne .loop
	inc rax
	mov BYTE [rcx], 0x0
	jmp .loop
 .exit:
	ret


; char* rcx, char dl
; Replaces '<dl>' with 0x0
; Returns number of strings
split_at:
	mov rax, 1
 .loop:
	mov r8b, BYTE [rcx]
	cmp r8b, 0x0
	je .exit
	inc rcx
	cmp r8b, dl
	jne .loop
	inc rax
	mov BYTE [rcx - 1], 0x0
	jmp .loop
 .exit:
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
	cmp BYTE [rcx], 0x2b
	jne parse_i64_cstr_positive_parse
	inc rcx
parse_i64_cstr_positive_parse:
	call parse_u64_cstr
	cmp rax, 0
	jns parse_i64_cstr_exit
parse_i64_cstr_error:
	mov BYTE [error_byte], PARSE_INT_ERROR
parse_i64_cstr_exit:
	ret

; rcx = size in bytes
; returns ptr
proc heap_alloc
	mov r8, rcx
	xor rdx, rdx
	mov rcx, QWORD [process_heap]
	extern_call HeapAlloc
	ret
endp

; rcx = ptr
proc heap_free
	mov r8, rcx
	xor rdx, rdx
	mov rcx, QWORD [process_heap]
	extern_call HeapFree
	ret
endp

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

; Does not even pretend to follow calling conventions...
; rax = stack space to allocate
; afterwards, rsp will have grown to fit allocation
stack_alloc:
	add rax, 16	;
	shr rax, 4	; Align pointer
	shl rax, 4	; 
	sub rax, 8	 ; Include ret address
	call chkstk
	sub rsp, rax
	mov rax, QWORD [rsp + rax]
	jmp rax

chkstk:
	push rcx
	push rax
	cmp  rax, 0x1000
	lea  rcx, [rsp + 0x18]
	jb chkstk_end
chkstk_loop:
	sub rcx, 0x1000
	or qword [rcx], 0
	sub rax, 0x1000
	cmp rax, 0x1000
	ja chkstk_loop
chkstk_end:
	sub rcx,rax
	or qword [rcx], 0
	pop rax
	pop rcx
	ret

setup_main:
	sub rsp, 40
	call setup
	mov rcx, QWORD [file_buffer]
	mov rdx, QWORD [file_size]
	call main
	add rsp, 40
	ret


; Get heap, reads input into file_buffer, 
; size into file_size, gets std_handle
proc setup
	local status:QWORD, file_handle:QWORD
	mov QWORD [status], 0
	extern_call GetProcessHeap
	mov QWORD [process_heap], rax
	lea rcx, [input]
	mov rdx, GENERIC_READ
	call file_open
	cmp rax, INVALID_HANDLE_VALUE
	jne setup_get_size
	extern_call GetLastError
	jmp setup_exit
setup_get_size:
	mov QWORD [file_handle], rax
	mov rcx, rax
	lea rdx, [file_size]
	extern_call GetFileSizeEx
	cmp rax, 0
	jne setup_heap_alloc
	extern_call GetLastError
	mov QWORD [status], rax
	jmp setup_close_file
setup_heap_alloc:
	mov rcx, QWORD [process_heap]
	mov rdx, 0
	mov r8, QWORD [file_size]
	inc r8
	extern_call HeapAlloc
	cmp rax, 0
	jne setup_read_file
	mov QWORD [status], 1
	jmp setup_close_file
setup_read_file:
	mov QWORD [file_buffer], rax
	mov rdx, rax
	mov r8, QWORD [file_size]
	lea rcx, [rax + r8]
	mov BYTE [rcx], 0
	mov rcx, QWORD [file_handle]
	call file_read
	cmp rax, 0
	jne setup_stdin
	extern_call GetLastError
	mov QWORD [status], rax
	jmp setup_free
setup_stdin:
	mov rcx, 0xfffffff5
	extern_call GetStdHandle
	mov QWORD [stdout], rax
	cmp rax, INVALID_HANDLE_VALUE
	jne setup_close_file
	extern_call GetLastError
	mov QWORD [status], rax
setup_free:
	mov rcx, QWORD [process_heap]
	xor rdx, rdx
	mov r8, QWORD [file_buffer]
	extern_call HeapFree
setup_close_file:
	mov rcx, QWORD [file_handle]
	extern_call CloseHandle
	mov rax, QWORD [status]
setup_exit:
	ret
endp

if defined NOT_DEFINED_SYMBOL

global file_buffer
global file_size

global setup
global print
global split
global split_on
global strlen
global strcmp
global stack_alloc
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
global listq_sort
global binsearch
global heap_alloc
global heap_free
global binsearch_index
global setup_main

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
extern main


print_:
	sub rsp, 40
	mov r8, rdx
	mov rdx, rcx
	mov rcx, QWORD [stdout]
	mov r9, 0
	mov QWORD [rsp + 32], 0
	call WriteConsoleA
	add rsp, 40
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
	lea rax, [rdx * 8]
	call stack_alloc
	mov rdx, rsp
	call mergesort_str
strlist_sort_exit:
	mov rsp, rbp
	pop rbp
	ret


; rcx = ptr to first element of input
; rdx = ptr to second buffer
; r8 = length of input
mergesort_str:
	push rsi
	push rdi
	push rbp
	cmp r8, 1
	je mergesort_str_exit
	mov rsi, rcx
	cmp r8, 2
	jne mergesort_str_divide
	mov rcx, QWORD [rsi]
	mov rdx, QWORD [rsi + 8]
	call strcmp
	cmp eax, 0
	jle mergesort_str_exit
	mov rcx, QWORD [rsi]
	mov rdx, QWORD [rsi + 8]
	mov QWORD [rsi + 8], rcx
	mov QWORD [rsi], rdx
	jmp mergesort_str_exit
mergesort_str_divide:
	mov rdi, rdx
	mov rbp, r8
	shl r8, 3
	call memcopy
	mov rcx, rdi
	mov rdx, rsi
	mov r8, rbp
	shr r8, 1
	call mergesort_str
	mov r8, rbp
	mov r9, rbp
	shr r9, 1
	sub r8, r9
	lea rcx, [rdi + 8 * r9]
	mov rdx, rsi
	call mergesort_str
	mov r10, rbp
	mov r11, rbp
	shr r10, 1
	sub r11, r10
	lea rbp, [rdi + 8 * r10]
	mov r10, rbp
	lea r11, [rbp + 8 * r11]
mergesort_str_merge:
	cmp rdi, r10
	je mergesort_str_merge_check_second
	cmp rbp, r11
	jne mergesort_str_merge_cmp
mergesort_str_merge_first:
	mov rcx, QWORD [rdi]
	mov QWORD [rsi], rcx
	add rsi, 8
	add rdi, 8
	jmp mergesort_str_merge
mergesort_str_merge_check_second:
	cmp rbp, r11
	je mergesort_str_exit
mergesort_str_merge_second:
	mov rcx, QWORD [rbp]
	mov QWORD [rsi], rcx
	add rsi, 8
	add rbp, 8
	jmp mergesort_str_merge
mergesort_str_merge_cmp:
	mov rcx, QWORD [rdi]
	mov rdx, QWORD [rbp]
	call strcmp
	cmp eax, 0
	jle mergesort_str_merge_first
	jmp mergesort_str_merge_second
mergesort_str_exit:
	pop rbp
	pop rdi
	pop rsi
	ret

; sorts a list of qword
; rcx = ptr to first element
; rdx = length of input
listq_sort:
	push rbp
	mov rbp, rsp
	mov r8, rdx
	lea rax, [rdx * 8]
	call stack_alloc
	mov rdx, rsp
	call mergesort_qword
listq_sort_exit:
	mov rsp, rbp
	pop rbp
	ret

; rcx = ptr to first element of input
; rdx = ptr to second buffer
; r8 = length of input
mergesort_qword:
	push rsi
	push rdi
	push rbp
	cmp r8, 1
	je mergesort_qword_exit
	mov rsi, rcx
	cmp r8, 2
	jne mergesort_qword_divide
	mov rcx, QWORD [rsi]
	mov rdx, QWORD [rsi + 8]
	cmp rcx, rdx
	jle mergesort_qword_exit
	mov QWORD [rsi + 8], rcx
	mov QWORD [rsi], rdx
	jmp mergesort_qword_exit
mergesort_qword_divide:
	mov rdi, rdx
	mov rbp, r8
	shl r8, 3
	call memcopy
	mov rcx, rdi
	mov rdx, rsi
	mov r8, rbp
	shr r8, 1
	call mergesort_qword
	mov r8, rbp
	mov r9, rbp
	shr r9, 1
	sub r8, r9
	lea rcx, [rdi + 8 * r9]
	mov rdx, rsi
	call mergesort_qword
	mov r10, rbp
	mov r11, rbp
	shr r10, 1
	sub r11, r10
	lea rbp, [rdi + 8 * r10]
	mov r10, rbp
	lea r11, [rbp + 8 * r11]
mergesort_qword_merge:
	cmp rdi, r10
	je mergesort_qword_merge_check_second
	cmp rbp, r11
	jne mergesort_qword_merge_cmp
mergesort_qword_merge_first:
	mov rcx, QWORD [rdi]
	mov QWORD [rsi], rcx
	add rsi, 8
	add rdi, 8
	jmp mergesort_qword_merge
mergesort_qword_merge_check_second:
	cmp rbp, r11
	je mergesort_qword_exit
mergesort_qword_merge_second:
	mov rcx, QWORD [rbp]
	mov QWORD [rsi], rcx
	add rsi, 8
	add rbp, 8
	jmp mergesort_qword_merge
mergesort_qword_merge_cmp:
	mov rcx, QWORD [rdi]
	mov rdx, QWORD [rbp]
	cmp rcx, rdx
	jle mergesort_qword_merge_first
	jmp mergesort_qword_merge_second
mergesort_qword_exit:
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

end if