bits 64
default rel

section .text

extern split
extern parse_u64_cstr
extern parse_i64_cstr
extern memcopy
extern heap_alloc
extern heap_free
extern strfind
extern strlen
extern memcmp
extern ExitProcess

global parse_line
global parse_lines

; FORMAT STRING
; b = unsigned BYTE, size 1	-- not supported
; w = unsigned WORD, size 2	-- not supported
; d = unsigned DWORD, size 4	X
; q = unsigned QWORD, size 8	X
; B signed BYTE, size 1		-- not supported
; W signed WORD, size 2		-- not supported
; D signed DWORD, size 4		X
; Q signed QWORD, size 8		X
; c = one parsed character, size 1		X
; C<n> = <n> parsed characters, size <n>	X
; p = 1 ignored character		X
; P<n> = <n> ignored characters		X
; s<X> = string terminated by <X>, size 8
; i<X> = ignored string terminated by <X>
; V<X><P><n> = varatic arguments <P> terminated by <X>, separated by <n> characters, size 16

; Terminators
;	N<C><C>...0x0 = any value in <C><C>...
; 	k<C><C>...0x0 = all values in <C><C>...
;	l<C> = The character <C>
;	t<n><X>	= <n> occurences of terminator
; Terminators are not skipped! "sl2q" on "Hello21" gives &"Hello", 21


; <n> should be raw number, not 0, not ascii
; <C> means any character (except 0x0)
; <X> means any terminator
; <P> means any pattern, null terminated

; varatic structure
; 	QWORD number of arguments
;   PTR to arguments

; examples
;    "q", 0x0 :
;		just a number
;    "q", "j", 1, "q", "j", 1, "c", 1, "j", 2, "s", 1, ":", 0, 0
;	 "qpqpc", 1, "j", 2, "s", 1, ":", 0x0, 0x0
;		string of the form "4-6 b: bbbdbtbbbj" 
;		note that the final s is followed by null, the string has two nulls at the end.
; 	 "s2:l i2: "
;		wavy bronze bags contain 3 pale black bags, 5 bright turquoise bags, 4 pale orange bags.

; rcx = input buffer
; rdx = output buffer
; r8 = format buffer
; rax = position in input buffer
parse_line:
	push rsi
	push rdi
	push rbx
	push r12
	push r13
	push r14
	sub rsp, 56
	mov rbx, r8
	mov rdi, rdx
	mov rsi, rcx
parse_line_loop:
	mov r9b, BYTE [rbx]
	inc rbx
	cmp r9b, 0x0
	je parse_line_exit
	cmp r9b, "p"
	je parse_line_pass
	cmp r9b, "P"
	je parse_line_passmany
	cmp r9b, "c"
	je parse_line_char
	cmp r9b, "C"
	je parse_line_chars
	cmp r9b, "d"
	je parse_line_dword
	cmp r9b, "q"
	je parse_line_qword
	cmp r9b, "D"
	je parse_line_sdword
	cmp r9b, "Q"
	je parse_line_sqword
	cmp r9b, "s"
	je parse_line_string
	cmp r9b, "i"
	je parse_line_ignore
	cmp r9b, "V"
	je parse_line_var
	jmp error_exit
parse_line_pass:
	inc rsi
	jmp parse_line_loop
parse_line_passmany:
	mov cl, BYTE [rbx]
	inc rbx
	and rcx, 0xFF
	add rsi, rcx
	jmp parse_line_loop
parse_line_char:
	mov cl, BYTE [rsi]
	inc rsi
	mov BYTE [rdi], cl
	inc rdi
	jmp parse_line_loop
parse_line_chars:
	mov r12b, BYTE [rbx]
	inc rbx
	and r12, 0xFF
	mov rcx, rsi
	mov rdx, rdi
	mov r8, r12
	call memcopy
	add rsi, r12
	add rdi, r12
	jmp parse_line_loop
parse_line_dword:
	mov rcx, rsi
	call parse_u64_cstr
	mov DWORD [rdi], eax
	add rdi, 4
	mov rsi, rcx
	jmp parse_line_loop
parse_line_qword:
	mov rcx, rsi
	call parse_u64_cstr
	mov QWORD [rdi], rax
	add rdi, 8
	mov rsi, rcx
	jmp parse_line_loop
parse_line_sdword:
	mov rcx, rsi
	call parse_i64_cstr
	mov DWORD [rdi], eax
	add rdi, 4
	mov rsi, rcx
	jmp parse_line_loop
parse_line_sqword:
	mov rcx, rsi
	call parse_i64_cstr
	mov QWORD [rdi], rax
	add rdi, 8
	mov rsi, rcx
	jmp parse_line_loop
