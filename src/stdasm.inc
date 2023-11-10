export_func file_open, file_read, print, strlen, memcmp, memcopy, split, split_at, split_on,\
	parse_u64_cstr, parse_i64_cstr, heap_alloc, heap_free, format_u64, print_u64, memset, memreplace,\
	memmove, memcount, strcmp, strreplace, strfind, strlist_contains, lcm, stack_alloc, chkstk,\
	setup_main, setup

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
 .exit:
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
proc split_on uses rbx rsi rdi r12 r13
	mov rbx, rcx
	lea rsi, [rcx + rdx]
	mov rdi, r8
	mov r12, 1
	mov rcx, r8
	call strlen
	mov r13, rax
	inc rsi
	sub rsi, r13
 .loop:
	cmp rbx, rsi
	je .exit
	mov rcx, rbx
	mov rdx, rdi
	mov r8, r13
	call memcmp
	cmp eax, 0
	jne .next
	mov BYTE [rbx], 0x0
	add rbx, r13
	inc r12
	jmp .loop
 .next:
	inc rbx
	jmp .loop
 .exit:
	mov rax, r12
	ret
endp

; Converts a string to a 64 bit unsigned.
; rcx: ptr, will point at first non-number after.
parse_u64_cstr:
	xor rax, rax
	mov r9, 10
	mov r8b, BYTE [rcx]
	cmp r8b, 0x30
	jb .error
	cmp r8b, 0x39
	ja .error
 .loop:
	sub r8b, 0x30
	mul r9
	jc .error
	and r8, 0xff ; Needed?
	add rax, r8
	inc rcx
	mov r8b, BYTE [rcx]
	cmp r8b, 0x30 
	jb .exit
	cmp r8b, 0x39
	ja .exit
	jmp .loop
 .error:
	mov BYTE [error_byte], PARSE_INT_ERROR
 .exit:
	ret

; Converts a null-terminated string to a 64 bit signed
; rcx: ptr, will point at null after.
parse_i64_cstr:
	cmp BYTE [rcx], 0x2d
	jne .positive
 .negative:
	inc rcx
	call parse_u64_cstr
	cmp rax, 0
	js .error
	xor r8, r8
	sub r8, rax
	mov rax, r8
	jmp .exit
 .positive:
	cmp BYTE [rcx], 0x2b
	jne .positive_parse
	inc rcx
 .positive_parse:
	call parse_u64_cstr
	cmp rax, 0
	jns .exit
 .error:
	mov BYTE [error_byte], PARSE_INT_ERROR
 .exit:
	ret

; rcx = size in bytes
; returns ptr
proc heap_alloc
	mov r8, rcx
	xor rdx, rdx
	mov rcx, QWORD [process_heap]
	extern_call HeapAlloc
 .exit:
	ret
endp

; rcx = ptr
proc heap_free
	mov r8, rcx
	xor rdx, rdx
	mov rcx, QWORD [process_heap]
	extern_call HeapFree
 .exit:
	ret
endp

; rcx: value, rdx: buffer, r8: buffer size
proc format_u64 uses rbx
	xor rbx, rbx
	mov r9, rdx
	dec r9
	mov rax, rcx
	mov rcx, 10
	cmp r8, 0
	je .error
	add r8, r9
	cmp rax, 0
	jne .loop
	mov BYTE [r9 + 1], 0x30
	mov rbx, 1
	jmp .exit
 .loop:
	cmp rax, 0
	je .move
	cmp r9, r8
	je .error
	xor rdx, rdx
	div rcx
	add rdx, 0x30
	mov BYTE [r8], dl
	inc rbx
	dec r8
	jmp .loop
 .error:
	xor rbx, rbx
 .move:
	lea rcx, [r8 + 1]
	lea rdx, [r9 + 1]
	mov r8, rbx
	call memcopy
 .exit:
	mov rax, rbx
	ret
endp

print_u64:
	sub rsp, 72
	lea rdx, [rsp + 51]
	mov r8, 20
	call format_u64
	lea rcx, [rsp + 51]
	lea rdx, [rax + 1]
	mov BYTE [rcx + rax], 0xA
	call print	
 .exit:
	add rsp, 72
	ret

