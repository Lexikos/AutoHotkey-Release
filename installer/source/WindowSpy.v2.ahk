;
; Window Spy
;

; #NoTrayIcon
#SingleInstance Ignore
SetWorkingDir A_ScriptDir
; SetBatchLines -1
CoordMode "Pixel", "Screen"
; Ignore error, sometimes update() will issue window not found error
; Comment this out when debug
OnError((*) => true)

WinGetTextFast(detect_hidden) {
    ; WinGetText ALWAYS uses the "fast" mode - TitleMatchMode only affects
    ; WinText/ExcludeText parameters.  In Slow mode, GetWindowText() is used
    ; to retrieve the text of each control.
    controls := WinGetControlsHwnd()
    static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.
    buf := BufferAlloc(WINDOW_TEXT_SIZE * 2) ; *2 for Unicode
    local text := ""
    loop parse controls `n
    {
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", A_LoopField)
            continue
        if !DllCall("GetWindowText", "ptr", A_LoopField, "str", buf, "int", WINDOW_TEXT_SIZE)
            continue
        text .= buf "`n"
    }
    return text
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

class MainWindow {
    updateClosure := ""
    oldText := Map()
    autoUpdateEnabled := false

    textList := Map(
        "NotFrozen", "Updating...",
        "Frozen", "Update suspended",
        "MouseCtrl", "Control Under Mouse Position",
        "FocusCtrl", "Focused Control",
    )

    __new() {
        this.gui := Gui.new("+AlwaysOnTop +Resize +DPIScale MinSize")
        this.gui.add("Text", "xm", "Window Title, Class and Process:")
        this.gui.add("Edit", "xm w320 r4 ReadOnly -Wrap vTitle")
        this.gui.add("Text",, "Mouse Position:")
        this.gui.add("Edit", "w320 r4 ReadOnly -Wrap vMousePos")
        this.gui.add("Text", "w320 vCtrlLabel", this.textList["FocusCtrl"] ":")
        this.gui.add("Edit", "w320 r4 ReadOnly -Wrap vCtrl")
        this.gui.add("Text",, "Active Window Position:")
        this.gui.add("Edit", "w320 r2 ReadOnly -Wrap vPos")
        this.gui.add("Text",, "Status Bar Text:")
        this.gui.add("Edit", "w320 r2 ReadOnly -Wrap vSBText")
        this.gui.add("Checkbox", "vIsSlow", "Slow TitleMatchMode")
        this.gui.add("Text",, "Visible Text:")
        this.gui.add("Edit", "w320 r2 ReadOnly -Wrap vVisText")
        this.gui.add("Text",, "All Text:")
        this.gui.add("Edit", "w320 r2 ReadOnly -Wrap vAllText")

        onOptionUpdateChange(*) {
            this.updateAutoUpdateTimer()
        }

        onOptionAlwaysOnTopChanged(checkbox, *) {
            this.gui.opt(
                (checkbox.value ? "+" : "-")
                "AlwaysOnTop"
            )
        }

        this.gui.add("GroupBox", "w320 r3 vOptions", "Options")
        this.gui.add("Checkbox", "xm+8 yp+16 vAlwaysOnTop checked", "Always on top")
            .onEvent("Click", Func("onOptionAlwaysOnTopChanged"))
        this.gui.add("Text", "xm+8 y+m", "Update when Ctrl key is")
        this.gui.add("Radio", "yp vUpdateWhenCtrlUp checked", "up")
            .onEvent("Click", Func("onOptionUpdateChange"))
        this.gui.add("Radio", "yp vUpdateWhenCtrlDown", "down")
            .onEvent("Click", Func("onOptionUpdateChange"))
        this.gui.add("Text", "xm+8 y+m", "Get info of")
        this.gui.add("Radio", "yp vGetActive checked", "Active window")
        this.gui.add("Radio", "yp vGetCursor", "Window on cursor")

        this.statusBar := this.gui.add("StatusBar",, this.textList["NotFrozen"])

        onSize(window, minMax, width, height) {
            if (minMax == -1) {
                this.autoUpdate(false)
            } else {
                this.autoUpdate(true)
            }

            list := "Title,MousePos,Ctrl,Pos,SBText,VisText,AllText,Options"
            loop parse, list, ","
                window[A_LoopField].move(,,width - window.marginX*2)
        }

        onClose(window) {
            ExitApp
        }

        ; Event handler need to use Func() to create closure
        this.gui.onEvent("size", Func("onSize"))
        this.gui.onEvent("close", Func("onClose"))

        ; Create updateClosure for timer
        this.updateClosure := () => this.update()
    }

