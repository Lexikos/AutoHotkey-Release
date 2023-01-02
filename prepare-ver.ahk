
PrepareNewVersion()
{
    global ctag, cid, version, branch

    if RegExMatch(ctag, "^v(.*\D)(\d+)$", ver)
        version := format("{}{:0" StrLen(ver2) "}", ver1, ver2 + 1)
    else
        version := SubStr(ctag, 2)

    PrepareVersion()
}

PrepareEdgeVersion()
{
    global cdesc, version

    if RegExMatch(cdesc, "^v(\d+\.\d+\.)(?:(\d+)?\.\d+)?-\d+-(.*)", ver)
        version := format("{}{:02}-TEST+{}", ver1, (ver2="" ? 0 : ver2) + 1, ver3)
    else
        version := SubStr(cdesc, 2)

    PrepareVersion()
}

PrepareVersion()
{
    global

    InputBox version,, Enter new version number.,,, 120,,,,, %version%
    if ErrorLevel
        ExitApp

    ; 1.1.11.01 -> 1,1,11,1  --  2.0-a099 -> 2,0
    if RegExMatch(version, "^(\d+\.){0,3}\d+", version_n)
        version_n := RegExReplace(version_n, "\.(0(?=\d))?", ",")
    else
        version_n := 0
    
    EnvSet RawAhkVersion, % version
    EnvSet AhkVersionN, % version_n

    local ahkversion_h
    FileReadLine ahkversion_h, source\ahkversion.h, 1
    if !(modified_ahkversion_h := (ahkversion_h ~= "^#define AHK_VERSION "))
    {
        if !FileExist("source\ahkversion.cpp")
            Prompt("ahkversion.h content not recognized and there is no ahkversion.cpp; continue anyway?")
    }
    else
    {
        ; Update ahkversion.h ...
        FileDelete, source\ahkversion.h
        FileAppend,
        (LTrim
        #define AHK_VERSION "%version%"
        #define AHK_VERSION_N %version_n%`n
        ), source\ahkversion.h

        OnExit(Func("PrepareVer_OnExit"))
    }
}

PrepareVer_OnExit()
{
    ; Restore ahkversion.h if it has not been committed
    git("checkout source/ahkversion.h")
}