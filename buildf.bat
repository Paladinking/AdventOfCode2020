@echo off
@setlocal
pushd %~dp0
set CUR_DAY=10
for /f tokens^=^* %%i  in ('where fasm') do set INCLUDE=%%~dpiINCLUDE;%INCLUDE%

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
fasm -d COFF_IMAGE=TRUE src\day%1f.asm bin\day%1f.exe
fasm src\day%1f.asm build\day%1f.obj
gcc build\day%1f.obj -nostdlib -lkernel32 --entry=setup_main -o bin\day%1f-gcc.exe
exit /b
:exit
echo Done
popd
exit /b
