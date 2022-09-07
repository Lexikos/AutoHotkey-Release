;@Ahk2Exe-SetName AutoHotkey Setup
;@Ahk2Exe-SetVersion %A_AhkVersion%
;@Ahk2Exe-SetDescription AutoHotkey installer
;@Ahk2Exe-ExeName AutoHotkey_%A_AhkVersion%_setup.exe
;@Ahk2Exe-Base %A_ScriptDir%\AutoHotkey32.exe

#NoTrayIcon
#SingleInstance Off

#include UX\install.ahk

if A_Args.Length {
    Install_Main
    ExitApp
}

#include UX\ui-setup.ahk

UnpackFiles(installDir) {
    DirCreate dir := installDir "\.staging\" A_ScriptName
    SetWorkingDir dir
    OnExit cleanup
    #include ~FileInstall.ahk
    return dir
    cleanup(*) {
        SetWorkingDir A_ScriptDir
        DirDelete dir, true
        try DirDelete installDir "\.staging"
    }
}