    setText(controlID, text) {
        ; Unlike using a pure GuiControl, this function causes the text of the
        ; controls to be updated only when the text has changed, preventing periodic
        ; flickering (especially on older systems).
        if (!this.oldText.has(controlID) || this.oldText[controlID] != text) {
            this.oldText[controlID] := text
            this.gui[controlID].value := text
        }
    }

    update() {
        local curCtrl
        CoordMode("Mouse", "Screen")
        MouseGetPos(msX, msY, msWin, msCtrl)
        if this.gui["GetCursor"].value {
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
        if (curWin = this.gui.Hwnd || t2 = "MultitaskingViewFrame") {
            this.statusBar.setText(this.textList["Frozen"])
            return
        }
        this.statusBar.setText(this.textList["NotFrozen"])
        t3 := WinGetProcessName()
        t4 := WinGetPID()
        this.setText("Title", t1 "`nahk_class " t2 "`nahk_exe " t3 "`nahk_pid " t4)
        CoordMode "Mouse", "Window"
        MouseGetPos mrX, mrY
        CoordMode "Mouse", "Client"
        MouseGetPos mcX, mcY
        mClr := PixelGetColor(msX, msY)
        mClr := SubStr(mClr, 3)
        this.setText(
            "MousePos", 
            "Screen:`t" msX ", " msY "`n"
            "Window:`t" mrX ", " mrY "`n"
            "Client:`t" mcX ", " mcY "`n"
            "Color:`t" mClr " (Red=0x" SubStr(mClr, 1, 2) " Green=0x" SubStr(mClr, 3, 2) " Blue=0x" SubStr(mClr, 5) ")"
        )
        this.setText(
            "CtrlLabel", 
            (this.gui["GetCursor"].value ? this.textList["MouseCtrl"] : this.textList["FocusCtrl"]) ":"
            this.textList["MouseCtrl"]
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
        this.setText("Ctrl", cText)
        WinGetPos(wX, wY, wW, wH)
        GetClientSize(curWin, wcW, wcH)
        this.setText("Pos", "`tx: " wX "`ty: " wY "`tw: " wW "`th: " wH "`nClient:`tx: 0`ty: 0`tw: " wcW "`th: " wcH)
        sbTxt := ""
        loop {
            try {
                sbTxt .= "[" A_Index "]`t" textMangle(StatusBarGetText(A_Index)) "`n"
            } catch e {
                break
            }
        }
        sbTxt := SubStr(sbTxt, 1, -1)
        this.setText("SBText", sbTxt)
        if this.gui["IsSlow"].Value {
            DetectHiddenText(False)
            ovVisText := WinGetText()
            DetectHiddenText(True)
            ovAllText := WinGetText()
        } else {
            ovVisText := WinGetTextFast(false)
            ovAllText := WinGetTextFast(true)
        }
        this.setText("VisText", ovVisText)
        this.setText("AllText", ovAllText)
    }

    autoUpdate(enable) {
        if (enable == this.autoUpdateEnabled) {
            return
        }
        if (enable) {
            SetTimer(this.updateClosure, 100)
        } else {
            SetTimer(this.updateClosure, 0)
            this.statusBar.setText(this.textList["Frozen"])
        }
        this.autoUpdateEnabled := enable
    }
    
    updateAutoUpdateTimer() {
        local ctrlKeyDown := GetKeyState("Ctrl", "P")
        local enable := (
            ctrlKeyDown == window.gui["UpdateWhenCtrlDown"].value
        )
        this.autoUpdate(enable)
    }

}

global window := MainWindow.New()
window.gui.Show("NoActivate")
window.autoUpdate(true)

~*Ctrl::
~*Ctrl up:: {
    ; global window
    window.updateAutoUpdateTimer()
}
