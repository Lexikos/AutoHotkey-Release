@echo off

cd /d %~dp0\..

set rh="C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe"
set rc="C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\RC.Exe"
set ahk=%cd%\include\AutoHotkeyU32.exe
set ahk2exe=%cd%\include\Compiler\Ahk2Exe.exe
set _7zr=%cd%\tools\lzma\bin\7zr
set tcc=%cd%\tools\tcc\tcc

echo *** Pre-processing script
%ahk% tools\packageit.ahk

echo *** Compiling scripts
rem  setup.exe is kept to avoid having to explain how to manually run the installer.
rem  It shouldn't increase file size much because setup.exe is just a combination of
rem  files which are already included in the archive.  Not used:  /icon source\setup.ico
%ahk2exe% /in include\Installer.ahk /out include\setup.exe /bin "include\Compiler\Unicode 32-bit.bin"
%ahk2exe% /in source\ActiveWindowInfo.ahk /out include\AU3_Spy.exe /bin "include\Compiler\Unicode 32-bit.bin" /icon source\spy.ico

echo *** Compiling SFX stub
pushd tools\lzma\C
%tcc% -DUSE_ASM -o 7zS2.exe 7zAlloc.c 7zArcIn.c 7zBuf.c 7zBuf2.c 7zCrc.c 7zCrcOpt.c 7zFile.c 7zDec.c 7zStream.c Bcj2.c Bra.c Bra86.c CpuArch.c Lzma2Dec.c LzmaDec.c Util\SfxSetup2\SfxSetup.c Util\SfxSetup2\rsrc.c
set sfxsrc=%cd%\7zS2.exe
popd

echo *** Updating SFX resources
%rc% /fo installer.res source\installer.rc
if ErrorLevel 1 goto :err
%rh% -addoverwrite %sfxsrc%, %cd%\installer.sfx, %cd%\installer.res, ,,
if ErrorLevel 1 goto :err

echo *** Building 7z archive
del installer.7z > nul 2>&1
%_7zr% a installer.7z .\include\* -m0=BCJ2 -m1=LZMA:d25:fb255 -m2=LZMA:d19 -m3=LZMA:d19 -mb0:1 -mb0s1:2 -mb0s2:3 -mx
if ErrorLevel 1 goto :err

echo.
echo *** Assembling Install.exe
copy /Y /b installer.sfx + installer.7z AutoHotkey_L_Install.exe > nul
if ErrorLevel 1 goto :err

:cleanup
echo *** Cleaning up
del installer.sfx
del installer.7z
del installer.res
del installer.manifest

exit
:err
echo.
echo ##
echo ## Aborting due to an error. Press Enter.
echo ##
pause >nul
goto :cleanup