;
; Window Spy
;

; #NoTrayIcon
#SingleInstance Ignore
SetWorkingDir A_ScriptDir
; SetBatchLines -1
CoordMode "Pixel", "Screen"

global textList := Map(
    "NotFrozen", "(Hold Ctrl or Shift to suspend updates)",
    "Frozen", "(Updates suspended)",
    "MouseCtrl", "Control Under Mouse Position",
    "FocusCtrl", "Focused Control",
)

createWindow() {
    window := Gui.New("+AlwaysOnTop +Resize +DPIScale MinSize")
    window.Add("Text",, "Window Title, Class and Process:")
    window.Add("Checkbox", "yp xp+200 w120 Right vFollowMouse", "Follow Mouse")
    window.Add("Edit", "xm w320 r4 ReadOnly -Wrap vTitle")
    window.Add("Text",, "Mouse Position:")
    window.Add("Edit", "w320 r4 ReadOnly -Wrap vMousePos")
    window.Add("Text", "w320 vCtrlLabel", textList["FocusCtrl"] ":")
    window.Add("Edit", "w320 r4 ReadOnly -Wrap vCtrl")
    window.Add("Text",, "Active Window Position:")
    window.Add("Edit", "w320 r2 ReadOnly -Wrap vPos")
    window.Add("Text",, "Status Bar Text:")
    window.Add("Edit", "w320 r2 ReadOnly -Wrap vSBText")
    window.Add("Checkbox", "vIsSlow", "Slow TitleMatchMode")
    window.Add("Text",, "Visible Text:")
    window.Add("Edit", "w320 r2 ReadOnly -Wrap vVisText")
    window.Add("Text",, "All Text:")
    window.Add("Edit", "w320 r2 ReadOnly -Wrap vAllText")
    window.Add("Text", "w320 r1 vFreeze", textList["NotFrozen"])
    return window
}

global window := createWindow()
window.OnEvent("Size", "onWindowSize")
window.OnEvent("Close", "onWindowClose")
window.Show("NoActivate")
global windowUpdate := Func("Update").Bind(window)
SetTimer(windowUpdate, 250)

onWindowSize(window, minMax, width, height) {
    global windowUpdate

    if (minMax == -1) {
        SetTimer(windowUpdate, 0)
    } else {
        SetTimer(windowUpdate)
    }

    window["Title"].GetPos(x,,)
    list := "Title,MousePos,Ctrl,Pos,SBText,VisText,AllText,Freeze"
    Loop Parse, list, ","
        window[A_LoopField].Move(,,width - x*2)
}

onWindowClose(window) {
    ExitApp
}