; Set r8 characters from rcx to dl
memset:
	cmp r8, 0
	je .exit
	mov BYTE [rcx], dl
	inc rcx
	dec r8
	jmp memset
 .exit:
	ret

; rcx = ptr, dl = byte to write
; r8 = number of characters, r9b = what to replace
memreplace:
	cmp r8, 0
	je .exit
	dec r8
	inc rcx
	cmp BYTE [rcx - 1], r9b
	jne memreplace
	mov BYTE [rcx - 1], dl
	jmp memreplace
 .exit:
	ret

; Move r8 potentialy overlapping characters from rcx to rdx
memmove:
	cmp rcx, rdx
	je .exit
	ja .greater
	lea rcx, [rcx + r8]
	lea rdx, [rdx + r8]
 .less:
	cmp r8, 0
	je .exit
	dec rcx
	dec rdx
	dec r8
	mov r9b, BYTE [rcx]
	mov BYTE [rdx], r9b
	jmp .less
 .greater:
	cmp r8, 0
	je .exit
	mov r9b, BYTE [rcx]
	mov BYTE [rdx], r9b
	inc rcx
	inc rdx
	dec r8
	jmp .greater
 .exit:
	ret

; rcx = ptr, dl = byte to count
; r8 = number of characters
memcount:
	xor rax, rax
 .loop:
	cmp r8, 0
	je .exit
	dec r8
	inc rcx
	cmp BYTE [rcx - 1], dl
	jne .loop
	inc rax
	jmp .loop
 .exit:
	ret

; Compare two null-terminated strings
; Destroys: rcx, rdx, r8, r9, rax
strcmp:
	mov r8b, BYTE [rcx]
	mov r9b, BYTE [rdx]
	mov al, r8b
	sub al, r9b
	jne .exit
	cmp r8b, 0
	je .exit
	cmp r9b, 0
	je .exit
	inc rcx
	inc rdx
	jmp strcmp
 .exit:
	movsx eax, al
	ret

; rcx = ptr to string, dl = BYTE to replace, r8b = BYTE to write
strreplace:
	cmp BYTE [rcx], 0x0
	je .exit
	cmp BYTE [rcx], dl
	jne .next
	mov BYTE [rcx], r8b
 .next:
	inc rcx
	jmp strreplace
 .exit:
	ret

; rcx = null-terminated input string
; dl = BYTE to find 
; Returns 0 on fail, ptr on find
strfind:
	xor rax, rax
 .loop:
	cmp BYTE [rcx], dl
	je .found
	cmp BYTE [rcx], 0
	je .exit
	inc rcx
	jmp .loop
 .found:
	mov rax, rcx
 .exit:
	ret

; rcx = null-terminated input string
; rdx = ptr to string set
; r8 = size of string set
; Return 0 on fail, ptr on find
proc strlist_contains uses rsi rdi rbx
	mov rsi, rcx
	mov rdi, rdx
	mov rbx, r8
 .loop:
	cmp rbx, 0
	je .not_found
	mov rcx, rsi
	mov rdx, rdi
	call strcmp
	cmp rax, 0
	je .found
 .next_loop:
	cmp BYTE [rdi], 0
	je .next
	inc rdi
	jmp .next_loop
 .next:
	inc rdi
	dec rbx
	jmp .loop
 .found:
	mov rax, rdi
	jmp .exit
 .not_found:
	xor rax, rax
 .exit:
	ret
endp

macro listn_contains_dec size, char, size_word, reg {
export_func list#char#_contains
list#char#_contains:
	xor rax, rax
	lea r8, [rdx + size * r8]
 .loop:
	cmp rdx, r8
	je .exit 
	cmp reg, size_word [rdx]
	je .true
	add rdx, size
	jmp .loop
 .true:
	mov rax, rdx
 .exit:
	ret
}
listn_contains_dec 1, b, BYTE, cl
listn_contains_dec 2, w, WORD, cx
listn_contains_dec 4, d, DWORD, ecx
listn_contains_dec 8, q, QWORD, rcx

; rcx = target string
; rdx = ptr to string list
; r8 = size of string list
; Returns: index to target, or -1
proc binsearch_index uses rsi
	mov rsi, rdx
	call binsearch
	cmp rax, 0
	jne .convert
	dec rax
	jmp .exit
 .convert:
	sub rax, rsi
	shr rax, 3
 .exit:
	ret
