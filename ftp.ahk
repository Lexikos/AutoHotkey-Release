
FtpQPut(src, dst:="")
{
    global
    if (dst = "")
        dst := StrReplace(src, "\", "/")
    FileAppend, put "%src%" "%FtpPrefix%%dst%"`n, %FtpScript%
}

FtpExecute()
{
    global
    RunWait "%PSFTP%" -bc -be -b "%FtpScript%",, UseErrorLevel
    FileMove %FtpScript%, %OutDir%\ftp-ran-%A_Now%.txt ; Rename in case of re-release
}