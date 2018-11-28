@echo off

del azIDE.exe
setlocal
set include=c:\fasm\INCLUDE&& C:\fasm\FASM.EXE azIDE.asm
endlocal
if exist azIDE.exe (
	azIDE.exe
) else (
	pause
)