endp

; rcx = target string
; rdx = ptr to string list
; r8 = size of string list
; Returns: ptr to target, or null
proc binsearch uses rsi rdi rbp r12 r13
	mov rsi, rcx
	mov rdi, rdx
	mov rbp, r8 ; high
	xor r12, r12 ; low
 .loop:
	lea r13, [rbp + r12]
	shr r13, 1
	cmp r13, r12
	je .last
	mov rcx, rsi
	mov rdx, QWORD [rdi + 8 * r13]
	call strcmp
	cmp eax, 0
	je .found
	jg .greater
	mov rbp, r13
	jmp .loop
 .greater:
	mov r12, r13
	jmp .loop
 .last:
	mov rcx, rsi
	mov rdx, QWORD [rdi + 8 * r13]
	call strcmp
	cmp eax, 0
	je .found
	xor rax, rax
	jmp .exit
 .found:
	lea rax, [rdi + 8 * r13]
 .exit:
	ret
endp

; Gets a list of pointers from a continuous list of strings.
; rcx = ptr to output
; rdx = ptr to string set
; r8 = length of string set
strlist_extract:
	mov r9, rcx
 .loop:
	cmp r8, 0
	je .exit
	mov QWORD [r9], rdx
	add r9, 8
	dec r8
	mov rcx, rdx
	call strlen
	add rdx, rax
	inc rdx
	jmp .loop
 .exit:
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
 .exit:
	mov rsp, rbp
	pop rbp
	ret


; rcx = ptr to first element of input
; rdx = ptr to second buffer
; r8 = length of input
proc mergesort_str uses rsi rdi rbp
	cmp r8, 1
	je .exit
	mov rsi, rcx
	cmp r8, 2
	jne .divide
	mov rcx, QWORD [rsi]
	mov rdx, QWORD [rsi + 8]
	call strcmp
	cmp eax, 0
	jle .exit
	mov rcx, QWORD [rsi]
	mov rdx, QWORD [rsi + 8]
	mov QWORD [rsi + 8], rcx
	mov QWORD [rsi], rdx
	jmp .exit
 .divide:
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
 .merge:
	cmp rdi, r10
	je .merge_check_second
	cmp rbp, r11
	jne .merge_cmp
 .merge_first:
	mov rcx, QWORD [rdi]
	mov QWORD [rsi], rcx
	add rsi, 8
	add rdi, 8
	jmp .merge
 .merge_check_second:
	cmp rbp, r11
	je .exit
 .merge_second:
	mov rcx, QWORD [rbp]
	mov QWORD [rsi], rcx
	add rsi, 8
	add rbp, 8
	jmp .merge
 .merge_cmp:
	mov rcx, QWORD [rdi]
	mov rdx, QWORD [rbp]
	call strcmp
	cmp eax, 0
	jle .merge_first
	jmp .merge_second
 .exit:
	ret
endp

