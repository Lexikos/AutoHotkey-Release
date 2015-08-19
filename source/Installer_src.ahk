#NoEnv
#NoTrayIcon
; #Warn
#SingleInstance Off
Menu Tray, Icon, appwiz.cpl, -1500

if !A_IsAdmin && !%False%
{
    if A_OSVersion not in WIN_2003,WIN_XP,WIN_2000
    {
        Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%",, UseErrorLevel
        if !ErrorLevel
            ExitApp
    }
    MsgBox 0x31, AutoHotkey Setup,
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
;#debug
SourceDir := A_ScriptDir "\..\include"
;#end
SilentMode := false
SilentErrors := 0
AutoRestart := false

ProductName := "AutoHotkey"
ProductVersion := A_AhkVersion
ProductPublisher := "Lexikos"
ProductWebsite := "http://ahkscript.org/"

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

Menu Tray, MainWindow  ; Enable debugging setup.exe.

if 1 = /exec ; For internal use
{
    HandleExec(1)
    ExitApp
}

DetermineVersion()

Loop %0%
    if %A_Index% = /S
        SilentMode := true
    else if %A_Index% = /R
        AutoRestart := true
    else if %A_Index% = /U32
        DefaultType = Unicode
    else if %A_Index% in /U64,/x64
        DefaultType = x64
    else if %A_Index% in /A32,/ANSI
        DefaultType = ANSI
    else if InStr(%A_Index%, "/D=") = 1 {
        if !RegExMatch(DllCall("GetCommandLine", "str"), "(?<!"")/D=\K[^""]*?(?=$|[ `t]+/)", DefaultPath)
            DefaultPath := SubStr(%A_Index%, 4)
        Loop %DefaultPath%, 2  ; Resolve relative path.
            DefaultPath := A_LoopFileLongPath
        SlashD := true
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
    else if (%A_Index% = "/E") {
        Extract(SlashD ? DefaultPath : "")
        ExitApp
    }
    else if (SubStr(%A_Index%,1,5) = "/Test")
        TestMode := SubStr(%A_Index%,6)

if SilentMode {
    QuickInstall()
    ExitApp % SilentErrors
}

if WinExist("AutoHotkey Setup ahk_class AutoHotkeyGUI") {
    MsgBox 0x30, AutoHotkey Setup, AutoHotkey Setup is already running!
    WinActivate
    ExitApp
}

OnExit GuiClose

;#debug
Menu TestMenu, Add, RELOAD, Reload
Menu TestMenu, Add, TEST, Test
Menu TestMenu, Add, Set page, Test?page
Menu TestMenu, Add, New Install, Test?fresh
Menu TestMenu, Add, Upgrade, Test?upgrade
Menu TestMenu, Add, Update, Test?update
Menu TestMenu, Add, Repair, Test?repair
Menu TestMenu, Add, Complete, Test?complete
Gui Menu, TestMenu
;#end

Gui Margin, 0, 0
Gui Add, ActiveX, vwb w600 h400 hwndhwb, Shell.Explorer
ComObjConnect(wb, "wb_")
OnMessage(0x100, "gui_KeyDown", 2)
try {
    if !wb
        throw Exception("Failed to create IE control")
    if GetKeyState("Shift") || GetKeyState("Ctrl")
        throw 1
    InitUI()
}
catch excpt {
    if (A_ScriptDir = DefaultPath) {
        MsgBox 0x10, AutoHotkey Setup, Setup failed to initialize its user interface and will now exit.
        ExitApp
    }
    message := IsObject(excpt)
        ? "Setup encountered an error.`n"
        . "  Specifically: " excpt.Message
        : "Setup is in troubleshooting mode (you're holding Ctrl or Shift)."
    type := DefaultType="ANSI" ? "ANSI 32-bit" : "Unicode " (DefaultType="x64"?"64":"32") "-bit"
    MsgBox 0x33, AutoHotkey Setup,
(
%message%

Do you want to install with default options?
  %ProductName% v%ProductVersion% (%type%)
  %DefaultPath%

Click Yes to install.
Click No to copy setup files to a directory of your choosing.
Click Cancel to exit.
)
    IfMsgBox Yes
        QuickInstall()
    else IfMsgBox No
        Extract()
    ExitApp
}
Gui Show,, AutoHotkey Setup
return

GuiEscape:
MsgBox 0x34, AutoHotkey Setup, Are you sure you want to exit setup?
IfMsgBox No
    return
GuiClose:
Gui Destroy
OnExit
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
    if ErrorLevel = 0x300
        CurrentType := "x64"
    else if ErrorLevel = 0x100
        CurrentType := "Unicode"
    else if ErrorLevel = 0
        CurrentType := "ANSI"
    else
        CurrentType := ""
    FileDelete %A_Temp%\VersionTest.ahk
    ; Set some default parameter based on current installation:
    if CurrentType
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
    SetWBClientSite()
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
    wb.Document.close()
    ;#debug
    }
    wb.Navigate(A_ScriptDir "\Installer_src.htm")
    while wb.ReadyState != 4
        Sleep 10
    ;#end
    w := wb.Document.parentWindow
    w.AHK := Func("JS_AHK")
    if (!CurrentType && A_ScriptDir != DefaultPath)
        CurrentName := ""  ; Avoid showing the Reinstall option since we don't know which version it was.
    w.initOptions(CurrentName, CurrentVersion, CurrentType
                , ProductVersion, DefaultPath, DefaultStartMenu
                , DefaultType, A_Is64bitOS = 1)
    if (A_ScriptDir = DefaultPath) {
        w.installdir.disabled := true
        w.installdir_browse.disabled := true
        w.installcompiler.disabled := !DefaultCompiler
        w.installcompilernote.style.display := "block"
        w.ci_nav_install.innerText := "apply"
        w.install_button.innerText := "Apply"
        w.extract.style.display := "None"
        w.opt1.disabled := true
        w.opt1.firstChild.innerText := "Checking for updates..."
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
    ; Scale UI by screen DPI.  My testing showed that Vista with IE7 or IE9
    ; did not scale by default, but Win8.1 with IE10 did.  The scaling being
    ; done by the control itself = deviceDPI / logicalDPI.
    logicalDPI := w.screen.logicalXDPI, deviceDPI := w.screen.deviceXDPI
    if (A_ScreenDPI != 96)
        w.document.body.style.zoom := A_ScreenDPI/96 * (logicalDPI/deviceDPI)
    if (A_ScriptDir = DefaultPath)
        CheckForUpdates()
}

CheckForUpdates() {
    local w := getWindow(), latestVersion := ""
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "http://ahkscript.org/download/1.1/version.txt", true)
        whr.Send()
        whr.WaitForResponse()
        latestVersion := whr.responseText
    }
    if RegExMatch(latestVersion, "^(\d+\.){3}\d+") {
        if (latestVersion = ProductVersion)
            w.opt1.firstChild.innerText := "Reinstall (download required)"
        else
            w.opt1.firstChild.innerText := "Download v" latestVersion
        w.opt1.href := "javascript:AHK('DownloadAHK')"
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


/*  javascript:AHK('Func') --> Func()
 */

JS_AHK(func, prms*) {
    global wb
    ; Stop navigation prior to calling the function, in case it uses Exit.
    wb.Stop(),  %func%(prms*)
}


/*  Complex workaround to override "Active scripting" setting
 *  and ensure scripts can run within the WebBrowser control.
 */

global WBClientSite

SetWBClientSite()
{
    interfaces := {
    (Join,
        IOleClientSite: [0,3,1,0,1,0]
        IServiceProvider: [3]
        IInternetSecurityManager: [1,1,3,4,8,7,3,3]
    )}
    unkQI      := RegisterCallback("WBClientSite_QI", "Fast")
    unkAddRef  := RegisterCallback("WBClientSite_AddRef", "Fast")
    unkRelease := RegisterCallback("WBClientSite_Release", "Fast")
    WBClientSite := {_buffers: bufs := {}}, bufn := 0, 
    for name, prms in interfaces
    {
        bufn += 1
        bufs.SetCapacity(bufn, (4 + prms.MaxIndex()) * A_PtrSize)
        buf := bufs.GetAddress(bufn)
        NumPut(unkQI,       buf + 1*A_PtrSize)
        NumPut(unkAddRef,   buf + 2*A_PtrSize)
        NumPut(unkRelease,  buf + 3*A_PtrSize)
        for i, prmc in prms
            NumPut(RegisterCallback("WBClientSite_" name, "Fast", prmc+1, i), buf + (3+i)*A_PtrSize)
        NumPut(buf + A_PtrSize, buf + 0)
        WBClientSite[name] := buf
    }
    global wb
    if pOleObject := ComObjQuery(wb, "{00000112-0000-0000-C000-000000000046}")
    {   ; IOleObject::SetClientSite
        DllCall(NumGet(NumGet(pOleObject+0)+3*A_PtrSize), "ptr"
            , pOleObject, "ptr", WBClientSite.IOleClientSite, "uint")
        ObjRelease(pOleObject)
    }
}

WBClientSite_QI(p, piid, ppvObject)
{
    static IID_IUnknown := "{00000000-0000-0000-C000-000000000046}"
    static IID_IOleClientSite := "{00000118-0000-0000-C000-000000000046}"
    static IID_IServiceProvider := "{6d5140c1-7436-11ce-8034-00aa006009fa}"
    iid := _String4GUID(piid)
    if (iid = IID_IOleClientSite || iid = IID_IUnknown)
    {
        NumPut(WBClientSite.IOleClientSite, ppvObject+0)
        return 0 ; S_OK
    }
    if (iid = IID_IServiceProvider)
    {
        NumPut(WBClientSite.IServiceProvider, ppvObject+0)
        return 0 ; S_OK
    }
    NumPut(0, ppvObject+0)
    return 0x80004002 ; E_NOINTERFACE
}

WBClientSite_AddRef(p)
{
    return 1
}

WBClientSite_Release(p)
{
    return 1
}

WBClientSite_IOleClientSite(p, p1="", p2="", p3="")
{
    if (A_EventInfo = 3) ; GetContainer
    {
        NumPut(0, p1+0) ; *ppContainer := NULL
        return 0x80004002 ; E_NOINTERFACE
    }
    return 0x80004001 ; E_NOTIMPL
}

WBClientSite_IServiceProvider(p, pguidService, piid, ppvObject)
{
    static IID_IUnknown := "{00000000-0000-0000-C000-000000000046}"
    static IID_IInternetSecurityManager := "{79eac9ee-baf9-11ce-8c82-00aa004ba90b}"
    if (_String4GUID(pguidService) = IID_IInternetSecurityManager)
    {
        iid := _String4GUID(piid)
        if (iid = IID_IInternetSecurityManager || iid = IID_IUnknown)
        {
            NumPut(WBClientSite.IInternetSecurityManager, ppvObject+0)
            return 0 ; S_OK
        }
        NumPut(0, ppvObject+0)
        return 0x80004002 ; E_NOINTERFACE
    }
    NumPut(0, ppvObject+0)
    return 0x80004001 ; E_NOTIMPL
}

WBClientSite_IInternetSecurityManager(p, p1="", p2="", p3="", p4="", p5="", p6="", p7="", p8="")
{
    if (A_EventInfo = 5) ; ProcessUrlAction
    {
        if (p2 = 0x1400) ; dwAction = URLACTION_SCRIPT_RUN
        {
            NumPut(0, p3+0)  ; *pPolicy := URLPOLICY_ALLOW
            return 0 ; S_OK
        }
    }
    return 0x800C0011 ; INET_E_DEFAULT_ACTION
}

_String4GUID(pGUID)
{
	VarSetCapacity(String,38*2)
	DllCall("ole32\StringFromGUID2", "ptr", pGUID, "str", String, "int", 39)
	Return	String
}


/*  Utility Functions
 */

getWindow() {
    global wb
    return wb.document.parentWindow
}

ErrorExit(errMsg) {
    global
    if !SilentMode
        MsgBox 16, AutoHotkey Setup, %errMsg%
    ExitApp 1
}

CloseScriptsEtc(installdir, actionToContinue) {
    titles := ""
    DetectHiddenWindows On
    close := [], reopen := []
    WinGet w, List, ahk_class AutoHotkey
    Loop % w {
        ; Exclude the install script.
        if (w%A_Index% = A_ScriptHwnd)
            continue
        ; Determine if the script actually needs to be terminated.
        WinGet exe_path, ProcessPath, % "ahk_id " w%A_Index%
        if (exe_path != "") {
            ; Exclude external executables.
            if InStr(exe_path, installdir "\") != 1
                continue
            ; The main purpose of this next check is to avoid closing
            ; SciTE4AutoHotkey's toolbar, but also may be helpful for
            ; other situations.
            exe := SubStr(exe_path, StrLen(installdir) + 2)
            if !RegExMatch(exe, "i)^(AutoHotkey(A32|U32|U64)?\.exe|Compiler\\Ahk2Exe.exe)$")
                continue
        }        
        ; Append script path to the list.
        WinGetTitle title, % "ahk_id " w%A_Index%
        title := RegExReplace(title, " - AutoHotkey v.*")
        titles .= "  -  " title "`n"
        close.Insert(w%A_Index%)
        if FileExist(title)
            reopen.Insert({path: title, exe: exe_path})
    }
    if (titles != "") {
        global SilentMode, installInPlace
        if !SilentMode {
            static button_retry, button_mode
            button_retry := 3
            if (actionToContinue = "installation" && !installInPlace) {
                help_text =
                (LTrim
                Click Reload to automatically reload the scripts later.
                Click Close All to just close the scripts and continue.
                )
                button_mode := 3
            } else {
                help_text =
                (LTrim
                Click Close All to close all scripts and continue the %actionToContinue%.
                )
                button_mode := 1
            }
            SetTimer CloseScriptsEtc_Buttons, -5
            MsgBox % 48|button_mode, AutoHotkey Setup,
            (LTrim
            Setup needs to close the following script(s):
            `n%titles%
            %help_text%
            )
            IfMsgBox Cancel
                Exit
            IfMsgBox Yes
                global AutoRestart := true
        }
        ; Close script windows (typically causing them to exit).
        Loop % close.MaxIndex()
        {
            WinClose % "ahk_id " close[A_Index]
            WinWaitClose % "ahk_id " close[A_Index],, 1
        }
    }
    ; Close all help file and Window Spy windows automatically:
    GroupAdd autoclosegroup, AutoHotkey_L Help ahk_class HH Parent
    GroupAdd autoclosegroup, AutoHotkey Help ahk_class HH Parent
    GroupAdd autoclosegroup, Active Window Info ahk_exe %installdir%\AU3_Spy.exe
    ; Also close the old Ahk2Exe (but the new one is a script, so it
    ; was already handled by the section above):
    GroupAdd autoclosegroup, Ahk2Exe v ahk_exe %installdir%\Compiler\Ahk2Exe.exe
    WinClose ahk_group autoclosegroup
    return reopen
    
    CloseScriptsEtc_Buttons:
    Critical
    if !WinExist("ahk_class #32770 ahk_pid " DllCall("GetCurrentProcessId")) {
        if (button_retry--)
            SetTimer,, -5
        return
    }
    if (button_mode = 1)
        ControlSetText Button1, Close &All
    else {
        ControlSetText Button1, &Reload
        ControlSetText Button2, Close &All
    }
    return
}

ReopenScripts(scripts) {
    global AutoRestart
    if !AutoRestart || !scripts || !scripts.MaxIndex()
        return
    failed := ""
    for i, script in scripts {
        try
            script.exe ? Run_(script.exe, """" script.path """")
                       : Run_("""" script.path """")
        catch
            failed .= "`n" script
    }
    if (failed != "" && !SilentMode)
        MsgBox 16, AutoHotkey Setup, Failed to restart the following scripts:`n%failed%
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
    ; ToolTip % status
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
        Run_("http://ahkscript.org" topic)
}

RunAutoHotkey() {
    ; Setup may be running as a user other than the one that's logged
    ; in (i.e. an admin user), so in addition to running AutoHotkey.exe
    ; in user mode, have it call the function below to ensure the script
    ; file is correctly located.
    Run_("AutoHotkey.exe", """" A_WorkingDir "\Installer.ahk"" /exec runahk")
}
Exec_RunAHK() {
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
            if !FileExist(script_path) {
                WinWait AutoHotkey Help,, 1
                if !ErrorLevel {
                    WinActivate  ; Welcome screen (v1.1.20).
                    return
                }
            }
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
                MsgBox 0x40, AutoHotkey Setup, Your script is running in the background.
            return
        }
    }
    MsgBox % message_flags, AutoHotkey Setup, %message%`n`nYour script is located here:`n   %script_path%`n`nDo you want to edit this file?
    IfMsgBox Yes
    {
        if !FileExist(script_path)
            FileAppend,, %script_path%
        Run edit "%script_path%"
    }
}

Quit() {
    ExitApp
}

ViewWebsite() {
    global
    Run_(ProductWebsite)
}

Extract(dstDir="") {
    if (dstDir = "") {
        FileSelectFolder dstDir,,, Select a folder to copy program files to.
        if ErrorLevel
            return
    }
    try {
        global TestMode, SourceDir
        if (TestMode = "FailExtract")
            throw
        shell := ComObjCreate("Shell.Application")
        try FileCreateDir %dstDir%
        dst := shell.NameSpace(dstDir)
        src := shell.NameSpace(SourceDir)
        if !(dst && src)
            throw
        try dst.CopyHere(src.Items, 256)
    }
    catch {
        FileCopyDir %SourceDir%, %dstDir%, 1
        if ErrorLevel {
            MsgBox 48, AutoHotkey Setup, An unspecified error occurred.
            return
        }
    }
    Run %dstDir%
}

DownloadAHK() {
    file := A_Temp "\ahk-install.exe"
    switchPage("downloading")
    Sleep 10
    if !Download("http://ahkscript.org/download/ahk-install.exe", file, "DownloadAHK_Progress") {
        MsgBox 16,, Download failed.
        switchPage("start")
        return
    }
    Run "%file%" /exec waitclose %A_ScriptHwnd% /exec downloaded "%file%"
    ExitApp
}
Exec_WaitClose(hwnd) {
    DetectHiddenWindows On
    WinWaitClose ahk_id %hwnd%
}
Exec_Downloaded(file) {
    ; global SilentMode := true
    DetermineVersion()
    QuickInstall()
    ; NOTE: .\ is required here.  Otherwise it launches the copy found
    ; in the directory containing the current module -- the temp dir.
    Run .\AutoHotkeyU32.exe Installer.ahk /exec cleanup "%file%"
}
Exec_Cleanup(file) {
    SplitPath file, name
    Process WaitClose, %name%
    MsgBox 64, AutoHotkey Setup, Installation complete.
    FileDelete %file%
}
DownloadAHK_Progress(n, nMax) {
    if !nMax
        return
    w := getWindow()
    w.document.getElementById("dl_progress")
        .style.width := (n*100/nMax) "%"
    w.document.getElementById("dl_text")
        .innerText := DownloadSize(n) " / " DownloadSize(nMax)
    Sleep 10
}
DownloadSize(n) {
    n /= 1024
    if (n > 1024)
        return Round(n/1024, 2) " MB"
    return Round(n, 2) " KB"
}

; Based on code by Sean and SKAN @ http://www.autohotkey.com/forum/viewtopic.php?p=184468#184468
Download(url, file, callback) {
    static vt
    if !VarSetCapacity(vt) {
        VarSetCapacity(vt, A_PtrSize*11), nPar := "31132253353"
        Loop Parse, nPar
            NumPut(RegisterCallback("DL_Progress", "F", A_LoopField, A_Index-1), vt, A_PtrSize*(A_Index-1))
    }
    if !(IsObject(callback) || (callback := Func(callback)))
        return !(ErrorLevel := 1)
    VarSetCapacity(bobj, A_PtrSize*2), NumPut(&callback, NumPut(&vt, bobj)), VarSetCapacity(tn, 520)
    if (0 = DllCall("urlmon\URLDownloadToCacheFile", "ptr", 0, "str", url, "str", tn, "uint", 260, "uint", 0x10, "ptr", &bobj))
        FileCopy %tn%, %file%, 1
    else
        ErrorLevel := 1
    return !ErrorLevel
}
DL_Progress( pthis, nP=0, nPMax=0, nSC=0, pST=0 ) {
    if A_EventInfo = 6
        fn := Object(NumGet(pthis+A_PtrSize)), %fn%(np, npMax)
    return 0
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
        MsgBox 64, AutoHotkey Setup
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
    AutoHotkey.exe "%A_ScriptFullPath%" /exec kill %A_ScriptHwnd%
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
    
    /*  Preparation
     */
    
    SetWorkingDir % opt.path
    
    ; If the following is "true", we have no source files to install,
    ; but we may have settings to change.  This includes replacing the
    ; binary files with %exefile% and %binfile%.
    installInPlace := (A_WorkingDir = A_ScriptDir)
    
    reopen := CloseScriptsEtc(CurrentPath, "installation")
    
    switchPage("wait")
    
    ; Remove old files which are no longer relevant.
    if (CurrentVersion <= "1.0.48.05") {
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
    
    ; Notify other programs (e.g. explorer.exe) that file type associations have changed.
    ; This may be necessary to update the icon when upgrading from an older version of AHK.
    DllCall("shell32\SHChangeNotify", "uint", 0x08000000, "uint", 0, "int", 0, "int", 0) ; SHCNE_ASSOCCHANGED
    
    UpdateStatus("")
    
    if installInPlace {
        ; As AutoHotkey.exe is probably in use by this script, the final
        ; step will be completed by another instance of this script:
        Run .\AutoHotkeyU32.exe "%A_ScriptFullPath%"
                /exec kill %A_ScriptHwnd%
                /exec setExe %exefile% %SilentMode%
        ExitApp
    }
    
    ReopenScripts(reopen)
    
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
        MsgBox 0x12, AutoHotkey Setup,
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
    
    if !FileExist(A_WinDir "\ShellNew\Template.ahk") {
        FileCreateDir %A_WinDir%\ShellNew
        InstallFile("Template.ahk", A_WinDir "\ShellNew\Template.ahk")
    }
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

HandleExec(n) {
    Loop {
        ++n, fn := Func("Exec_" %n%), args := []
        Loop % %false% - n {
            ++n, v := %n%
            if v = /exec
                break
            args.Insert(v)
        }
        c := Round(args.MaxIndex())
        if !fn || c < fn.MinParams || c > fn.MaxParams
            ErrorExit("Internal: bad /exec")
        %fn%(args*)
    }
    until v != "/exec"
}

Exec_Kill(id) {
    DetectHiddenWindows On
    WinKill ahk_id %id%
    WinWaitClose ahk_id %id%,, 10
}

Exec_SetExe(exefile, SilentMode := false) {
    InstallFile(exefile, "AutoHotkey.exe")
    if !SilentMode
        MsgBox 64, AutoHotkey Setup, The settings have been updated.
}

;#debug
    ~^s::
    Sleep 250
    ; InitUI()  ; SetClientSite() currently causes a crash on Win 8.1 the second time it's called.
    Reload
    return

    #IfWinActive AutoHotkey Setup ahk_class AutoHotkeyGUI
    
    Test?page:
    InputBox _page_,, Type a page name to switch to.
    if !ErrorLevel
        switchPage(_page_)
    return

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
    LoadUI("AutoHotkey", "1.1.00.00", CurrentType, ProductVersion)
    return

    ^4::
    Test?repair:
    LoadUI("AutoHotkey", ProductVersion, CurrentType, ProductVersion)
    return

    Test?complete:
    switchPage("done")
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
                                , DefaultPath, DefaultStartMenu
                                , DefaultType, A_Is64bitOS = 1)
    }

    Reload:
    Reload
    return
;#end

DefineUI:
FileRead html, %A_ScriptDir%\Installer_src.htm
return