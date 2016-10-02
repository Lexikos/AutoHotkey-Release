@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d %~dp0\..
:: Create clean temp directory.
rmdir /q /s temp 2>nul
mkdir temp
if ErrorLevel 1 goto :err
set td=%cd%\temp

set ahk="%cd%\include\AutoHotkeyU32.exe"
set ahk2exe="%cd%\include\Compiler\Ahk2Exe.exe"
call :find_tool rh ResourceHacker.exe "Resource Hacker"
set _7zr="%cd%\tools\7z\7zr.exe"
set sfx="%cd%\tools\7z\7zS2.sfx"

for %%f in (%rh% %ahk% %ahk2exe% %_7zr% %sfx%) do if not exist %%f (
	echo Missing required tool: %%f
	goto :err
)

echo *** Pre-processing script
%ahk% tools\packageit.ahk

echo *** Compiling scripts
:: The standard 7zS2.sfx runs "setup.exe" automatically.  Even if we're using a custom
:: sfx which runs Installer.ahk, keeping setup.exe makes it easier for users to manually
:: extract and run setup when the sfx has a problem.  It shouldn't increase file size
:: much because setup.exe is basically just a combination of other included files.
%ahk2exe% /in include\Installer.ahk /out include\setup.exe /bin "include\Compiler\Unicode 32-bit.bin"
%ahk2exe% /in source\ActiveWindowInfo.ahk /out include\AU3_Spy.exe /bin "include\Compiler\Unicode 32-bit.bin" /icon source\spy.ico

echo *** Updating SFX resources
copy source\setup.ico temp >nul
:: Working directory must be set for the rc script.
pushd %td%
%rh% -compile %td%\installer.rc, %td%\installer.res
popd
%rh% -addoverwrite %sfx%, %td%\installer.sfx, %td%\installer.res, ,,
if not exist "%td%\installer.res" goto :err

echo *** Building 7z archive
%_7zr% a "%td%\installer.7z" .\include\* -m0=BCJ2 -m1=LZMA:d25:fb255 -m2=LZMA:d19 -m3=LZMA:d19 -mb0:1 -mb0s1:2 -mb0s2:3 -mx
if ErrorLevel 1 goto :err

echo.
echo *** Assembling Install.exe
copy /Y /b "%td%\installer.sfx" + "%td%\installer.7z" AutoHotkey_L_Install.exe >nul
if ErrorLevel 1 goto :err

:cleanup
echo *** Cleaning up
rmdir /s /q temp

exit
:err
echo.
echo ##
echo ## Aborting due to an error. Press Enter.
echo ##
pause >nul
goto :cleanup

:find_tool
set %1="%cd%\tools\%2"
if not exist "!%1!" for %%d in ("%ProgramFiles%" "%ProgramFiles(x86)%") do (
	if exist "%%~d\%~3\%2" set %1="%%~d\%~3\%2"
)
exit /b
