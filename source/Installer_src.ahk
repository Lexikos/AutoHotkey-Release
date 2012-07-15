#NoEnv
#NoTrayIcon
; #Warn
#SingleInstance Off

if !A_IsAdmin && !%False%
{
    if A_OSVersion not in WIN_2003,WIN_XP,WIN_2000
    {
        Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%",, UseErrorLevel
        if !ErrorLevel
            ExitApp
    }
    MsgBox 0x31, AutoHotkey_L Setup,
    (LTrim Join`s
    Setup is running as a limited user.  If you continue, some problems
    are likely to occur.  It is strongly recommended that you run Setup
    as an administrator.`n
    `n
    To continue anyway, click OK.  Otherwise click Cancel.
    )
    IfMsgBox Cancel
        ExitApp
}

SourceDir := A_ScriptDir
SilentMode := false
SilentErrors := 0

if 0 > 0
if 1 = /kill ; For internal use.
{
    DetectHiddenWindows On
    WinKill % "ahk_id " %0%
    ExitApp
}
else if 1 = /fin ; For internal use.
{
    DetectHiddenWindows On
    WinKill % "ahk_id " %0%
    WinWaitClose % "ahk_id " %0%,, 1
    
    exefile = %2%
    InstallFile(exefile, "AutoHotkey.exe")
    if 3 = 0 ; SilentMode
        MsgBox 64, AutoHotkey_L Setup, The settings have been updated.
    ExitApp
}
else if 1 = /runahk ; For internal use.
{
    RunAutoHotkey_()
    ExitApp
}

SetWorkingDir %A_ScriptDir%

ProductName := "AutoHotkey_L"
ProductVersion := A_AhkVersion
ProductPublisher := "Lexikos"
ProductWebsite := "http://l.autohotkey.net/"

EnvGet ProgramW6432, ProgramW6432
DefaultPath := (ProgramW6432 ? ProgramW6432 : A_ProgramFiles) "\AutoHotkey"
DefaultType := A_Is64bitOS ? "x64" : "Unicode"
DefaultStartMenu := "AutoHotkey"
DefaultCompiler := true
DefaultDragDrop := true
DefaultToUTF8 := false
DefaultIsHostApp := false
AutoHotkeyKey := "SOFTWARE\AutoHotkey"
UninstallKey := "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AutoHotkey"
FileTypeKey := "AutoHotkeyScript"

DetermineVersion()

Loop %0%
    if %A_Index% = /S
        SilentMode := true
    else if %A_Index% = /U32
        DefaultType = Unicode
    else if %A_Index% in /U64,/x64
        DefaultType = x64
    else if %A_Index% in /A32,/ANSI
        DefaultType = ANSI
    else if InStr(%A_Index%, "/D=") = 1 {
        if !RegExMatch(DllCall("GetCommandLine", "str"), "(?<!"")/D=\K[^""]*?(?=$|[ `t]+/)", DefaultPath)
            DefaultPath := SubStr(%A_Index%, 4)
    }
    else if (%A_Index% = "/?") {
        ViewHelp("/docs/Scripts.htm#install")
        ExitApp
    }
    else if (%A_Index% = "/Uninstall") {
        SilentMode := true
        Uninstall()
        ExitApp
    }

if SilentMode {
    QuickInstall()
    ExitApp % SilentErrors
}

if WinExist("AutoHotkey_L Setup ahk_class AutoHotkeyGUI") {
    MsgBox 0x30, AutoHotkey_L Setup, AutoHotkey_L Setup is already running!
    WinActivate
    ExitApp
}

;#debug
Menu TestMenu, Add, RELOAD, Reload
Menu TestMenu, Add, TEST, Test
Menu TestMenu, Add, New Install, Test?fresh
Menu TestMenu, Add, Upgrade, Test?upgrade
Menu TestMenu, Add, Update, Test?update
Menu TestMenu, Add, Repair, Test?repair
Gui Menu, TestMenu
;#end

Gui Margin, 0, 0
Gui Add, ActiveX, vwb w600 h400 hwndhwb, Shell.Explorer
ComObjConnect(wb, "wb_")
OnMessage(0x100, "gui_KeyDown", 2)
InitUI()
Gui Show,, AutoHotkey_L Setup
return