macro listn_sort_dec size, char, size_word, creg, dreg {
export_func list#char#_sort
list#char#_sort:
	push rbp
	mov rbp, rsp
	mov r8, rdx
	lea rax, [rdx * size]
	call stack_alloc
	mov rdx, rsp
	call mergesort#char#_list
 .exit:
	mov rsp, rbp
	pop rbp
	ret

export_func mergesort#char#_list
; rcx = ptr to first element of input
; rdx = ptr to second buffer
; r8 = length of input
mergesort#char#_list:
	push rsi
	push rdi
	push rbp
	cmp r8, 1
	je .exit
	mov rsi, rcx
	cmp r8, 2
	jne .divide
	mov creg, size_word [rsi]
	mov dreg, size_word [rsi + 8]
	cmp creg, dreg
	jle .exit
	mov size_word [rsi + 8], creg
	mov size_word [rsi], dreg
	jmp .exit
 .divide:
	mov rdi, rdx
	mov rbp, r8
	lea r8, [r8 * size]
	call memcopy
	mov rcx, rdi
	mov rdx, rsi
	mov r8, rbp
	shr r8, 1
	call mergesort#char#_list
	mov r8, rbp
	mov r9, rbp
	shr r9, 1
	sub r8, r9
	lea rcx, [rdi + size * r9]
	mov rdx, rsi
	call mergesort#char#_list
	mov r10, rbp
	mov r11, rbp
	shr r10, 1
	sub r11, r10
	lea rbp, [rdi + size * r10]
	mov r10, rbp
	lea r11, [rbp + size * r11]
 .merge:
	cmp rdi, r10
	je .merge_check_second
	cmp rbp, r11
	jne .merge_cmp
 .merge_first:
	mov creg, size_word [rdi]
	mov size_word [rsi], creg
	add rsi, size
	add rdi, size
	jmp .merge
 .merge_check_second:
	cmp rbp, r11
	je .exit
 .merge_second:
	mov creg, size_word [rbp]
	mov size_word [rsi], creg
	add rsi, size
	add rbp, size
	jmp .merge
 .merge_cmp:
	mov creg, size_word [rdi]
	mov dreg, size_word [rbp]
	cmp creg, dreg
	jle .merge_first
	jmp .merge_second
 .exit:
	pop rbp
	pop rdi
	pop rsi
	ret
}

listn_sort_dec 1, b, BYTE, cl, dl
listn_sort_dec 2, w, WORD, cx, dx
listn_sort_dec 4, d, DWORD, ecx, edx
listn_sort_dec 8, q, QWORD, rcx, rdx

; rcx = a, rdx = b
; rax => lcm(a, b)
lcm:
	mov r8, rcx
	mov r9, rdx
	mov r10, rdx
 .loop:
	cmp r10, 0
	je .exit
	mov rax, rcx
	xor rdx, rdx
	div r10
	mov rcx, r10
	mov r10, rdx
	jmp .loop
 .exit:
	mov rax, r9
	xor rdx, rdx
	div rcx
	mul r8
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
 .exit:
	mov rax, QWORD [rsp + rax]
	jmp rax

chkstk:
	push rcx
	push rax
	cmp  rax, 0x1000
	lea  rcx, [rsp + 0x18]
	jb .exit
 .loop:
	sub rcx, 0x1000
	or qword [rcx], 0
	sub rax, 0x1000
	cmp rax, 0x1000
	ja .loop
 .exit:
	sub rcx,rax
	or qword [rcx], 0
	pop rax
	pop rcx
	ret

setup_main:
	sub rsp, 40
	call setup
	test rax, rax
	jne .exit
	mov rcx, QWORD [file_buffer]
	mov rdx, QWORD [file_size]
	call main
 .exit:
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
	jne .get_size
	extern_call GetLastError
	jmp .exit
 .get_size:
	mov QWORD [file_handle], rax
	mov rcx, rax
	lea rdx, [file_size]
	extern_call GetFileSizeEx
	cmp rax, 0
	jne .heap_alloc
	extern_call GetLastError
	mov QWORD [status], rax
	jmp .close_file
 .heap_alloc:
	mov rcx, QWORD [process_heap]
	mov rdx, 0
	mov r8, QWORD [file_size]
	inc r8
	extern_call HeapAlloc
	cmp rax, 0
	jne .read_file
	mov QWORD [status], 1
	jmp .close_file
 .read_file:
	mov QWORD [file_buffer], rax
	mov rdx, rax
	mov r8, QWORD [file_size]
	lea rcx, [rax + r8]
	mov BYTE [rcx], 0
	mov rcx, QWORD [file_handle]
	call file_read
	cmp rax, 0
	jne .stdin
	extern_call GetLastError
	mov QWORD [status], rax
	jmp .free
 .stdin:
	mov rcx, 0xfffffff5
	extern_call GetStdHandle
	mov QWORD [stdout], rax
	cmp rax, INVALID_HANDLE_VALUE
	jne .close_file
	extern_call GetLastError
	mov QWORD [status], rax
 .free:
	mov rcx, QWORD [process_heap]
	xor rdx, rdx
	mov r8, QWORD [file_buffer]
	extern_call HeapFree
 .close_file:
	mov rcx, QWORD [file_handle]
	extern_call CloseHandle
	mov rax, QWORD [status]
 .exit:
	ret
endp