Update(window) {
    local curCtrl
    global textList
    CoordMode("Mouse", "Screen")
    MouseGetPos(msX, msY, msWin, msCtrl)
    if window["FollowMouse"].Value {
        curWin := msWin
        curCtrl := msCtrl
        WinExist("ahk_id " curWin)
    } else {
        curWin := WinExist("A")
        if (!curWin) {
            return
        }
        curCtrl := ControlGetFocus()
    }
    t1 := WinGetTitle()
    t2 := WinGetClass()

    ; Our Gui || Alt-tab
    if (curWin = window.Hwnd || t2 = "MultitaskingViewFrame") {
        UpdateText("Freeze", textList["Frozen"])
        return
    }
    UpdateText("Freeze", textList["NotFrozen"])
    t3 := WinGetProcessName()
    t4 := WinGetPID()
    UpdateText("Title", t1 "`nahk_class " t2 "`nahk_exe " t3 "`nahk_pid " t4)
    CoordMode "Mouse", "Window"
    MouseGetPos mrX, mrY
    CoordMode "Mouse", "Client"
    MouseGetPos mcX, mcY
    mClr := PixelGetColor(msX, msY)
    mClr := SubStr(mClr, 3)
    UpdateText(
        "MousePos", 
        "Screen:`t" msX ", " msY "`n"
        "Window:`t" mrX ", " mrY "`n"
        "Client:`t" mcX ", " mcY "`n"
        "Color:`t" mClr " (Red=0x" SubStr(mClr, 1, 2) " Green=0x" SubStr(mClr, 3, 2) " Blue=0x" SubStr(mClr, 5) ")"
    )
    UpdateText(
        "CtrlLabel", 
        (window["FollowMouse"].Value ? textList["MouseCtrl"] : textList["FocusCtrl"]) ":"
    )
    if (curCtrl) {
        ctrlTxt := ControlGetText(curCtrl)
        cText := "ClassNN:`t" curCtrl "`nText:`t" textMangle(ctrlTxt)
        ControlGetPos cX, cY, cW, cH, curCtrl
        cText .= "`n`tx: " cX "`ty: " cY "`tw: " cW "`th: " cH
        WinToClient(curWin, cX, cY)
        curCtrlHwnd := ControlGetHwnd(curCtrl)
        GetClientSize(curCtrlHwnd, cW, cH)
        cText .= "`nClient:`tx: " cX "`ty: " cY "`tw: " cW "`th: " cH
    } else {
        cText := ""
    }
    UpdateText("Ctrl", cText)
    WinGetPos(wX, wY, wW, wH)
    GetClientSize(curWin, wcW, wcH)
    UpdateText("Pos", "`tx: " wX "`ty: " wY "`tw: " wW "`th: " wH "`nClient:`tx: 0`ty: 0`tw: " wcW "`th: " wcH)
    sbTxt := ""
    Loop {
        try {
            sbTxt .= "[" A_Index "]`t" textMangle(StatusBarGetText(A_Index)) "`n"
        } catch e {
            break
        }
    }
    sbTxt := SubStr(sbTxt, 1, -1)
    UpdateText("SBText", sbTxt)
    if window["IsSlow"].Value {
        DetectHiddenText(False)
        ovVisText := WinGetText()
        DetectHiddenText(True)
        ovAllText := WinGetText()
    } else {
        ovVisText := WinGetTextFast(false)
        ovAllText := WinGetTextFast(true)
    }
    UpdateText("VisText", ovVisText)
    UpdateText("AllText", ovAllText)
}

WinGetTextFast(detect_hidden) {
    ; WinGetText ALWAYS uses the "fast" mode - TitleMatchMode only affects
    ; WinText/ExcludeText parameters.  In Slow mode, GetWindowText() is used
    ; to retrieve the text of each control.
    controls := WinGetControlsHwnd()
    static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.
    buf := BufferAlloc(WINDOW_TEXT_SIZE * 2)
    local text := ""
    Loop Parse controls `n
    {
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", A_LoopField)
            continue
        if !DllCall("GetWindowText", "ptr", A_LoopField, "str", buf, "int", WINDOW_TEXT_SIZE)
            continue
        text .= buf "`r`n"
    }
    return text
}

UpdateText(ControlID, NewText) {
    ; Unlike using a pure GuiControl, this function causes the text of the
    ; controls to be updated only when the text has changed, preventing periodic
    ; flickering (especially on older systems).
    static OldText := Map()
    global window
    if (!OldText.Has(ControlID) || OldText[ControlID] != NewText) {
        OldText[ControlID] := NewText
        window[ControlID].Value := NewText
    }
}

GetClientSize(hWnd, ByRef w := "", ByRef h := "") {
    rect := BufferAlloc(16)
    DllCall("GetClientRect", "ptr", hWnd, "ptr", rect)
    w := NumGet(rect, 8, "int")
    h := NumGet(rect, 12, "int")
}

WinToClient(hWnd, ByRef x, ByRef y) {
    WinGetPos(wX, wY,,, "ahk_id " hWnd)
    if (IsInteger(wX)) {
        x += wX
    }
    if (IsInteger(wY)) {
        y += wY
    }
    pt := BufferAlloc(8)
    NumPut("int", x, "int", y, pt)
    if !DllCall("ScreenToClient", "ptr", hWnd, "ptr", pt)
        return false
    x := NumGet(pt, 0, "int")
    y := NumGet(pt, 4, "int")
    return true
}

textMangle(x) {
    elli := false
    pos := InStr(x, "`n")
    if (pos) {
        x := SubStr(x, 1, pos-1)
        elli := true
    }
    if (StrLen(x) > 40) {
        x := SubStr(x, 1, 40)
        elli := true
    }
    if (elli) 
        x .= " (...)"
    return x
}

~*Ctrl::
~*Shift:: {
    global windowUpdate
    SetTimer(windowUpdate, 0)
    UpdateText("Freeze", textList["Frozen"])
}

~*Ctrl up::
~*Shift up:: {
    global windowUpdate
    SetTimer(windowUpdate)
}
