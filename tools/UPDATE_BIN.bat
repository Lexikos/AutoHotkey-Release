@echo off

del %bin%\Win32w\AutoHotkey.exe > nul 2>&1
del %bin%\Win32a\AutoHotkey.exe > nul 2>&1
del %bin%\x64w\AutoHotkey.exe > nul 2>&1

del %bin%\Win32w\AutoHotkeySC.bin > nul 2>&1
del %bin%\Win32a\AutoHotkeySC.bin > nul 2>&1
del %bin%\x64w\AutoHotkeySC.bin > nul 2>&1

"C:\Program Files (x86)\AutoHotkey\AutoHotkey.exe" F:\Projects\AutoHotkey\AutoHotkey_L_\zzz_rebuild.ahk

echo.
echo.

set bin=F:\Projects\AutoHotkey\AutoHotkey_L\bin

cd %~dp0..

copy %bin%\Win32w\AutoHotkey.exe include\AutoHotkeyU32.exe
copy %bin%\Win32a\AutoHotkey.exe include\AutoHotkeyA32.exe
copy %bin%\x64w\AutoHotkey.exe include\AutoHotkeyU64.exe

copy %bin%\Win32w\AutoHotkeySC.bin "include\Compiler\Unicode 32-bit.bin"
copy %bin%\Win32a\AutoHotkeySC.bin "include\Compiler\ANSI 32-bit.bin"
copy %bin%\x64w\AutoHotkeySC.bin "include\Compiler\Unicode 64-bit.bin"

echo.
echo.
pause