parse_line_string:
	mov rcx, rsi
	mov rdx, rbx
	call find_string
	mov rbx, rdx
	mov r12, rax
	lea rcx, [rax + 1]
	call heap_alloc
	cmp rax, 0
	je error_exit
	mov QWORD [rdi], rax
	add rdi, 8
	mov BYTE [rax + r12], 0x0
	mov rcx, rsi
	mov rdx, rax
	mov r8, r12
	call memcopy
	add rsi, r12
	jmp parse_line_loop
parse_line_ignore:
	mov rcx, rsi
	mov rdx, rbx
	call find_string
	mov rbx, rdx
	add rsi, rax
	jmp parse_line_loop
parse_line_var:
	mov rcx, rbx
	mov r13, rbx
	call skip_terminator
	mov rbx, rax			; Update pattern buffer past var terminator
	mov QWORD [rsp + 16], rsi			; Store input location
	mov rcx, rbx			   ;
	call pattern_size		   ; Get size of one instance of pattern
	mov r14, rax			   ;
	mov QWORD [rsp + 48], rax  ;
	mov QWORD [rsp], 1 ; Store capacity
	mov QWORD [rsp + 32], 1 ; Store remaining capacity
	mov cl, BYTE [rcx + 1]		;
	mov BYTE [rsp + 24], cl		; Store separating characters
	mov rcx, rax				;
	call heap_alloc				;
	cmp rax, 0					; Allocate output buffer	
	je error_exit				;
	mov QWORD [rsp + 8], rax	;
	xor r12, r12
parse_line_var_loop:
	mov rax, r12
	inc r12
	mul r14
	mov rcx, QWORD [rsp + 16]
	mov rdx, QWORD [rsp + 8]
	add rdx, rax
	mov r8, rbx
	call parse_line
	mov QWORD [rsp + 16], rax
	mov rcx, rax
	mov rdx, r13
	call find_string
	cmp rax, 0
	je parse_line_var_done
	mov dl, BYTE [rsp + 24]
	and rdx, 0xFF
	add QWORD [rsp + 16], rdx	; skip <n> characters
	dec QWORD [rsp + 32]
	cmp QWORD [rsp + 32], 0
	jg parse_line_var_loop
	mov rax, QWORD [rsp]
	add QWORD [rsp + 32], rax	; Increase remaining capacity
	add QWORD [rsp], rax		; Increase total capacity
	mov rcx, QWORD [rsp + 48]
	shl rcx, 1
	mov QWORD [rsp + 48], rcx
	call heap_alloc
	mov QWORD [rsp + 40], rax 
	mov rcx, QWORD [rsp + 8]
	mov rdx, rax
	mov r8, QWORD [rsp + 48]
	shr r8, 1
	call memcopy
	mov rcx, QWORD [rsp + 8]
	call heap_free
	mov rcx, QWORD [rsp + 40]
	mov QWORD [rsp + 8], rcx
	jmp parse_line_var_loop
parse_line_var_done:
	mov QWORD [rdi], r12
	mov rax, QWORD [rsp + 8]
	mov QWORD [rdi + 8], rax
	add rdi, 16
	mov rsi, QWORD [rsp + 16]
	mov rcx, rbx
	call pattern_size
	lea rbx, [rcx + 2]
	jmp parse_line_loop
parse_line_exit:
	mov rax, rsi
	add rsp, 56
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rdi
	pop rsi
	ret


; rcx = ptr to null-terminated pattern
; rcx => pointer after pattern (to null-terminator)
; rax => size needed to store result of pattern
pattern_size:
	push rbx
	push rsi
	sub rsp, 8
	mov rbx, rcx
	xor rsi, rsi
pattern_size_loop:
	mov cl, BYTE [rbx]
	inc rbx
	cmp cl, 0x0
	je pattern_size_exit
	cmp cl, "p"
	je pattern_size_loop
	cmp cl, "P"
	je pattern_size_passmany
	cmp cl, "c"
	je pattern_size_char
	cmp cl, "C"
	je pattern_size_chars
	cmp cl, "d"
	je pattern_size_dword
	cmp cl, "q"
	je pattern_size_qword
	cmp cl, "D"
	je pattern_size_dword
	cmp cl, "Q"
	je pattern_size_qword
	cmp cl, "s"
	je pattern_size_string
	cmp cl, "i"
	je pattern_size_ignore
	cmp cl, "V"
	je pattern_size_var
	jmp error_exit
pattern_size_passmany:
	inc rbx
	jmp pattern_size_loop
pattern_size_char:
	inc rsi
	jmp pattern_size_loop
