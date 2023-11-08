; Include inside data section

define PARSE_INT_ERROR 101
define INVALID_SIZE 102

if defined COFF_IMAGE
section '.idata' import data readable

	library kernel,'KERNEL32.DLL'
	import kernel,\
		ExitProcess, 'ExitProcess',\
		WriteFile, 'WriteFile',\
		GetStdHandle, 'GetStdHandle',\
		GetLastError, 'GetLastError',\
		CreateFileA, 'CreateFileA',\
		ReadFile, 'ReadFile',\
		GetProcessHeap, 'GetProcessHeap',\
		GetFileSizeEx, 'GetFileSizeEx',\
		HeapAlloc, 'HeapAlloc',\
		HeapFree, 'HeapFree',\
		CloseHandle, 'CloseHandle'


else
	extrn ExitProcess
	extrn WriteFile
	extrn GetStdHandle
	extrn GetLastError
	extrn CreateFileA
	extrn ReadFile
	extrn GetProcessHeap
	extrn GetFileSizeEx
	extrn HeapAlloc
	extrn HeapFree
	extrn CloseHandle
end if


section '.bss' readable writeable
	error_byte: rb 1
	process_heap: rq 1
	stdout: rq 1

	file_size: rq 1
	file_buffer: rq 1