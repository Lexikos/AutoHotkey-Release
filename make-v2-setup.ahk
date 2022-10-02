#Requires AutoHotkey v2.0-beta.7

SetWorkingDir "include-v2"

fi := FileOpen("~FileInstall.ahk", "w")
dirs := Map(), dirs.CaseSense := "Off"
Loop Read A_ScriptDir "\zip-files-alpha.txt" {
    ; FileAppend A_LoopReadLine "`n", "*"
    Loop Files A_LoopReadLine, "F"
        AddFile
    else Loop Files A_LoopReadLine "\*", "FR"
        AddFile
}
AddFile() {
    ; FileAppend '+ ' A_LoopFilePath "`n", "*"
    if A_LoopFileDir != "" && !dirs.Has(A_LoopFileDir) {
        fi.WriteLine(Format('DirCreate "{}"', A_LoopFileDir))
        dirs[A_LoopFileDir] := true
    }
    fi.WriteLine(Format('FileInstall "{1}", "{1}", 1', A_LoopFilePath))
}
fi.Close()

if !A_Args.Length
    RunWait '*compile AutoHotkey_setup.ahk'