GuiEscape:
MsgBox 0x34, AutoHotkey_L Setup, Are you sure you want to exit setup?
IfMsgBox No
    return
GuiClose:
ExitApp

DetermineVersion() {
    global
    local url, v
    ; This first section has two purposes:
    ;  1) Determine the location of any current installation.
    ;  2) Determine which view of the registry it was installed into
    ;     (only applicable if the OS is 64-bit).
    CurrentRegView := ""
    Loop % (A_Is64bitOS ? 2 : 1) {
        SetRegView % 32*A_Index
        RegRead CurrentPath, HKLM, %AutoHotkeyKey%, InstallDir
        if !ErrorLevel {
            CurrentRegView := A_RegView
            break
        }
    }
    if ErrorLevel {
        CurrentName := ""
        CurrentVersion := ""
        CurrentType := ""
        CurrentPath := ""
        CurrentStartMenu := ""
        return
    }
    RegRead CurrentVersion, HKLM, %AutoHotkeyKey%, Version
    RegRead CurrentStartMenu, HKLM, %AutoHotkeyKey%, StartMenuFolder
    RegRead url, HKLM, %UninstallKey%, URLInfoAbout
    ; Identify by URL since uninstaller display name is the same:
    if (url = "http://www.autohotkey.net/~Lexikos/AutoHotkey_L/"
        || url = "http://l.autohotkey.net/")
        CurrentName := "AutoHotkey_L"
    else
        CurrentName := "AutoHotkey"
    ; Identify which build is installed/set as default:
    FileAppend ExitApp `% (A_IsUnicode=1) << 8 | (A_PtrSize=8) << 9, %A_Temp%\VersionTest.ahk
    RunWait %CurrentPath%\AutoHotkey.exe "%A_Temp%\VersionTest.ahk",, UseErrorLevel
    if (ErrorLevel & 0x200)
        CurrentType := "x64"
    else if (ErrorLevel & 0x100)
        CurrentType := "Unicode"
    else
        CurrentType := "ANSI"
    FileDelete %A_Temp%\VersionTest.ahk
    ; Set some default parameter based on current installation:
    DefaultType := CurrentType
    DefaultPath := CurrentPath
    DefaultStartMenu := CurrentStartMenu
    DefaultCompiler := FileExist(CurrentPath "\Compiler\Ahk2Exe.exe") != ""
    RegRead v, HKCR, %FileTypeKey%\ShellEx\DropHandler
    DefaultDragDrop := ErrorLevel = 0
    RegRead v, HKCR, Applications\AutoHotkey.exe, IsHostApp
    DefaultIsHostApp := !ErrorLevel
    RegRead v, HKCR, %FileTypeKey%\Shell\Open\Command
    DefaultToUTF8 := InStr(v, " /CP65001 ") != 0
}

InitUI() {
    local w
    ;#debug
    if false {
    ;#end
    gosub DefineUI
    wb.Silent := true
    wb.Navigate("about:blank")
    while wb.ReadyState != 4
        Sleep 10
    wb.Document.open()
    wb.Document.write(html)
    wb.Document.Close()
    ;#debug
    }
    wb.Navigate(A_ScriptDir "\Installer_src.htm")
    while wb.ReadyState != 4
        Sleep 10
    ;#end
    w := wb.Document.parentWindow
    w.initOptions(CurrentName, CurrentVersion, CurrentType
                , ProductVersion, DefaultPath, DefaultStartMenu
                , DefaultType, A_Is64bitOS)
    if (A_ScriptDir = DefaultPath) {
        w.installdir.disabled := true
        w.installdir_browse.disabled := true
        w.installcompiler.disabled := !DefaultCompiler
        w.installcompilernote.style.display := "block"
        w.ci_nav_install.innerText := "apply"
        w.install_button.innerText := "Apply"
        w.opt1.disabled := true
        w.opt1.firstChild.innerText := "Checking for updates..."
        SetTimer CheckForUpdates, -500
    }
    w.installcompiler.checked := DefaultCompiler
    w.enabledragdrop.checked := DefaultDragDrop
    w.separatebuttons.checked := DefaultIsHostApp
    ; w.defaulttoutf8.checked := DefaultToUTF8
    if !A_Is64bitOS
        w.it_x64.style.display := "None"
    if A_OSVersion in WIN_2000,WIN_2003,WIN_XP ; i.e. not WIN_7, WIN_8 or a future OS.
        w.separatebuttons.parentNode.style.display := "none"
    w.switchPage("start")
    w.document.body.focus()
}

CheckForUpdates:
CheckForUpdates()
return
CheckForUpdates() {
    local w := getWindow(), latestVersion := ""
    URLDownloadToFile http://l.autohotkey.net/version.txt, %A_Temp%\ahk_version.txt
    if !ErrorLevel {
        FileRead latestVersion, %A_Temp%\ahk_version.txt
        FileDelete %A_Temp%\ahk_version.txt
    }
    if RegExMatch(latestVersion, "^(\d+\.){3}\d+") {
        if (latestVersion = ProductVersion)
            w.opt1.firstChild.innerText := "Reinstall (download required)"
        else
            w.opt1.firstChild.innerText := "Download v" latestVersion
        w.opt1.href := "http://l.autohotkey.net/AutoHotkey_L_Install.exe"
        w.opt1.disabled := false
    } else
        w.opt1.innerText := "An error occurred while checking for updates."
}

/*  Fix keyboard shortcuts in WebBrowser control.
 *  References:
 *    http://www.autohotkey.com/community/viewtopic.php?p=186254#p186254
 *    http://msdn.microsoft.com/en-us/library/ms693360
 */

gui_KeyDown(wParam, lParam, nMsg, hWnd) {
    global wb
    pipa := ComObjQuery(wb, "{00000117-0000-0000-C000-000000000046}")
    VarSetCapacity(kMsg, 48), NumPut(A_GuiY, NumPut(A_GuiX
    , NumPut(A_EventInfo, NumPut(lParam, NumPut(wParam
    , NumPut(nMsg, NumPut(hWnd, kMsg)))), "uint"), "int"), "int")
    Loop 2
    r := DllCall(NumGet(NumGet(1*pipa)+5*A_PtrSize), "ptr", pipa, "ptr", &kMsg)
    ; Loop to work around an odd tabbing issue (it's as if there
    ; is a non-existent element at the end of the tab order).
    until wParam != 9 || wb.Document.activeElement != ""
    ObjRelease(pipa)
    if r = 0 ; S_OK: the message was translated to an accelerator.
        return 0
}


/*  ahk://Func/Param  -->  Func("Param")
 */

wb_BeforeNavigate2(wb, url, flags, frame, postdata, headers, cancel) {
    if !RegExMatch(url, "^ahk://(.*?)/(.*)", m)
        return
    static func, prms
    func := m1
    prms := []
    StringReplace m2, m2, `%20, %A_Space%, All
    Loop Parse, m2, `,
        prms.Insert(A_LoopField)
    ; Cancel: don't load the error page (or execute ahk://whatever
    ; if it happens to somehow be a registered protocol).
    NumPut(-1, ComObjValue(cancel), "short")
    ; Call after a delay to allow navigation (this might only be
    ; necessary if called from NavigateError; i.e. on Windows 8).
    SetTimer wb_bn2_call, -15
    return
wb_bn2_call:
    %func%(prms*)
    func := prms := ""
    return
}

wb_NavigateError(wb, url, frame, status, cancel) {
    ; This might only be called on Windows 8, which skips the
    ; BeforeNavigate2 call (because the protocol is invalid?).
    wb_BeforeNavigate2(wb, url, 0, frame, "", "", cancel)
}


/*  Utility Functions
 */

getWindow() {
    global wb
    return wb.document.parentWindow
}

ErrorExit(errMsg) {
    global
    if SilentMode
        ExitApp 1
    MsgBox 16, AutoHotkey_L Setup, %errMsg%
    Exit
}

CloseScriptsEtc(installdir, actionToContinue) {
    titles := ""
    DetectHiddenWindows On
    close := []
    WinGet w, List, ahk_class AutoHotkey
    Loop % w {
        ; Exclude the install script.
        if (w%A_Index% = A_ScriptHwnd)
            continue
        ; Determine if the script actually needs to be terminated.
        WinGet exe, ProcessPath, % "ahk_id " w%A_Index%
        if (exe != "") {
            ; Exclude external executables.
            if InStr(exe, installdir "\") != 1
                continue
            ; The main purpose of this next check is to avoid closing
            ; SciTE4AutoHotkey's toolbar, but also may be helpful for
            ; other situations.
            exe := SubStr(exe, StrLen(installdir) + 2)
            if !RegExMatch(exe, "i)^(AutoHotkey(A32|U32|U64)?\.exe|Compiler\\Ahk2Exe.exe)$")
                continue
        }        
        ; Append script path to the list.
        WinGetTitle title, % "ahk_id " w%A_Index%
        title := RegExReplace(title, " - AutoHotkey v.*")
        titles .= "  -  " title "`n"
        close.Insert(w%A_Index%)
    }
    if (titles != "") {
        global SilentMode
        if !SilentMode {
            MsgBox 49, AutoHotkey_L Setup,
            (LTrim
            Setup needs to close the following script(s):
            `n%titles%
            Click OK to close these scripts and continue the %actionToContinue%.
            )
            IfMsgBox Cancel
                Exit
        }
        ; Close script windows (typically causing them to exit).
        Loop % close.MaxIndex()
            WinClose % "ahk_id " close[A_Index]
    }
    ; Close all help file and Window Spy windows automatically:
    GroupAdd autoclosegroup, AutoHotkey_L Help ahk_class HH Parent
    GroupAdd autoclosegroup, Active Window Info ahk_exe %installdir%\AU3_Spy.exe
    ; Also close the old Ahk2Exe (but the new one is a script, so it
    ; was already handled by the section above):
    GroupAdd autoclosegroup, Ahk2Exe v ahk_exe %installdir%\Compiler\Ahk2Exe.exe
    WinClose ahk_group autoclosegroup
}

GetErrorMessage(error_code="") {
    VarSetCapacity(buf, 1024) ; Probably won't exceed 1024 chars.
    if DllCall("FormatMessage", "uint", 0x1200, "ptr", 0, "int", error_code!=""
                ? error_code : A_LastError, "uint", 1024, "str", buf, "uint", 1024, "ptr", 0)
        return buf
}

switchPage(page) {
    global
    if !SilentMode
        getWindow().switchPage(page)
}

UpdateStatus(status) {
    ; if !SilentMode
        ; getWindow().install_status.innerText := status
}

#include <ShellRun>

Run_(target, args="") {
    try
        ShellRun(target, args)
    catch e
        Run % args="" ? target : target " " args
}


/*  Utility Functions invoked by the UI
 */

Customize() {
    getWindow().switchPage("custom-install")
}

SelectFolder(id, prompt="", root="::{20d04fe0-3aea-1069-a2d8-08002b30309d}") {
    global wb
    if !(field := wb.document.getElementById(id))
        return
    Gui +OwnDialogs
    FileSelectFolder path
        , % root " *" field.value
        ,, % prompt
    if !ErrorLevel
        field.value := path
}

ReadLicense() {
    Run_(A_ScriptDir "\license.txt")
}

ViewHelp(topic) {
    local path
    if FileExist("AutoHotkey.chm")
        path := A_WorkingDir "\AutoHotkey.chm"
    else
        path := CurrentPath "\AutoHotkey.chm"
    if FileExist(path)
        Run_("hh.exe", "mk:@MSITStore:" path "::" topic)
    else
        Run_("http://l.autohotkey.net" topic)
}

RunAutoHotkey() {
    ; Setup may be running as a user other than the one that's logged
    ; in (i.e. an admin user), so in addition to running AutoHotkey.exe
    ; in user mode, have it call the function below to ensure the script
    ; file is correctly located.
    Run_("AutoHotkey.exe", """" A_WorkingDir "\Installer.ahk"" /runahk")
}
RunAutoHotkey_() {
    ; This could detect %ExeDir%\AutoHotkey.ahk (which takes precedence
    ; over %A_MyDocuments%\AutoHotkey.ahk), but that file is unlikely to
    ; exist in this situation.
    script_path := A_MyDocuments "\AutoHotkey.ahk"
    ; Start the script.
    Run AutoHotkey.exe,,, pid
    ; Check for common failures.
    SetTitleMatchMode 2
    DetectHiddenWindows On
    message := ""
    message_flags := 0x34
    Loop {
        Sleep 50
        Process Exist, %pid%
        if !ErrorLevel {
            message =
            (LTrim Join`s
            AutoHotkey has exited.  You may need to edit your startup
            script.  For instance, if it exited because it had nothing
            to do, you can add a hotkey.
            )
            message_flags := 0x44 ; Less severe, since it might be intentional.
            break
        }
        if WinExist("ahk_class #32770 ahk_pid " pid) {
            WinGetText message
            if !InStr(message, "Error")
                return
            WinWaitClose
            Process Exist, %pid%
            message := "Your script encountered an error" (ErrorLevel ? "." : " and exited.")
                   . "  You will need to edit it to resolve this error."
            break
        }
        if WinExist("ahk_class AutoHotkey ahk_pid " pid) {
            WinWaitClose,,, .2 ; Wait a moment in case the script is empty/about to exit.
            if !ErrorLevel
                continue ; Back to the top of the loop.
            DetectHiddenWindows Off
            if !WinExist("ahk_pid " pid)
                MsgBox 0x40, AutoHotkey_L Setup, Your script is running in the background.
            return
        }
    }
    MsgBox % message_flags, AutoHotkey_L Setup, %message%`n`nYour script is located here:`n   %script_path%`n`nDo you want to edit this file?
    IfMsgBox Yes
        Run edit "%script_path%"
}

Quit() {
    ExitApp
}


/*  Setup Actions
 */

; Upgrade to newer version or from AutoHotkey to AutoHotkey_L.
;   Type: "ANSI" or "Unicode"
Upgrade(Type="") {
    global
    _Install({
    (Join C
        type: Type,
        path: DefaultPath,
        menu: DefaultStartMenu,
        ahk2exe: DefaultCompiler,
        dragdrop: DefaultDragDrop,
        utf8: DefaultToUTF8,
        isHostApp: DefaultIsHostApp
    )})
}

; Quick install with default options.
QuickInstall() {
    global
    _Install({
    (Join
        type: DefaultType,
        path: DefaultPath,
        menu: DefaultStartMenu,
        ahk2exe: DefaultCompiler,
        dragdrop: DefaultDragDrop,
        utf8: DefaultToUTF8,
        isHostApp: DefaultIsHostApp
    )})
}

; Begin installation after reviewing options.
CustomInstall() {
    local w := getWindow()
    _Install({
    (C Join
        type: w.installtype.value,
        path: w.installdir.value,
        menu: w.startmenu.value,
        ahk2exe: w.installcompiler.checked,
        dragdrop: w.enabledragdrop.checked,
        utf8: DefaultToUTF8, ;w.defaulttoutf8.checked
        isHostApp: w.separatebuttons.checked
    )})
}

; Uninstall.
Uninstall() {
    global
    
    try
        SetWorkingDir % CurrentPath
    catch
        ErrorExit("Error uninstalling; installation directory '" CurrentPath "' may be invalid.")
    
    CloseScriptsEtc(CurrentPath, "uninstallation")
    
    switchPage("wait")
    
    /*  Registry
     */
    
    SetRegView % CurrentRegView
    
    RegDelete HKLM, %UninstallKey%
    RegDelete HKLM, %AutoHotkeyKey%
    RegDelete HKCU, %AutoHotkeyKey%  ; Created by Ahk2Exe.
    
    RegDelete HKCR, .ahk
    RegDelete HKCR, %FileTypeKey%
    RegDelete HKCR, Applications\AutoHotkey.exe
    
    RegDelete HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoHotkey.exe
    
    /*  Files
     */
    
    FileDelete AutoHotkeyU32.exe
    FileDelete AutoHotkeyA32.exe
    FileDelete AutoHotkeyU64.exe
    
    FileDelete AU3_Spy.exe
    FileDelete AutoHotkey.chm
    FileDelete license.txt
    
    ; This file would only exist if an older version of AutoHotkey_L
    ; installed it:
    FileDelete Update.ahk
    
    ; Although the old installer was designed not to overwrite this in
    ; case the user made customizations, the old uninstaller deletes it:
    FileDelete %A_WinDir%\ShellNew\Template.ahk
    
    RemoveCompiler()
    
    FileDelete %ProductName% Website.url
    if (CurrentStartMenu != "")  ; Must not remove A_ProgramsCommon itself!
        FileRemoveDir %A_ProgramsCommon%\%CurrentStartMenu%, 1
    
    if !SilentMode
        MsgBox 64, AutoHotkey_L Setup
            , Setup will now close to complete the uninstallation.
    
    ; Try deleting it normally first, in case this script is running
    ; on an external exe (such as via a downloaded installer).
    FileDelete AutoHotkey.exe
    if !ErrorLevel {
        FileDelete Installer.ahk
        SetWorkingDir %A_Temp%  ; Otherwise FileRemoveDir will fail.
        FileRemoveDir %CurrentPath%  ; Only if empty.
        ExitApp
    }
    
    Gui Cancel
    
    ; Use cmd.exe to work around the fact that AutoHotkey.exe is locked
    ; while it is still running.  Having a second instance of the script
    ; terminate this instance should be more reliable than performing
    ; an arbitrary wait (e.g. by calling "ping").
    Run %ComSpec% /c "
    (Join`s&`s
    AutoHotkey.exe "%A_ScriptFullPath%" /kill %A_ScriptHwnd%
    del Installer.ahk
    del AutoHotkey.exe
    cd %A_Temp%
    rmdir "%CurrentPath%"
    )",, Hide
}


/*  Installation
 */

_Install(opt) {
    global
    
    /*  Validation
     */
    
    local exefile, binfile
    if opt.type = "Unicode" {
        exefile := "AutoHotkeyU32.exe"
        binfile := "Unicode 32-bit.bin"
    } else if opt.type = "x64" && A_Is64bitOS {
        exefile := "AutoHotkeyU64.exe"
        binfile := "Unicode 64-bit.bin"
    } else if opt.type = "ANSI" {
        exefile := "AutoHotkeyA32.exe"
        binfile := "ANSI 32-bit.bin"
    } else
        ErrorExit("Invalid installation type '" opt.type "'")
    
    if !InStr(FileExist(opt.path), "D")
        try
            FileCreateDir % opt.path
        catch
            ErrorExit("Unable to create installation directory ('" opt.path "')")
    
    CloseScriptsEtc(CurrentPath, "installation")
    
    /*  Preparation
     */
    
    SetWorkingDir % opt.path
    
    switchPage("wait")
    
    ; Remove old files which are no longer relevant.
    if (CurrentName = "AutoHotkey") {
        FileDelete Compiler\README.txt
        FileDelete Compiler\upx.exe
    }
    FileDelete uninst.exe
    
    if A_Is64bitOS {
        ; For xx-bit installs, write to the xx-bit view of the registry.
        local regView := (opt.type = "x64") ? 64 : 32
        if (CurrentRegView && CurrentRegView != regView) {
            ; Clean up old keys in the other registry view.
            SetRegView % CurrentRegView
            RegDelete HKLM, %UninstallKey%
            RegDelete HKLM, %AutoHotkeyKey%
            RegDelete HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoHotkey.exe
            RegDelete HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe
        }
        SetRegView % regView
    }
    
    /*  Install Files
     */
    
    UpdateStatus("Copying files")
    
    ; If the following is "true", we have no source files to install,
    ; but we may have settings to change.  This includes replacing the
    ; binary files with %exefile% and %binfile%.
    installInPlace := (A_WorkingDir = A_ScriptDir)
    
    ; Install all unique files.
    if !installInPlace {
        InstallMainFiles()
        if opt.ahk2exe
            InstallCompilerFiles()
    }
    
    ; If the user deselected Ahk2Exe and it was previously installed,
    ; ensure it is removed.
    if !opt.ahk2exe
        RemoveCompiler()
    
    ; Create the "default" binaries, corresponding to whichever version
    ; the user selected.
    if !installInPlace
        InstallFile(exefile, "AutoHotkey.exe")
    ;else: a workaround is needed later.
    if opt.ahk2exe
        InstallFile("Compiler\" binfile, "Compiler\AutoHotkeySC.bin")
    
    /*  Start Menu Shortcuts
     */
    
    if CurrentStartMenu
        FileRemoveDir %A_ProgramsCommon%\%CurrentStartMenu%, 1
    
    if opt.menu {
        UpdateStatus("Creating shortcuts")
        local smpath := A_ProgramsCommon "\" opt.menu
        FileCreateDir %smpath%
        FileCreateShortcut %A_WorkingDir%\AutoHotkey.exe, %smpath%\AutoHotkey.lnk
        FileCreateShortcut %A_WorkingDir%\AU3_Spy.exe, %smpath%\AutoIt3 Window Spy.lnk
        FileCreateShortcut %A_WorkingDir%\AutoHotkey.chm, %smpath%\AutoHotkey Help File.lnk
        IniWrite %ProductWebsite%, %ProductName% Website.url, InternetShortcut, URL
        FileCreateShortcut %A_WorkingDir%\%ProductName% Website.url, %smpath%\Website.lnk
        FileCreateShortcut %A_WorkingDir%\Installer.ahk, %smpath%\AutoHotkey Setup.lnk
            ,,,, %A_WinDir%\System32\appwiz.cpl,, -1499
        if opt.ahk2exe
            FileCreateShortcut %A_WorkingDir%\Compiler\Ahk2Exe.exe
                , %smpath%\Convert .ahk to .exe.lnk
    }
    
    /*  Registry
     */
    
    UpdateStatus("Configuring registry")
    
    RegWrite REG_SZ, HKLM, %AutoHotkeyKey%, InstallDir, %A_WorkingDir%
    RegWrite REG_SZ, HKLM, %AutoHotkeyKey%, Version, %ProductVersion%
    if opt.menu
        RegWrite REG_SZ, HKLM, %AutoHotkeyKey%, StartMenuFolder, % opt.menu
    else
        RegDelete HKLM, %AutoHotkeyKey%, StartMenuFolder
    
    ; Might need to get rid of this to allow the ShellNew template to work:
    RegDelete HKCR, ahk_auto_file
    RegWrite REG_SZ, HKCR, .ahk,, %FileTypeKey%
    RegWrite REG_SZ, HKCR, .ahk\ShellNew, FileName, Template.ahk
    
    RegWrite REG_SZ, HKCR, %FileTypeKey%,, AutoHotkey Script
    RegWrite REG_SZ, HKCR, %FileTypeKey%\DefaultIcon,, %A_WorkingDir%\AutoHotkey.exe`,1
    
    ; Set up system verbs:
    RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Open,, Run Script
    RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Edit,, Edit Script
    if opt.ahk2exe
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Compile,, Compile Script
    
    local value
    
    ; Set default action, but don't overwrite.
    try
        RegRead value, HKCR, %FileTypeKey%\Shell,
    catch   ; Key likely doesn't exist.
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell,, Open
    
    ; Set editor, but don't overwrite.
    try
        RegRead value, HKCR, %FileTypeKey%\Shell\Edit\Command,
    catch
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Edit\Command,, notepad.exe `%1
    
    if opt.ahk2exe
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Compile\Command,, "%A_WorkingDir%\Compiler\Ahk2Exe.exe" /in "`%l"
    
    local cmd
    cmd = "%A_WorkingDir%\AutoHotkey.exe"
    if opt.utf8
        cmd = %cmd% /CP65001
    cmd = %cmd% "`%1" `%*
    RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\Open\Command,, %cmd%
    
    ; If UAC is enabled, add a "Run as administrator" option.
    RegRead value, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System, EnableLUA
    if value
        RegWrite REG_SZ, HKCR, %FileTypeKey%\Shell\RunAs\Command,, "%A_WorkingDir%\AutoHotkey.exe" "`%1" `%*
    
    if opt.dragdrop
        RegWrite REG_SZ, HKCR, %FileTypeKey%\ShellEx\DropHandler,, {86C86720-42A0-1069-A2E8-08002B30309D}
    else
        RegDelete HKCR, %FileTypeKey%\ShellEx
    
    RegWrite REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoHotkey.exe,, %A_WorkingDir%\AutoHotkey.exe
    if opt.ahk2exe
        RegWrite REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe,, %A_WorkingDir%\Compiler\Ahk2Exe.exe
    
    RegDelete HKCR, Applications\AutoHotkey.exe
    if opt.isHostApp
        RegWrite REG_SZ, HKCR, Applications\AutoHotkey.exe, IsHostApp
    
    ; Write uninstaller info.
    RegWrite REG_SZ, HKLM, %UninstallKey%, DisplayName, %ProductName% %ProductVersion%
    RegWrite REG_SZ, HKLM, %UninstallKey%, UninstallString, "%A_WorkingDir%\AutoHotkey.exe" "%A_WorkingDir%\Installer.ahk"
    RegWrite REG_SZ, HKLM, %UninstallKey%, DisplayIcon, %A_WorkingDir%\AutoHotkey.exe
    RegWrite REG_SZ, HKLM, %UninstallKey%, DisplayVersion, %ProductVersion%
    RegWrite REG_SZ, HKLM, %UninstallKey%, URLInfoAbout, %ProductWebsite%
    RegWrite REG_SZ, HKLM, %UninstallKey%, Publisher, %ProductPublisher%
    RegWrite REG_SZ, HKLM, %UninstallKey%, NoModify, 1
    
    if installInPlace {
        ; As AutoHotkey.exe is probably in use by this script, the final
        ; step will be completed by another instance of this script:
        Run AutoHotkeyU32.exe "%A_ScriptFullPath%" /fin %exefile% %A_ScriptHwnd% %SilentMode%
        ExitApp
    }
    
    switchPage("done")
}

