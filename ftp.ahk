FtpQCD(dir)
{
    global
    if SubStr(dir,1,1) != "/"
        throw Exception("Don't use a relative path", -1, dir)
    FileAppend, cd %FtpRoot%%dir%`n, %FtpScript%
}

FtpQLCD(dir)
{
    global
    FileAppend, lcd "%dir%"`n, %FtpScript%
}

FtpQPut(src, dst:="")
{
    global
    if (dst = "")
        dst := StrReplace(src, "\", "/")
    FileAppend, put "%src%" %dst%`n, %FtpScript%
}

FtpExecute()
{
    global
    ; RunWait "%PSFTP%" -bc -be -b "%FtpScript%",, UseErrorLevel
    ; FileMove %FtpScript%, %OutDir%\ftp-ran-%A_Now%.txt ; Rename in case of re-release
}