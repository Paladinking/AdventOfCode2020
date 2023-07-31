@echo off
pushd %~dp0
nasm -fwin64 src\day1.asm -o build\day1.obj
nasm -fwin64 src\stdasm.asm -o build\stdasm.obj
cl build\day1.obj build\stdasm.obj /Fe:bin\day1.exe Kernel32.lib /link /NODEFAULTLIB /entry:main
gcc build\day1.obj build\stdasm.obj -o bin\day1-gcc.exe -nostdlib -lkernel32 --entry=main
popd