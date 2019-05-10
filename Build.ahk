Build(builds)
{
    global branch
    build_args := branch ? branch : "unknown"
    Loop % builds._MaxIndex()
    {
        build := builds[A_Index], cfg := build.cfg, platform := build.platform
        build_args .= " " build.cfg " " build.platform
    }
    
    RunWait "%A_ScriptDir%\build.cmd" %build_args%
    all_good := !ErrorLevel
    
    ; Delete these so that the next VC++ 2013 build won't fail.
    FileDelete temp\x64\Release\AutoHotkey.pch
    FileDelete temp\x64\Self-contained\AutoHotkeySC.pch
    
    return all_good
}
