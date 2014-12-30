@echo off

cd /d %~dp0\..

set rh="C:\Program Files (x86)\Resource Hacker\ResHacker.exe"
set rc="C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\RC.Exe"
set ahk=include\AutoHotkeyU32.exe
set ahk2exe=include\Compiler\Ahk2Exe.exe

echo *** Pre-processing script
%ahk% tools\packageit.ahk

echo *** Compiling scripts
%ahk2exe% /in include\Installer.ahk /out include\setup.exe /bin "include\Compiler\Unicode 32-bit.bin" /icon source\setup.ico
%ahk2exe% /in source\ActiveWindowInfo.ahk /out include\AU3_Spy.exe /bin "include\Compiler\Unicode 32-bit.bin" /icon source\spy.ico

echo *** Updating SFX resources
%rc% /fo installer.res source\installer.rc
%rh% -addoverwrite %cd%\tools\7z\7zS2.sfx, %cd%\installer.sfx, installer.res, ,,
del installer.res

echo *** Updating 7z archive
del installer.7z > nul 2>&1
tools\7z\7zr a installer.7z .\include\* -m0=BCJ2 -m1=LZMA:d25:fb255 -m2=LZMA:d19 -m3=LZMA:d19 -mb0:1 -mb0s1:2 -mb0s2:3 -mx

echo.
echo *** Creating SFX archive
copy /Y /b installer.sfx + installer.7z AutoHotkey_L_Install.exe > nul
if ErrorLevel 1 pause

echo *** Cleaning up
del installer.sfx
del installer.7z
