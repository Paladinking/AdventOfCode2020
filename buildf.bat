@echo off
@setlocal

for /f tokens^=^* %%i  in ('where fasm') do set INCLUDE=%%~dpiINCLUDE;%INCLUDE%

pushd %~dp0

fasm -d COFF_IMAGE=TRUE src\day1f.asm bin\day1f.exe
fasm src\day1f.asm build\day1f.obj
gcc build\day1f.obj -nostdlib -lkernel32 --entry=setup_main -o bin\day1f-gcc.exe



popd %~dp0