@echo off
@setlocal
pushd %~dp0
set CUR_DAY=12
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
fasm -d COFF_IMAGE=TRUE src\day%1.asm bin\day%1.exe >nul
if %errorlevel% NEQ 0 (
	exit /b
)
echo  bin\day%1.exe
fasm src\day%1.asm build\day%1.obj >nul
if %errorlevel% NEQ 0 (
	exit /b
)
echo  build\day%1.obj
gcc build\day%1.obj -nostdlib -lkernel32 --entry=setup_main -o bin\day%1-gcc.exe
if %errorlevel% NEQ 0 (
	exit /b
)
echo  bin\day%1-gcc.exe
exit /b
:exit
echo Done
popd
exit /b