InstallFile(file, target="") {
    global
    if (target = "")
        target := file
    Loop { ; Retry loop.
        try {
            FileCopy %SourceDir%\%file%, %target%, 1
            ; If successful (no exception thrown):
            return
        }
        if SilentMode {
            SilentErrors += 1
            return  ; Continue anyway.
        }
        local error_message := RTrim(GetErrorMessage(), "`r`n")
        MsgBox 0x12, AutoHotkey_L Setup,
        (LTrim
        Error installing file "%target%"
        
        Specifically: %error_message%
        
        Click Abort to stop the installation,
        Retry to try again, or
        Ignore to skip this file.
        )
        IfMsgBox Abort
            ExitApp
        IfMsgBox Ignore
            return
    }
}

InstallMainFiles() {
    InstallFile("AutoHotkeyU32.exe")
    InstallFile("AutoHotkeyA32.exe")
    if A_Is64bitOS
        InstallFile("AutoHotkeyU64.exe")
    
    InstallFile("AU3_Spy.exe")
    InstallFile("AutoHotkey.chm")
    InstallFile("license.txt")
    
    InstallFile("Installer.ahk")
    
    if !FileExist(A_WinDir "\ShellNew\Template.ahk")
        InstallFile("Template.ahk", A_WinDir "\ShellNew\Template.ahk")
}

