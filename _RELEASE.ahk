
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


ProjDir := SelectProjDir()
InstDir = %A_ScriptDir%\installer
WebDir = %A_ScriptDir%\files\web  ; Location of index.htm
Ahk2ExeDir = %A_ScriptDir%\..\Ahk2Exe
Ahk2ExeCmd = "%A_AhkPath%" "%Ahk2ExeDir%\Ahk2Exe.ahk"

SelectProjDir() {
    local
    try Menu ProjDirs, DeleteAll
    SetWorkingDir ..
    count := 0
    Loop Files, *, D
        if FileExist(A_LoopFilePath "\AutoHotkeyx.sln") {
            Menu ProjDirs, Add, %A_LoopFilePath%, SelectProjDirLbl
            last := A_LoopFilePath
            ++count
        }
    switch count {
    case 0:
        MsgBox AutoHotkeyx.sln not found.
        ExitApp
    case 1:
        return last
    }
    ProjDir := ""
    Menu ProjDirs, Show
    if (ProjDir = "") {
        MsgBox Project directory not selected. Exiting.
        ExitApp
    }
    return A_WorkingDir "\" ProjDir
    SelectProjDirLbl:
    ProjDir := A_ThisMenuItem
    return
}


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

on_test_branch := !(branch ~= "^(v[\d\.]+|alpha)$")

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
if ccnt
    version .= "+" cid


/*************************************************************
 *                  MORE CONFIGURATION
 */

if (branch = "v1.1")
{
    DocDir = %A_ScriptDir%\..\Docs\v1
    ChangeLogFile = %DocDir%\docs\AHKL_ChangeLog.htm
}
else if (branch = "v2.0")
{
    DocDir = %A_ScriptDir%\..\Docs\v2
    ChangeLogFile = %DocDir%\docs\ChangeLog.htm
}
else if (branch = "alpha")
{
    DocDir = %A_ScriptDir%\..\Docs\alpha
    ChangeLogFile = %DocDir%\docs\ChangeLog.htm
}
else
    Prompt("No documentation directory is set for branch """ branch """", 0)

if (version >= "2.")
    InstDataDir = %A_ScriptDir%\include-v2
else
    InstDataDir = %InstDir%\include  ; May be overridden below


/*************************************************************
 *                      WHAT TO DO?
 */

has_docs := DocDir != "" && InStr(FileExist(DocDir), "D")
has_ahk2exe := Ahk2ExeDir != "" && InStr(FileExist(Ahk2ExeDir), "D")
has_installer := has_docs && has_ahk2exe
has_github := gh_owner && gh_repo && gh_token && (A_PtrSize=4 || ActiveScript)

committing := !on_test_branch && (committing || committing="" && Prompt("Bump version and commit/tag?"))
building := committing || Prompt("Build?")
update_helpfile := has_docs && (committing || Prompt("Update help file?"))
update_ahk2exe := has_ahk2exe && version < "2." && (building || Prompt("Update Ahk2Exe?"))
update_installer := has_installer && (building || update_helpfile || update_ahk2exe || Prompt("Update installer?"))
update_zip := SevenZip && (building || update_helpfile || update_ahk2exe || Prompt("Update zip?"))
gh_release := has_github && branch ~= "^v" && (committing || Prompt("GitHub release?"))
pushing := on_test_branch ? Prompt("Push test branch?") : committing


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
        {cfg: "Release"              , platform:   "x64"}
    )]
    if (version < "2.")
    {
        builds.push(
        (Join,
            {cfg: "Release(mbcs)"        , platform: "Win32"}
            {cfg: "Self-contained"       , platform: "Win32"}
            {cfg: "Self-contained(mbcs)" , platform: "Win32"}
            {cfg: "Self-contained"       , platform:   "x64"}
        ))
    }
    if !Build(builds)
        ExitError(build_errors " build error(s)")
    
    ; Update installer/zip includes
    if (version < "2.")
    {
        Loop Parse, % "AutoHotkeyU32.exe,AutoHotkeyA32.exe,AutoHotkeyU64.exe", `,
            FileCopyAssert("bin\" A_LoopField, InstDataDir "\" A_LoopField)
        Loop Parse, % "Unicode 32-bit.bin,ANSI 32-bit.bin,Unicode 64-bit.bin", `,
            FileCopyAssert("bin\" A_LoopField, InstDataDir "\Compiler\" A_LoopField)
    }
    else
    {
        FileCopyAssert("bin\AutoHotkey32.exe", InstDataDir "\AutoHotkey32.exe")
        FileCopyAssert("bin\AutoHotkey64.exe", InstDataDir "\AutoHotkey64.exe")
    }
}


/*************************************************************
 *                  COMMIT AND TAG
 */

if committing
{
    if modified_ahkversion_h
    {
        D("! Committing v" version)
        git("commit -m ""v" version """ --only source/ahkversion.h")
    }

    if !on_test_branch
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
    if (!committing)
        PrepareSearchIndex(true)
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
        /out "%InstDataDir%\Compiler\Ahk2Exe.exe"
        /base "%InstDataDir%\AutoHotkeyU32.exe"
        /icon "%A_ScriptDir%\ahk2exe.ico"
        , %Ahk2ExeDir%
}


/*************************************************************
 *                UPDATE UX
 */

if FileExist(InstDataDir "\UX")
{
    D("! Pulling UX")
    git("pull --ff-only", InstDataDir "\UX")
    if ErrorLevel
        Prompt("Error updating UX; check log", 0)
}


