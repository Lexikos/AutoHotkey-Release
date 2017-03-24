
IniFile = %A_ScriptDir%\release.ini

; External tools
IniRead Editor, %IniFile%, Tools, Editor, notepad.exe
IniRead PSFTP, %IniFile%, Tools, PSFTP, %A_ProgramFiles%\PuTTY\psftp.exe
IniRead SevenZip, %IniFile%, Tools, SevenZip, 0
if !SevenZip
{
    RegRead SevenZip, HKLM\Software\7-Zip, Path
    if ErrorLevel
        Prompt("7-zip not found; zip will not be created", 0)
    else
        SevenZip = %SevenZip%\7z.exe
}

IniRead gh_owner, %IniFile%, GitHub, owner, 0
IniRead gh_repo,  %IniFile%, GitHub, repo,  0
IniRead gh_token, %IniFile%, GitHub, token, 0

; Prefix for all FTP remote URLs (optional)
IniRead FtpPrefix, %IniFile%, FTP, Prefix, % A_Space


ProjDir = %A_ScriptDir%\..\AutoHotkey_L
InstDir = %A_ScriptDir%\installer
WebDir = %A_ScriptDir%\files\web  ; Location of index.htm and .htaccess (optional)


#NoEnv
FileEncoding UTF-8-RAW
TempDir = %A_ScriptDir%\temp
FileCreateDir %TempDir%
SetWorkingDir %ProjDir%


#include git.ahk
#include ftp.ahk
#include Build.ahk
#include GitHub.ahk
#include prepare-ver.ahk
#include prepare-docs.ahk
#include prepare-github.ahk


FormatTime now
D("==================== " now " ====================")


/*************************************************************
 *                GET CURRENT GIT TAG/STATUS
 */

FileRead head, .git\HEAD
if !RegExMatch(head, "^ref: refs/heads/\K\S+(?=`n$)", branch)
{
    ExitError(head ? "Not on a branch. Current head:`n" head : ".git\HEAD is missing.")
}

; Let git() and each call to a console app use the same console
DllCall("AllocConsole")

; Compare HEAD to most recent tag.
if !RegExMatch(cdesc:=git("describe --long --match v* --dirty --first-parent")
        , "^(?<tag>v.*)-(?<cnt>\d+)-g(?<id>\w+)(?<dirty>-dirty)?$", c)
{
    ExitError("Failed to determine version; git tags may be missing.")
}
D(ccnt " commits since " ctag ", head is " cid)
if (cdirty)
{
    ExitError("Working directory has unstaged changes. Aborting.")
}
if (ccnt = 0)
{
    D("Nothing to commit")
    committing := false
}
version := SubStr(ctag, 2)
if (branch = "alpha")
    version .= "-" cid


/*************************************************************
 *                  MORE CONFIGURATION
 */

if (branch = "master")
{
    DocDir = %A_ScriptDir%\..\Docs\v1
    ChangeLogFile = %DocDir%\docs\AHKL_ChangeLog.htm
    Ahk2ExeDir = %A_ScriptDir%\..\Ahk2Exe
    Ahk2ExeCmd = "%A_AhkPath%" "%Ahk2ExeDir%\Ahk2Exe.ahk"
}
else if (branch = "alpha")
{
    DocDir = %A_ScriptDir%\..\Docs\v2
    ChangeLogFile =
}


/*************************************************************
 *                      WHAT TO DO?
 */

has_docs := DocDir != "" && InStr(FileExist(DocDir), "D")
has_ahk2exe := Ahk2ExeDir != "" && InStr(FileExist(Ahk2ExeDir), "D")
has_installer := has_docs && has_ahk2exe
has_github := gh_owner && gh_repo && gh_token && (A_PtrSize=4 || ActiveScript)

committing := branch != "edge" && (committing || committing="" && Prompt("Commit?"))
building := committing || Prompt("Build?")
update_helpfile := has_docs && (committing || Prompt("Update help file?"))
update_ahk2exe := has_ahk2exe && (building || Prompt("Update Ahk2Exe?"))
update_installer := has_installer && (building || update_helpfile || update_ahk2exe || Prompt("Update installer?"))
update_zip := SevenZip && (building || update_helpfile || update_ahk2exe)
gh_release := has_github && branch == "master" && (committing || Prompt("GitHub release?"))
pushing := committing


