@echo off
pushd %~dp0
nasm -fwin64 src\stdasm.asm -o build\stdasm.obj
nasm -fwin64 src\day1.asm -o build\day1.obj
nasm -fwin64 src\day2.asm -o build\day2.obj
nasm -fwin64 src\day3.asm -o build\day3.obj
nasm -fwin64 src\day4.asm -o build\day4.obj
cl build\day1.obj build\stdasm.obj /Fe:bin\day1.exe Kernel32.lib /link /NODEFAULTLIB /entry:main >nul 2>&1
cl build\day2.obj build\stdasm.obj /Fe:bin\day2.exe Kernel32.lib /link /NODEFAULTLIB /entry:main >nul 2>&1
cl build\day3.obj build\stdasm.obj /Fe:bin\day3.exe Kernel32.lib /link /NODEFAULTLIB /entry:main >nul 2>&1
cl build\day4.obj build\stdasm.obj /Fe:bin\day4.exe Kernel32.lib /link /NODEFAULTLIB /entry:main >nul 2>&1
gcc build\day1.obj build\stdasm.obj -o bin\day1-gcc.exe -nostdlib -lkernel32 --entry=main
gcc build\day2.obj build\stdasm.obj -o bin\day2-gcc.exe -nostdlib -lkernel32 --entry=main
gcc build\day3.obj build\stdasm.obj -o bin\day3-gcc.exe -nostdlib -lkernel32 --entry=main
gcc build\day4.obj build\stdasm.obj -o bin\day4-gcc.exe -nostdlib -lkernel32 --entry=main
popd