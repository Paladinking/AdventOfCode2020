match =TRUE, COFF_IMAGE {
	format PE64 console
	entry setup_main
}
match =COFF_IMAGE, COFF_IMAGE {
	format MS64 COFF
	public main
	public input
}
include 'win64a.inc'

define OWORD DQWORD
define resq rq
define resd rd
define resw rw
define resb rb

prologue@proc equ static_rsp_prologue
epilogue@proc equ static_rsp_epilogue
close@proc equ static_rsp_close

macro import_func [name] {
	match =COFF_IMAGE, COFF_IMAGE \{
		extrn name
	\}
}

macro export_func [name] {
	match =COFF_IMAGE, COFF_IMAGE \{
		\public name
	\}
}

macro extern_call fn_name, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 { 
	match =COFF_IMAGE, COFF_IMAGE \{
		\common \fastcall fn_name, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
	\}
	match =TRUE, COFF_IMAGE \{
		\common \invoke fn_name, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
	\}
}