pattern_size_chars:
	mov cl, BYTE [rbx]
	inc rbx
	and cl, 0xFF
	add rsi, rcx
	jmp pattern_size_loop
pattern_size_dword:
	add rsi, 4
	jmp pattern_size_loop
pattern_size_qword:
	add rsi, 8
	jmp pattern_size_loop
pattern_size_string:
	add rsi, 8
pattern_size_ignore:
	mov rcx, rbx
	call skip_terminator
	mov rbx, rax
	jmp pattern_size_loop
pattern_size_var:
	add rsi, 16
	mov rcx, rbx
	call skip_terminator
	mov rbx, rax
	mov rcx, rbx
	call pattern_size
	lea rbx, [rcx + 2]
	jmp pattern_size_loop
pattern_size_exit:
	lea rcx, [rbx - 1]
	mov rax, rsi
	add rsp, 8
	pop rsi
	pop rbx
	ret

; rcx = terminator ptr
; rax => ptr after terminator
skip_terminator:
	mov dl, BYTE [rcx]
	inc rcx
	cmp dl, "l"
	je skip_terminator_single
	cmp dl, "k"
	je skip_terminator_seq
	cmp dl, "N"
	je skip_terminator_seq
	cmp dl, "t"
	jne error_exit
	inc rcx
	jmp skip_terminator
skip_terminator_single:
	inc rcx
	jmp skip_terminator_exit
skip_terminator_seq:
	inc rcx
	cmp BYTE [rcx - 1], 0
	jne skip_terminator_seq
skip_terminator_exit:
	mov rax, rcx
	ret
	


; rcx = input buffer
; rdx = ptr to terminator
; rdx => ptr after terminator
; rax => length of string
find_string:
	push rsi
	push rdi
	push rbx
	push r12
	push r13
	mov rsi, rcx
	mov rbx, rdx
	sub rsp, 32
	mov cl, BYTE [rbx]
	inc rbx
	cmp cl, "l"
	je find_string_simple
	cmp cl, "k"
	je find_string_seq_all
	cmp cl, "N"
	je find_string_seq_any
	cmp cl, "t"
	je find_string_many
	jmp error_exit
find_string_simple:
	mov rcx, rsi
	mov dl, BYTE [rbx]
	inc rbx
	call strfind
	sub rax, rsi
	mov r12, rax
	jmp find_string_exit
find_string_seq_all:
	mov rcx, rbx
	call strlen
	mov r13, rax
	xor r12, r12
find_string_seq_all_loop:
	mov rcx, rbx
	lea rdx, [rsi + r12]
	inc r12
	mov r8, r13
	call memcmp
	cmp eax, 0
	jne find_string_seq_all_loop
	lea rbx, [rbx + r13 + 1]
	dec r12
	jmp find_string_exit
find_string_seq_any:
	mov rcx, rbx
	call strlen
	mov r13, rax
	xor r12, r12
find_string_seq_any_loop:
	mov rcx, rbx
	mov dl, BYTE [rsi + r12]
	inc r12
	call strfind
	cmp rax, 0
	je find_string_seq_any_loop
	lea rbx, [rbx + r13 + 1]
	jmp find_string_exit
find_string_many:
	mov r13b, BYTE [rbx]
	inc rbx
	and r13, 0xFF
	xor r12, r12
find_string_many_loop:
	cmp r13, 0
	je find_string_many_done
	lea rcx, [rsi + r12]
	mov rdx, rbx
	call find_string
	lea r12, [rax + 1]
	dec r13
	jmp find_string_many_loop
find_string_many_done:
	mov rbx, rdx
find_string_exit:
	mov rdx, rbx
	mov rax, r12
	add rsp, 32
	pop r13
	pop r12
	pop rbx
	pop rdi
	pop rsi
	ret



error_exit:
	mov rcx, 9
	call ExitProcess
	

; rcx = input lines
; rdx = output buffer
; r8 = number of lines
; r9 = format buffer
parse_lines:
	push rsi
	push rdi
	push rbx
	push r12
	push r13
	push r14
	sub rsp, 8
	mov rsi, rcx
	mov rdi, rdx
	mov rbx, r9
	mov r12, r8
	mov rcx, rbx
	call pattern_size
	mov r13, rax
	xor r14, r14
parse_lines_loop:
	cmp r14, r12
	je parse_lines_end
	mov rcx, rsi
	mov rax, r14
	mul r13
	mov rdx, rax
	add rdx, rdi
	mov r8, rbx
	call parse_line
	lea rsi, [rax + 1] ; Skip null-terminator
	inc r14
	jmp parse_lines_loop
parse_lines_end:
	add rsp, 8
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rdi
	pop rsi
	ret
	