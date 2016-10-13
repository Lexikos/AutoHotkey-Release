
PrepareGitHubBegin()
{
    global TempDir, Editor
    global VersionDocsLog
    if (VersionDocsLog = "")
        VersionDocsLog = %TempDir%\ChangeLogEntry.htm
    
    global GitHubLog, GitHubEditor
    GitHubLog = %TempDir%\GitHubEntry.htm
    
    ; Tidy up changelog entry for use by GitHub Release
    FileRead, log, %VersionDocsLog%
    log := RegExReplace(log, "href=""\K(?!\w+:|#)", "https://autohotkey.com/docs/")
    log := RegExReplace(log, "<h2.*</h2>\R")
    log := RegExReplace(log, "<p>(.*?)</p>", "$1")
    FileOpen(GitHubLog, "w").Write(log)
    
    ; Open for review
    Run, %Editor% "%GitHubLog%",,, GitHubEditor
}

PrepareGitHubEnd()
{
    global GitHubLog, GitHubEditor
    
    Process, Exist, %GitHubEditor%
    if ErrorLevel
    {
        D("! waiting for editor to close")
        ; Wait until user finishes editing the changelist.
        Process, WaitClose, %GitHubEditor%
    }
    
    FileGetSize size, %GitHubLog%
    if !size
        Prompt("No log message for GitHub release!", 0)
}