if committing
{
    ; Check status and bump version number
    PrepareNewVersion()

    ; Generate changelog for this release
    if has_docs
        PrepareDocsBegin(ctag, version)
}
else if building
{
    ; Set version number for build
    if (ccnt || cdirty)
        PrepareEdgeVersion()
    else
        PrepareVersion()
}


OutDir := A_ScriptDir "\files\" version
FileCreateDir %OutDir%
if ErrorLevel
    ExitError("Failed to create directory:`n  " OutDir)
FtpScript = %OutDir%\ftp.txt
RemoteDownloadDir := "/download/" SubStr(version, 1, 3)


/*************************************************************
 *                REBUILD ALL BINARIES
 */

build_errors := 0

if building
{
    D("! Building")
    
    builds := [
    (Join,
        {cfg: "Release"              , platform: "Win32"}
        {cfg: "Self-contained"       , platform: "Win32"}
        {cfg: "Release"              , platform:   "x64"}
        {cfg: "Self-contained"       , platform:   "x64"}
    )]
    if (version < "2.")
    {
        builds.push(
        (Join,
            {cfg: "Release(mbcs)"        , platform: "Win32"}
            {cfg: "Self-contained(mbcs)" , platform: "Win32"}
        ))
    }
    Build(builds)
    
    if build_errors
        ExitError(build_errors " build error(s)")
    
    ; Update installer includes.
    FileCopy bin\Win32w\AutoHotkey.exe,   %InstDir%\include\AutoHotkeyU32.exe, 1
    FileCopy bin\Win32a\AutoHotkey.exe,   %InstDir%\include\AutoHotkeyA32.exe, 1
    FileCopy bin\x64w\AutoHotkey.exe,     %InstDir%\include\AutoHotkeyU64.exe, 1
    FileCopy bin\Win32w\AutoHotkeySC.bin, %InstDir%\include\Compiler\Unicode 32-bit.bin, 1
    FileCopy bin\Win32a\AutoHotkeySC.bin, %InstDir%\include\Compiler\ANSI 32-bit.bin,    1
    FileCopy bin\x64w\AutoHotkeySC.bin,   %InstDir%\include\Compiler\Unicode 64-bit.bin, 1
}


/*************************************************************
 *                  COMMIT AND TAG
 */

