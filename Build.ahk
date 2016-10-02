Build(builds)
{
    ; Retrieve environment for command-line builds:
    FileCreateDir temp
    RunWait cmd.exe /c ""`%VS140COMNTOOLS`%..\..\VC\vcvarsall.bat">NUL && SET>temp\build.env"

    ; Copy to current environment:
    Loop, Read, temp\build.env
        if RegExMatch(A_LoopReadLine, "(.*?)=\K.*", v)
            EnvSet, %v1%, %v%
    
    build_errors := 0
    
    Loop % builds._MaxIndex()
    {
        build := builds[A_Index], cfg := build.cfg, platform := build.platform
        ; Rebuild this configuration.  Do FULL REBUILD since the post-build
        ; scripts might misbehave if MSBuild leaves the old binaries in place.
        D("! Building " cfg "|" platform)
        RunWait MSBuild AutoHotkeyx.sln /t:Rebuild /p:Configuration=%cfg% /p:Platform=%platform%
        if ErrorLevel
            build_errors += 1
        FileAppend, `n`n, CON
    }
    
    ; Delete these so that the next VC++ 2013 build won't fail.
    FileDelete temp\x64\Release\AutoHotkey.pch
    FileDelete temp\x64\Self-contained\AutoHotkeySC.pch
    
    return build_errors
}