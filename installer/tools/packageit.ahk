SetWorkingDir %A_ScriptDir%\..

if WinActive(A_ScriptFullPath) || %True% = "/persist" {
    SetTitleMatchMode 2
    Hotkey IfWinActive, Installer_src
    Hotkey ~^s, packageit
    Menu Tray, Add
    Menu Tray, Add, Update Installer.ahk, packageit
    Menu Tray, Add, Rebuild Installer.exe, rebuild
    Menu Tray, Default, Rebuild Installer.exe
    Menu Tray, Click, 1
    return
}

packageit:
Sleep 200
FileRead htm, source\Installer_src.htm
FileRead css, source\Installer_src.css
FileRead js,  source\Installer_src.js
htm := RegExReplace(htm, "<meta.*?>") ; Save space. Has no effect with document.write().
htm := RegExReplace(htm, "<link rel=""StyleSheet"".*?>", "<style type=""text/css"">`n" css "`n</style>")
htm := RegExReplace(htm, "<script .*?\K src=.*?>", ">`n" js)
FileRead ahk, source\Installer_src.ahk
ahk := RegExReplace(ahk, "`ams)((?<=`r`n)`r`n)?^\s*;#debug.*?^\s*;#end\R")
ahk := RegExReplace(ahk, "`am)^FileRead html,.*", "
(Join`r`n
html=
`(%``
" htm "
`)
)")
FileRead inc, source\Lib\ShellRun.ahk
inc := RegExReplace(inc, "`am)^(?:/\*[\s\S]*?^\*/| *(?:;.*)?)\R")
ahk := RegExReplace(ahk, "`am)^#include <ShellRun>$", inc)
if 1 !=
    out = %1%
else
    out = include\Installer.ahk
FileOpen(out, "w").Write(ahk)

FileRead man, source\installer_src.manifest
man := RegExReplace(man, ">\s*(?:<!--.*?-->\s*)?<", "><")
FileOpen("temp\installer.manifest", "w").Write(man)

FileGetVersion ver, include\AutoHotkeyU32.exe
FileRead rc, source\installer.rc
rc := StrReplace(rc, "AHK_VERSION_N", StrReplace(ver, ".", ","))
rc := StrReplace(rc, "AHK_VERSION", """" RegExReplace(ver, "\b\d\b", "0$0",,, 4) """")
FileOpen("temp\installer.rc", "w").Write(rc)

return

rebuild:
Run %A_ScriptDir%\UPDATE.bat
return