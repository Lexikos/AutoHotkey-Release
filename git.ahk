git(cmd, dir="") {
    return gitout("git " cmd, dir)
}
gitout(cmd, dir:="") {
    tf = %A_Temp%\gitout%A_ScriptHwnd%.txt
    try {
        RunWait cmd.exe /v:on /c "%cmd% >"%tf%" & exit !ErrorLevel!", %dir%
        exit_code := ErrorLevel
        FileRead t, *P65001 *t %tf%
    } finally
        FileDelete %tf%
    ErrorLevel := exit_code
    return RTrim(t, "`n")
}
gitsh(cmd, dir:="") {
    return gitout("""" gitdir() "\bin\sh"" -l -c " cmd, dir)
}
gitdir() {
    static dir := ""
    if (dir != "")
        return dir
    pf := A_ProgramFiles
    if FileExist(pf "\Git")
        return dir := pf "\Git"
    EnvGet pf, ProgramW6432
    if FileExist(pf "\Git")
        return dir := pf "\Git"
    EnvGet pf, ProgramFiles(x86)
    if FileExist(pf "\Git")
        return dir := pf "\Git"
    throw Exception("Git not found!")
}