if committing
{
    if (branch == "master")
    {
        D("! Committing v" version)
        git("commit -m ""v" version """ --only source/ahkversion.h")
    }

    if (branch == "master" || branch == "alpha")
    {
        D("! Creating tag v" version)
        git("tag -m v" version " v" RegExReplace(version, "-\Q" cid "\E$"))
        tagged := true
    }
}


/*************************************************************
 *             FINISH UPDATING VERSION HISTORY
 */

if committing && has_docs
{
    PrepareDocsEnd()
}


/*************************************************************
 *             PREPARE FOR GITHUB RELEASE
 */

if gh_release
{
    PrepareGitHubBegin()
}


/*************************************************************
 *                UPDATE HELP FILE
 */

if update_helpfile
{
    PrepareDocsCHM()
}


/*************************************************************
 *                REBUILD AHK2EXE
 */

if update_ahk2exe
{
    D("! Pulling Ahk2Exe")
    git("pull origin master", Ahk2ExeDir)
    
    D("! Compiling Ahk2Exe")
    RunWait %Ahk2ExeCmd%
        /in "%Ahk2ExeDir%\Ahk2Exe.ahk"
        /out "%InstDir%\include\Compiler\Ahk2Exe.exe"
        /bin "%InstDir%\include\Compiler\Unicode 32-bit.bin"
        /icon "%A_ScriptDir%\ahk2exe.ico"
        , %Ahk2ExeDir%
}


/*************************************************************
 *                UPDATE INSTALLER
 */

InstName := "AutoHotkey_" version "_setup.exe"
InstPath := OutDir "\" InstName
if update_installer
{
    D("! Updating installer")
    ; Build installer package.
    RunWait "%InstDir%\tools\UPDATE.bat" "%InstPath%"
    if ErrorLevel
        Prompt("Failed to update installer!", 0)
    else
        FtpQPut(InstPath, RemoteDownloadDir "/" InstName)
}


/*************************************************************
 *                  UPDATE ZIP FILE
 */

ZipName := "AutoHotkey_" version ".zip"
ZipPath := OutDir "\" ZipName
if update_zip && FileExist(A_ScriptDir "\zip-files-" branch ".txt")
{
    D("! Zipping")
    zip_list := """@" A_ScriptDir "\zip-files-" branch ".txt"""
    FileDelete %ZipPath%
    RunWait "%SevenZip%" a -tzip "%ZipPath%" %zip_list%, %InstDir%\include, UseErrorLevel
    if ErrorLevel
        Prompt("Zipping failed (exit code " ErrorLevel ")", 0)
    else
        FtpQPut(ZipPath, RemoteDownloadDir "/" ZipName)
}


/*************************************************************
 *                SYNC WITH GITHUB.COM
 */

if pushing
{
    ; Push all updates to remote repo.
    D("! Pushing")
    if (branch == "edge")
        git("push -f origin edge:edge")
    else
        git("push")
    if tagged
        git("push origin tag v" version)
}

if gh_release
{
    PrepareGitHubEnd()
    
    FileRead log, %GitHubLog%
    
    ; Remove header used for previewing (see prepare-docs.ahk).
    log := Trim(RegExReplace(log, "s)<!--temp.*?/temp-->"), " `t`r`n")
    
    try
    {
        ; Create a new GitHub Release and upload the installer
        context := new GitHub.Context(gh_owner, gh_repo, gh_token)
        release := new GitHub.Release(context, {tag_name: "v" version, body: log})
        release.AddAsset(InstName, InstPath)
    }
    catch error
    {
        D("- GitHub release error : " error.message " (" error.extra ")")
    }
}


/*************************************************************
 *                SYNC WITH AUTOHOTKEY.COM
 */

if committing
{
    FileOpen(TempDir "\version.txt", "w").Write(version)
    FtpQPut(TempDir "\version.txt", RemoteDownloadDir "/version.txt")
    
    if (branch == "master")
    {
        ; Update 'last update' date
        FormatTime date,, MMMM d, yyyy
        RegExUpdate(WebDir "\index.htm"
            , "/download/index.htm"
            , "(?<=<!--update-->).*(?=<!--/update-->)"
            , "v" version " - " date)
        
        ; Update download redirects
        rewrite_rules =
        (LTrim
        RewriteRule ^ahk-install\.exe$ 1.1/%InstName% [R=301,L,E=nocache:1]
        RewriteRule ^ahk\.zip$ 1.1/%ZipName% [R=301,L,E=nocache:1]
        )
        RegExUpdate(WebDir "\.htaccess"
            , "/download/.htaccess"
            , "s)# v1.1`n\K.*?(?=`n#)"
            , rewrite_rules)
    }
    else if (branch == "alpha")
    {
        rewrite_rules =
        (LTrim
        RewriteRule ^ahk-v2\.zip$ 2.0/%ZipName% [R=301,L,E=nocache:1]
        )
        RegExUpdate(WebDir "\.htaccess"
            , "/download/.htaccess"
            , "s)# v2.0`n\K.*?(?=`n#)"
            , rewrite_rules)
    }
}

RegExUpdate(local_file, remote_file, needle, replacement)
{
    if !FileExist(local_file)
        return
    FileRead file_text, %local_file%
    file_text := RegExReplace(file_text, needle, replacement, replaced, 1)
    if replaced
    {
        FileOpen(local_file, "w").Write(file_text)
        FtpQPut(local_file, remote_file)
    }
    else Prompt(local_file " not updated!", 0)
}

D("! Executing FTP script")
FtpExecute()


D("`n")
Sleep 1000
ExitApp


/*************************************************************
 *                   MISC FUNCTIONS
 */

Prompt(t, yesNoCancel=true)
{
    if yesNoCancel
    {
        D("Prompting user (y/n/c): " t)
        MsgBox 3,, %t%
    }
    else
    {
        D("Prompting user (o/c): " t)
        MsgBox 1,, %t%
    }
    ifMsgBox Cancel
    {
        D("- User cancelled")
        ExitApp 1
    }
    ifMsgBox Yes
    {
        D("yes")
        return true
    }
    else
    {
        D("no")
        return false
    }
}

D(s)
{
    FileAppend %s%`n, *
    FileAppend %s%`n, %A_ScriptDir%\release.log
}

ExitError(s)
{
    D("- " s)
    MsgBox 16,, % s
    ExitApp 1
}