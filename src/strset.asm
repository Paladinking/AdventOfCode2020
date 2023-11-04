bits 64
default rel

section .text


extern heap
extern memcopy
extern memmove
extern strcmp
extern strlen
extern HeapAlloc
extern HeapReAlloc
extern HeapFree

; struct strmap {
; 	Node** data;		   + 0
;	DWORD data_len;		   + 8
;	DWORD data_capacity;   + 12
;
;	QWORD buffer;  		   + 16
;	DWORD buffer_len;      + 24
; 	DWORD buffer_capacity; + 28
; };
;
; struct Node {
;	QWORD value;
;	Null terminated key string;
; };
;

; rcx = ptr to strmap memory
strmap_create:
	vpxor ymm0, ymm0
	vmovdqu YWORD [rcx], ymm0
	mov rax, rcx
	ret


; rcx = ptr to strmap, rdx = null-terminated string to find
; return ptr to matching node in rax, final comparison in rcx
; return 0 in rax and non-zero in rcx if map is empty
strmap_find:
	push rsi
	push rbx
	push rdi
	push r12
	sub rsp, 8
	xor rax, rax
	cmp DWORD [rcx + 8], eax
	je strmap_find_exit
	mov rsi, rcx
	mov rbx, rdx
	xor r10, r10
	mov r11d, DWORD [rsi + 8]
strmap_find_loop:
	lea r12, [r10 + r11]
	shr r12, 1
	cmp r10, r12
	mov rdi, QWORD [rsi]
	mov rdi, QWORD [rdi + r12]
	lea rcx, [rdi + 8]
	mov rdx, rbx
	call strcmp
	cmp rax, 0
	je strmap_find_found
	cmp r10, r12
	je strmap_find_found
	cmovb r10, r12
	cmova r11, r12
	jmp strmap_find_loop
strmap_find_found:
	mov rax, rdi
	mov rcx, rax
strmap_find_exit:
	add rsp, 8
	pop r12
	pop rdi
	pop rbx
	pop rsi
	ret


; rcx = ptr to strmap, rdx = desired data_len, r8 = desired data capacity
strmap_size_fix:
	push rsi
	push rbx
	push rdi
	sub rsp, 32
	mov edi, r8d
	mov rsi, rcx
strmap_size_fix_data:
	mov ecx, DWORD [rsi + 12]
	cmp ecx, edx
	jae strmap_size_fix_buffer
	shr rcx, 1
	mov eax, 4
	cmp ecx, 0
	cmove ecx, eax
strmap_size_fix_data_loop:
	shl ecx, 1
	jc strmap_size_fix_exit
	cmp ecx, edx
	jb strmap_size_fix_data_loop
	mov ebx, ecx
	mov rcx, QWORD [heap]
	xor rdx, rdx
	mov r8, QWORD [rsi]
	mov r9d, ebx
	call HeapReAlloc
	cmp rax, 0
	je strmap_size_fix_exit
	mov QWORD [rsi], rax
	mov DWORD [rsi + 12], ebx
strmap_size_fix_buffer:
	mov ecx, DWORD [rsi + 28]
	cmp ecx, edi
	jae strmap_size_fix_exit
	shr rcx, 1
	mov eax, 4
	cmp ecx, 0
	cmove ecx, eax
strmap_size_fix_buffer_loop:
	shl ecx, 1
	jc strmap_size_fix_exit
	cmp ecx, edi
	jb strmap_size_fix_buffer_loop
	mov ebx, ecx
	mov rcx, QWORD [heap]
	xor rdx, rdx
	mov r8, QWORD [rsi + 16]
	mov r9d, ebx
	call HeapReAlloc
	cmp rax, 0
	je strmap_size_fix_exit
	mov QWORD [rsi + 16], rax
	mov DWORD [rsi + 28], ebx
strmap_size_fix_exit:
	add rsp, 32
	pop rdi
	pop rbx
	pop rsi
	ret


; rcx = ptr to strset, rdx = null-terminated string, r8 = value to add
strmap_add:
	push rsi
	push rbx
	push rdi
	push r12
	sub rsp, 8
	mov rsi, rcx
	mov rbx, rdx
	mov r12, r8
	mov rcx, rdx
	call strlen
	mov rdi, rax
	mov rcx, rsi
	mov rdx, QWORD [rsi + 8]
	inc rdx
	mov r8, QWORD [rsi + 24]
	lea r8, [r8 + rdi + 1]
	call strmap_size_fix
	mov rcx, rbx
	mov rdx, QWORD [rsi + 16]
	lea r8, [rdi + 1]
	add DWORD [rsi + 24], r8d ; increase buffer len
	call memcopy
	mov rcx, rsi
	mov rdx, rbx
	call strmap_find
	cmp rax, 0
	je strmap_add_first
	cmp rcx, 0
	jb strmap_add_left
	ja strmap_add_right
	mov QWORD [rax], r12	; Exact match, just replace old value
	jmp strmap_add_exit
strmap_add_left:
	mov rcx, rax
	lea rdx, [rax + 1]
	mov r8, QWORD [rsi]			;
	mov r9d, DWORD [rsi + 8]	; Get remaining length
	lea r8, [r8 + 8 * r9]		;
	sub r8, rax					;
	call memmove
strmap_add_right:

strmap_add_first:
	
strmap_add_exit:
	add rsp, 8
	pop r12
	pop rdi
	pop rbx
	pop rsi
	ret