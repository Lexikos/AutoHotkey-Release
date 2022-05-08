
PrepareDocsBegin(last_tag, version)
{
    global TempDir, DocDir, Editor, ChangeLogFile
    
    global PrepareDocsLog := TempDir "\ChangeLogEntry.htm"
    global PrepareDocsVersion := version
    global PrepareDocsEditor := 0
    
    if (ChangeLogFile = "")
    {
        D("- No change log to update")
        return
    }
    if !FileExist(ChangeLogFile)
    {
        Prompt("Change log file does not exist, so will not be updated:`n" ChangeLogFile, 0)
        return
    }
    
    D("! Edit change log entry")
    
    ; Get all commit messages since the last tag.
    log := git("log --format=format:%s%n%n%b --reverse " last_tag "..HEAD")

    ; Unwrap. | Remove empty lines.
    log := RegExReplace(log, "`n (?= \S)|`n(?=`n|$)")
    
    ; Encode < > &
    log := StrReplace(StrReplace(StrReplace(log, "<", "&lt;"), ">", "&gt;"), "&", "&amp;")
    
    ; `code`
    log := RegExReplace(log, "``(.*?)``", "<code>$1</code>")

    ; Paragraph formatting.
    log := RegExReplace(log, "`n).+", "<p>$0</p>")
    
    ; Header for previewing file.
    header := "<head>"
        . "<base href=""file:///" DocDir "/"" target=""_blank"">"
        . "<link href=""file:///" DocDir "/docs/static/theme.css"" rel=""stylesheet"" type=""text/css"" />"
        . "</head>"
    
    ; Add header and heading.
    FormatTime, date,, MMMM d, yyyy
    log := "<!--temp-->" header "<!--/temp-->`n`n"
        . "<h2 id=""v" version """>" version " - " date "</h2>`n"
        . log "`n"
    
    ; Run editor for confirmation/editing.
    FileOpen(PrepareDocsLog, "w`n", "UTF-8").Write(log)
    Run, %Editor% "%PrepareDocsLog%",,, PrepareDocsEditor
}

_PrepareDocsEndEdit()
{
    global ChangeLogFile
    global PrepareDocsEditor, PrepareDocsLog
    
    Process, Exist, %PrepareDocsEditor%
    if ErrorLevel
    {
        D("! Waiting for editor to close")
        ; Wait until user finishes editing the entry.
        Process, WaitClose, %PrepareDocsEditor%
    }
    
    FileRead, log, %PrepareDocsLog%
    
    ; Remove preview header and leading/trailing whitespace.
    log := Trim(RegExReplace(log, "s)<!--temp.*?/temp-->"), " `t`r`n")
    
    if (log = "")
    {
        Prompt("Change log entry is blank. Continue without updating change log?", 0)
        return
    }
    
    D("! Updating change log")
    
    ; Insert log entry into docs.
    FileRead, html, %ChangeLogFile%
    html := RegExReplace(html, "(?<=<!--new revisions go here-->)"
                            , "`n" log "`n", replaced, 1)
    if replaced
        FileOpen(ChangeLogFile, "w`n").Write(html)
}

PrepareDocsEnd()
{
    global DocDir
    global PrepareDocsEditor, PrepareDocsVersion
    
    if (PrepareDocsEditor != 0)
        _PrepareDocsEndEdit()
    
    version := PrepareDocsVersion
    
    ; Update version number in docs.
    FileRead, html, % DocDir "\docs\AutoHotkey.htm"
    html := RegExReplace(html, "(?<=<!--ver-->).*(?=<!--/ver-->)", version, replaced, 1)
    if replaced
        FileOpen(DocDir "\docs\AutoHotkey.htm", "w").Write(html)
    else
        Prompt("AutoHotkey.htm not updated!", 0)
    
    PrepareSearchIndex()
    
    git("commit -a -m v" version, DocDir)
    if ErrorLevel
        Prompt("Failed to commit docs!", 0)
    git("push", DocDir)
    
    if FileExist(DocDir "\..\up")
    {
        D("! Updating GitHub pages")
        gitsh("../up", DocDir)  ; This is a shell script which updates lexikos.github.io.
    }
}


PrepareDocsCHM()
{
    global InstDir, DocDir
    
    D("! Updating AutoHotkey.chm")
    Loop {
        FileDelete %DocDir%\AutoHotkey.chm
        if !FileExist(DocDir "\AutoHotkey.chm")
            break
        D("- AutoHotkey.chm locked; prompting user")
        MsgBox 0x35,, AutoHotkey.chm appears to be locked.  Ensure it is closed`, then click OK.
        IfMsgBox Cancel
        {
            D("- User cancelled")
            ExitApp 1
        }
    }
    RunWait "%A_AhkPath%\..\AutoHotkeyU32.exe" compile_chm.ahk, %DocDir%
    FileCopy %DocDir%\AutoHotkey.chm, %InstDir%\include, 1
}


PrepareSearchIndex(commit:=false)
{
    global DocDir
    
    ; Update search index.
    try
    {
        RunWait "%A_AhkPath%\..\v2-alpha\AutoHotkey32.exe" "%DocDir%\docs\static\source\build_search.ahk"
        if ErrorLevel
            throw Exception("AutoHotkey exited with code " ErrorLevel)
        if commit
            git("commit docs/static/source/data_search.js -m ""Update search index""", DocDir)
    }
    catch e
    {
        Prompt("Failed to build search index`n`n" e.message, 0)
    }
}