InstallCompilerFiles() {
    FileCreateDir Compiler
    InstallFile("Compiler\Ahk2Exe.exe")
    InstallFile("Compiler\ANSI 32-bit.bin")
    InstallFile("Compiler\Unicode 32-bit.bin")
    ; Install the following file even if !isOS64bit() to support
    ; compiling scripts for 64-bit systems on 32-bit systems:
    InstallFile("Compiler\Unicode 64-bit.bin")
}

RemoveCompiler() {
    global
    FileDelete Compiler\Ahk2Exe.exe
    FileDelete Compiler\ANSI 32-bit.bin
    FileDelete Compiler\Unicode 32-bit.bin
    FileDelete Compiler\Unicode 64-bit.bin
    FileDelete Compiler\AutoHotkeySC.bin
    FileRemoveDir Compiler  ; Only if empty.    
    RegDelete HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe
}

;#debug
    ~^s::
    Sleep 250
    InitUI()
    return

    #IfWinActive AutoHotkey_L Setup ahk_class AutoHotkeyGUI

    ^1::
    Test?fresh:
    LoadUI("", "", DefaultType, ProductVersion)
    return

    ^2::
    Test?upgrade:
    LoadUI("AutoHotkey", "1.0.48.05", "ANSI", ProductVersion)
    return

    ^3::
    Test?update:
    LoadUI("AutoHotkey_L", "1.1.00.00", CurrentType, ProductVersion)
    return

    ^4::
    Test?repair:
    LoadUI("AutoHotkey_L", ProductVersion, CurrentType, ProductVersion)
    return

    ^5::
    Test:
    ThisVer := ProductVersion
    InputBox ThisVer,, Debug: Enter version to be installed.
        ,,,,,,,, %ThisVer%
    LoadUI(CurrentName, CurrentVersion, CurrentType, ThisVer)
    return

    LoadUI(InstName, InstVer, InstType, ThisVer) {
        global
        getWindow().initOptions(InstName, InstVer, InstType, ThisVer
                                , DefaultPath, DefaultStartMenu)
    }

    Reload:
    Reload
    return
;#end

DefineUI:
FileRead html, %A_ScriptDir%\Installer_src.htm
return