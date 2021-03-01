@echo off
setlocal enabledelayedexpansion

:: Untested: ProgramFiles(x86) is not set for 32-bit programs pre Windows 10
if not defined ProgramFiles(x86) set ProgramFiles(x86)=%ProgramFiles%

set branch=%1
shift

:: Prefer the older build tools for v1
if [%branch%]==[master] goto :try_comntools

:try_vswhere
:: Is VS 2019 or (untested)2017 installed?
set vswhere="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist %vswhere% exit /b
for /f "usebackq delims=" %%i in (`%vswhere% -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath`) do (
  if exist "%%i\Common7\Tools\vsdevcmd.bat" (
    call "%%i\Common7\Tools\vsdevcmd.bat"
    goto :building
  )
)

:try_comntools
if defined VS100COMNTOOLS set VSCOMNTOOLS=%VS100COMNTOOLS%
if defined VS110COMNTOOLS set VSCOMNTOOLS=%VS110COMNTOOLS%
if defined VS120COMNTOOLS set VSCOMNTOOLS=%VS120COMNTOOLS%
if defined VS140COMNTOOLS set VSCOMNTOOLS=%VS140COMNTOOLS%
if not defined VSCOMNTOOLS (
    if not defined vswhere goto :try_vswhere
    echo ---- BUILD TOOLS NOT FOUND ----
    exit /b 1
)

call "%VSCOMNTOOLS%..\..\VC\vcvarsall.bat"

:building
set config=%1
set platform=%2
if [%platform%]==[] exit /b 0
if "%AUTOHOTKEY_BUILD_TARGET%"=="" set AUTOHOTKEY_BUILD_TARGET=Rebuild
echo ++++ Building %config% :: %platform% ++++
MSBuild AutoHotkeyx.sln /t:%AUTOHOTKEY_BUILD_TARGET% /p:Configuration=%config% /p:Platform=%platform%
if ErrorLevel 1 (
    echo ---- BUILD FAILED: !config! :: !platform! ----
    exit /b %ErrorLevel%
)
echo.
echo.
shift
shift
goto :building
