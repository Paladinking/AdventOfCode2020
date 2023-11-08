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

export_func parse_line, pattern_size, skip_terminator, find_string, error_exit, parse_lines


; rcx = input buffer
; rdx = output buffer
; r8 = format buffer
; rax = position in input buffer
proc parse_line uses rsi rdi rbx r12 r13 r14
	sub rsp, 56
	mov rbx, r8
	mov rdi, rdx
	mov rsi, rcx
 .loop:
	mov r9b, BYTE [rbx]
	inc rbx
	cmp r9b, 0x0
	je .exit
	cmp r9b, "p"
	je .pass
	cmp r9b, "P"
	je .passmany
	cmp r9b, "c"
	je .char
	cmp r9b, "C"
	je .chars
	cmp r9b, "d"
	je .dword
	cmp r9b, "q"
	je .qword
	cmp r9b, "D"
	je .sdword
	cmp r9b, "Q"
	je .sqword
	cmp r9b, "s"
	je .string
	cmp r9b, "i"
	je .ignore
	cmp r9b, "V"
	je .var
	jmp error_exit
 .pass:
	inc rsi
	jmp .loop
 .passmany:
	mov cl, BYTE [rbx]
	inc rbx
	and rcx, 0xFF
	add rsi, rcx
	jmp .loop
 .char:
	mov cl, BYTE [rsi]
	inc rsi
	mov BYTE [rdi], cl
	inc rdi
	jmp .loop
 .chars:
	mov r12b, BYTE [rbx]
	inc rbx
	and r12, 0xFF
	mov rcx, rsi
	mov rdx, rdi
	mov r8, r12
	call memcopy
	add rsi, r12
	add rdi, r12
	jmp .loop
 .dword:
	mov rcx, rsi
	call parse_u64_cstr
	mov DWORD [rdi], eax
	add rdi, 4
	mov rsi, rcx
	jmp .loop
 .qword:
	mov rcx, rsi
	call parse_u64_cstr
	mov QWORD [rdi], rax
	add rdi, 8
	mov rsi, rcx
	jmp .loop
 .sdword:
	mov rcx, rsi
	call parse_i64_cstr
	mov DWORD [rdi], eax
	add rdi, 4
	mov rsi, rcx
	jmp .loop
 .sqword:
	mov rcx, rsi
	call parse_i64_cstr
	mov QWORD [rdi], rax
	add rdi, 8
	mov rsi, rcx
	jmp .loop
 .string:
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
	jmp .loop
 .ignore:
	mov rcx, rsi
	mov rdx, rbx
	call find_string
	mov rbx, rdx
	add rsi, rax
	jmp .loop
 .var:
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
 .var_loop:
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
	je .var_done
	mov dl, BYTE [rsp + 24]
	and rdx, 0xFF
	add QWORD [rsp + 16], rdx	; skip <n> characters
	dec QWORD [rsp + 32]
	cmp QWORD [rsp + 32], 0
	jg .var_loop
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
	jmp .var_loop
 .var_done:
	mov QWORD [rdi], r12
	mov rax, QWORD [rsp + 8]
	mov QWORD [rdi + 8], rax
	add rdi, 16
	mov rsi, QWORD [rsp + 16]
	mov rcx, rbx
	call pattern_size
	lea rbx, [rcx + 2]
	jmp .loop
 .exit:
	mov rax, rsi
	add rsp, 56
	ret
endp