/*************************************************************
 *                UPDATE INSTALLER
 */

InstName := "AutoHotkey_" version "_setup.exe"
InstPath := OutDir "\" InstName
if update_installer
{
    D("! Updating installer")
    if VerCompare(version, ">=2-")
    {
        RunWait "%InstDataDir%\AutoHotkey32.exe" "%A_ScriptDir%\make-v2-setup.ahk" no-compile
        RunWait %Ahk2ExeCmd%
            /in "%InstDataDir%\AutoHotkey_setup.ahk"
            /out "%InstPath%"
            /base "%InstDataDir%\AutoHotkey32.exe"
            /compress 2
            , %Ahk2ExeDir%
    }
    else
        RunWait "%InstDir%\tools\UPDATE.bat" "%InstPath%"
    if ErrorLevel
        Prompt("Failed to update installer!", 0)
    else
    {
        InstHash := MakeSha256(InstPath)
        FtpQPut(InstPath, RemoteDownloadDir "/" InstName)
        FtpQPut(InstPath ".sha256", RemoteDownloadDir "/" InstName ".sha256")
    }
}


/*************************************************************
 *                  UPDATE ZIP FILE
 */

ZipName := "AutoHotkey_" version ".zip"
ZipPath := OutDir "\" ZipName
ZipList := A_ScriptDir "\zip-files-" branch ".txt"
if update_zip && (FileExist(ZipList) || Prompt("zip-files-" branch ".txt not found", 0) && FileExist(ZipList))
{
    if !update_installer && branch = "master"
        FileCopy %InstDir%\source\WindowSpy.v1.ahk, %InstDataDir%\WindowSpy.ahk, 1
    
    D("! Zipping")
    zip_list := """@" A_ScriptDir "\zip-files-" branch ".txt"""
    FileDelete %ZipPath%
    RunWait "%SevenZip%" a -tzip "%ZipPath%" %zip_list%, %InstDataDir%, UseErrorLevel
    if ErrorLevel
        Prompt("Zipping failed (exit code " ErrorLevel ")", 0)
    else
    {
        ZipHash := MakeSha256(ZipPath)
        FtpQPut(ZipPath, RemoteDownloadDir "/" ZipName)
        FtpQPut(ZipPath ".sha256", RemoteDownloadDir "/" ZipName ".sha256")
    }
}


/*************************************************************
 *                SYNC WITH GITHUB.COM
 */

if pushing
{
    ; Push all updates to remote repo.
    D("! Pushing")
    if on_test_branch
        git("push -f origin " branch ":" branch)
    else
        git("push")
    if tagged
        git("push origin tag v" RegExReplace(version, "-\Q" cid "\E$"))
}

if gh_release
{
    PrepareGitHubEnd()
    
    FileRead log, %GitHubLog%
    
    ; Remove header used for previewing (see prepare-docs.ahk).
    log := Trim(RegExReplace(log, "s)<!--temp.*?/temp-->"), " `t`r`n")
    
    ; Add SHA256 hash
    log .= "`n`n<details><summary>SHA256 hash</summary>`n"
        . "<code>" InstHash "</code> " InstName "`n"
        . "<code>" ZipHash "</code> " ZipName "`n"
        . "</details>"
    
    try
    {
        ; Create a new GitHub Release and upload the installer
        context := new GitHub.Context(gh_owner, gh_repo, gh_token)
        release := new GitHub.Release(context, {tag_name: "v" version, body: log})
        release.AddAsset(InstName, InstPath)
        release.AddAsset(ZipName, ZipPath)
    }
    catch error
    {
        D("- GitHub release error : " error.message " (" error.extra ")")
    }
}


/*************************************************************
 *                SYNC WITH AUTOHOTKEY.COM
 */

if committing && !on_test_branch
{
    FileOpen(TempDir "\version.txt", "w").Write(version)
    FtpQPut(TempDir "\version.txt", RemoteDownloadDir "/version.txt")
    
    RegExUpdate(WebDir "\versions.txt"
        , "/download/versions.txt"
        , "\Q" SubStr(version, 1, 3) "\E.*"
        , version)
    
    RegExUpdate(WebDir "\index.htm"
        , "/download/index.htm"
        , "(?<=<span class=""curver"">)\Q" SubStr(version, 1, 3) "\E.*?(?=</span>)"
        , version)
}

RegExUpdate(local_file, remote_file, needle, replacement)
{
    if !FileExist(local_file)
        return
    FileRead file_text, %local_file%
    file_text := RegExReplace(file_text, needle, replacement, replaced)
    if replaced
    {
        FileOpen(local_file, "w").Write(file_text)
        FtpQPut(local_file, remote_file)
    }
    else Prompt(local_file " not updated!", 0)
}

D("! Executing pre-FTP #include (if any)")
#include *i pre-ftp.ahk

D("! Executing FTP script")
FtpExecute()


D("`n")
Sleep 1000
ExitApp


/*************************************************************
 *                   MISC FUNCTIONS
 */

#include HashFile.ahk
MakeSha256(path)
{
    hash := HashFile(path, 4)
    FileOpen(path ".sha256", "w").Write(hash)
    SplitPath path, name
    ; Print the hashes last for easy copying to the forum
    OnExit(Func("D").Bind("[c]" hash "[/c] " name))
    return hash
}

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
    ifMsgBox OK
        return true
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

FileCopyAssert(source, dest) {
    try
        FileCopy % source, % dest, 1
    catch
        Prompt("FileCopy failed`nsource: " source "`ndest: " dest "`nerror: " A_LastError, false)
}