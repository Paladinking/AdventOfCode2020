@echo off
@setlocal
pushd %~dp0
set CUR_DAY=10
nasm -fwin64 src\stdasm.asm -o build\stdasm.obj
nasm -fwin64 src\parse.asm -o build\parse.obj

if "%~1" EQU "all" (
	for /L %%i in (1, 1, %CUR_DAY%) do (
		call :build_day %%i
	)
	goto :exit
)

if "%~1" EQU "run" (
	call :build_day %CUR_DAY%
	cd bin
	day%CUR_DAY%.exe
	goto :exit
)

if "%~1" NEQ "" (
	call :build_day %1
	goto :exit
)
call :build_day %CUR_DAY%
goto :exit

:build_day
echo Building day %1...
nasm -fwin64 src\day%1.asm -o build\day%1.obj
cl build\day%1.obj build\stdasm.obj build\parse.obj /Fe:bin\day%1.exe Kernel32.lib /link /NODEFAULTLIB /entry:setup_main >nul 2>&1
gcc build\day%1.obj build\stdasm.obj build\parse.obj -o bin\day%1-gcc.exe -nostdlib -lkernel32 --entry=setup_main
exit /b

:exit
echo Done
popd
exit /b