; rcx = ptr to null-terminated pattern
; rcx => pointer after pattern (to null-terminator)
; rax => size needed to store result of pattern
proc pattern_size uses rbx rsi
	sub rsp, 8
	mov rbx, rcx
	xor rsi, rsi
 .loop:
	mov cl, BYTE [rbx]
	inc rbx
	cmp cl, 0x0
	je .exit
	cmp cl, "p"
	je .loop
	cmp cl, "P"
	je .passmany
	cmp cl, "c"
	je .char
	cmp cl, "C"
	je .chars
	cmp cl, "d"
	je .dword
	cmp cl, "q"
	je .qword
	cmp cl, "D"
	je .dword
	cmp cl, "Q"
	je .qword
	cmp cl, "s"
	je .string
	cmp cl, "i"
	je .ignore
	cmp cl, "V"
	je .var
	jmp error_exit
 .passmany:
	inc rbx
	jmp .loop
 .char:
	inc rsi
	jmp .loop
 .chars:
	mov cl, BYTE [rbx]
	inc rbx
	and cl, 0xFF
	add rsi, rcx
	jmp .loop
 .dword:
	add rsi, 4
	jmp .loop
 .qword:
	add rsi, 8
	jmp .loop
 .string:
	add rsi, 8
 .ignore:
	mov rcx, rbx
	call skip_terminator
	mov rbx, rax
	jmp .loop
 .var:
	add rsi, 16
	mov rcx, rbx
	call skip_terminator
	mov rbx, rax
	mov rcx, rbx
	call pattern_size
	lea rbx, [rcx + 2]
	jmp .loop
 .exit:
	lea rcx, [rbx - 1]
	mov rax, rsi
	add rsp, 8
	ret
endp

; rcx = terminator ptr
; rax => ptr after terminator
skip_terminator:
	mov dl, BYTE [rcx]
	inc rcx
	cmp dl, "l"
	je .single
	cmp dl, "k"
	je .seq
	cmp dl, "N"
	je .seq
	cmp dl, "t"
	jne error_exit
	inc rcx
	jmp skip_terminator
 .single:
	inc rcx
	jmp .exit
 .seq:
	inc rcx
	cmp BYTE [rcx - 1], 0
	jne .seq
 .exit:
	mov rax, rcx
	ret
	


; rcx = input buffer
; rdx = ptr to terminator
; rdx => ptr after terminator
; rax => length of string
proc find_string uses rsi rdi rbx r12 r13
	mov rsi, rcx
	mov rbx, rdx
	sub rsp, 32
	mov cl, BYTE [rbx]
	inc rbx
	cmp cl, "l"
	je .simple
	cmp cl, "k"
	je .seq_all
	cmp cl, "N"
	je .seq_any
	cmp cl, "t"
	je .many
	jmp error_exit
 .simple:
	mov rcx, rsi
	mov dl, BYTE [rbx]
	inc rbx
	call strfind
	sub rax, rsi
	mov r12, rax
	jmp .exit
 .seq_all:
	mov rcx, rbx
	call strlen
	mov r13, rax
	xor r12, r12
 .seq_all_loop:
	mov rcx, rbx
	lea rdx, [rsi + r12]
	inc r12
	mov r8, r13
	call memcmp
	cmp eax, 0
	jne .seq_all_loop
	lea rbx, [rbx + r13 + 1]
	dec r12
	jmp .exit
 .seq_any:
	mov rcx, rbx
	call strlen
	mov r13, rax
	xor r12, r12
 .seq_any_loop:
	mov rcx, rbx
	mov dl, BYTE [rsi + r12]
	inc r12
	call strfind
	cmp rax, 0
	je .seq_any_loop
	lea rbx, [rbx + r13 + 1]
	jmp .exit
 .many:
	mov r13b, BYTE [rbx]
	inc rbx
	and r13, 0xFF
	xor r12, r12
 .many_loop:
	cmp r13, 0
	je .many_done
	lea rcx, [rsi + r12]
	mov rdx, rbx
	call find_string
	lea r12, [rax + 1]
	dec r13
	jmp .many_loop
 .many_done:
	mov rbx, rdx
 .exit:
	mov rdx, rbx
	mov rax, r12
	add rsp, 32
	ret
endp


error_exit:
	mov rcx, 9
	call ExitProcess
	

; rcx = input lines
; rdx = output buffer
; r8 = number of lines
; r9 = format buffer
proc parse_lines uses rsi rdi rbx r12 r13 r14
	sub rsp, 8
	mov rsi, rcx
	mov rdi, rdx
	mov rbx, r9
	mov r12, r8
	mov rcx, rbx
	call pattern_size
	mov r13, rax
	xor r14, r14
 .loop:
	cmp r14, r12
	je .end
	mov rcx, rsi
	mov rax, r14
	mul r13
	mov rdx, rax
	add rdx, rdi
	mov r8, rbx
	call parse_line
	lea rsi, [rax + 1] ; Skip null-terminator
	inc r14
	jmp .loop
 .end:
	add rsp, 8
	ret
endp
	