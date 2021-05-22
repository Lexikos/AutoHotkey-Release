; 
; Window Spy for AHKv2
;

#NoTrayIcon
#SingleInstance Ignore
SetWorkingDir A_ScriptDir
CoordMode "Pixel", "Screen"

Global oGui

WinSpyGui()

WinSpyGui() {
    Global oGui
    txtNotFrozen := "(Hold Ctrl or Shift to suspend updates)"
    txtFrozen := "(Updates suspended)"
    txtMouseCtrl := "Control Under Mouse Position"
    txtFocusCtrl := "Focused Control"
    
    oGui := Gui("AlwaysOnTop Resize MinSize +DPIScale","Window Spy for AHKv2"), hGui := oGui.hwnd
    oGui.OnEvent("Close",WinSpyClose)
    oGui.OnEvent("Size",WinSpySize)
    
    oGui.Add("Text",,"Window Title, Class and Process:")
    oGui.Add("Checkbox","yp xp+200 w120 Right vCtrl_FollowMouse","Follow Mouse").Value := 1
    oGui.Add("Edit","xm w320 r5 ReadOnly -Wrap vCtrl_Title")
    oGui.Add("Text",,"Mouse Position")
    oGui.Add("Edit","w320 r4 ReadOnly vCtrl_MousePos")
    oGui.Add("Text","w320 vCtrl_CtrlLabel",txtFocusCtrl ":")
    oGui.Add("Edit","w320 r4 ReadOnly vCtrl_Ctrl")
    oGui.Add("Text",,"Active Window Postition:")
    oGui.Add("Edit","w320 r2 ReadOnly vCtrl_Pos")
    oGui.Add("Text",,"Status Bar Text:")
    oGui.Add("Edit","w320 r2 ReadOnly vCtrl_SBText")
    oGui.Add("Checkbox","vCtrl_IsSlow","Slow TitleMatchMode")
    oGui.Add("Text",,"Visible Text:")
    oGui.Add("Edit","w320 r2 ReadOnly vCtrl_VisText")
    oGui.Add("Text",,"All Text:")
    oGui.Add("Edit","w320 r2 ReadOnly vCtrl_AllText")
    oGui.Add("Text","w320 r1 vCtrl_Freeze",txtNotFrozen)
    
    oGui.Show("NoActivate")
    GetClientSize(hGui, &temp, &temp2)
    
    horzMargin := temp*96//A_ScreenDPI - 320
    oGui.horzMargin := horzMargin
    
    oGui.txtNotFrozen := txtNotFrozen, oGui.txtFrozen := txtFrozen
    oGui.txtMouseCtrl := txtMouseCtrl, oGui.txtFocusCtrl := txtFocusCtrl
    
    SetTimer Update, 250
}

WinSpySize(GuiObj, MinMax, Width, Height) {
    Global oGui
    horzMargin := oGui.horzMargin
    if !horzMargin
        return
    
    SetTimer Update, (MinMax=0)?250:0 ; suspend updates on minimize
    
    ctrlW := Width - horzMargin
    list := "Title,MousePos,Ctrl,Pos,SBText,VisText,AllText,Freeze"
    Loop Parse list, ","
        ctl := oGui["Ctrl_" A_LoopField], ctl.Move(,,ctrlW)
}

WinSpyClose(GuiObj) {
    ExitApp
}

Update() { ; timer, no params
    Try TryUpdate()
}

TryUpdate() {
    Global oGui
    hGui := oGui.hwnd
    txtNotFrozen := oGui.txtNotFrozen, txtFrozen := oGui.txtFrozen
    txtMouseCtrl := oGui.txtMouseCtrl, txtFocusCtrl := oGui.txtFocusCtrl
    
    Ctrl_FollowMouse := oGui["Ctrl_FollowMouse"].Value
    CoordMode "Mouse", "Screen"
    MouseGetPos &msX, &msY, &msWin, &msCtrl, 2 ; get ClassNN and hWindow
    actWin := WinExist("A")
    
    if (Ctrl_FollowMouse) {
        curWin := msWin, curCtrl := msCtrl
        WinExist("ahk_id " curWin) ; updating LastWindowFound?
    } else {
        curWin := actWin
        curCtrl := ControlGetFocus() ; get focused control hwnd from active win
    }
    curCtrlClassNN := ControlGetClassNN(curCtrl)
    
    t1 := WinGetTitle(), t2 := WinGetClass()
    if (curWin = hGui || t2 = "MultitaskingViewFrame") { ; Our Gui || Alt-tab
        UpdateText("Ctrl_Freeze", txtFrozen)
        return
    }
    
    UpdateText("Ctrl_Freeze", txtNotFrozen)
    t3 := WinGetProcessName(), t4 := WinGetPID()
    
    UpdateText("Ctrl_Title", t1 "`nahk_class " t2 "`nahk_exe " t3 "`nahk_pid " t4 "`nahk_id " curWin)
    CoordMode "Mouse", "Window"
    MouseGetPos &mrX, &mrY
    CoordMode "Mouse", "Client"
    MouseGetPos &mcX, &mcY
    mClr := PixelGetColor(msX,msY,"RGB")
    mClr := SubStr(mClr, 3)
    
    UpdateText("Ctrl_MousePos", "Screen:`t" msX ", " msY " (less often used)`nWindow:`t" mrX ", " mrY " (default)`nClient:`t" mcX ", " mcY " (recommended)"
        . "`nColor:`t" mClr " (Red=" SubStr(mClr, 1, 2) " Green=" SubStr(mClr, 3, 2) " Blue=" SubStr(mClr, 5) ")")
    
    UpdateText("Ctrl_CtrlLabel", (Ctrl_FollowMouse ? txtMouseCtrl : txtFocusCtrl) ":")
    
    if (curCtrl) {
        ctrlTxt := ControlGetText(curCtrl)
        cText := "ClassNN:`t" curCtrlClassNN "`nText:`t" textMangle(ctrlTxt)
        ControlGetPos &cX, &cY, &cW, &cH, curCtrl
        cText .= "`n`tx: " cX "`ty: " cY "`tw: " cW "`th: " cH
        WinToClient(curWin, &cX, &cY)
        GetClientSize(curCtrl, &cW, &cH)
        cText .= "`nClient:`tx: " cX "`ty: " cY "`tw: " cW "`th: " cH
    } else
        cText := ""
    
    UpdateText("Ctrl_Ctrl", cText)
    wX := "", wY := "", wW := "", wH := ""
    WinGetPos &wX, &wY, &wW, &wH
    GetClientSize(curWin, &wcW, &wcH)
    
    UpdateText("Ctrl_Pos", "`tx: " wX "`ty: " wY "`tw: " wW "`th: " wH "`nClient:`tx: 0`ty: 0`tw: " wcW "`th: " wcH)
    sbTxt := ""
    
    Loop {
        if !(ovi := StatusBarGetText(A_Index))
            break
        sbTxt .= "(" A_Index "):`t" textMangle(ovi) "`n"
    }
    
    sbTxt := SubStr(sbTxt,1,-1) ; StringTrimRight, sbTxt, sbTxt, 1
    UpdateText("Ctrl_SBText", sbTxt)
    bSlow := oGui["Ctrl_IsSlow"].Value ; GuiControlGet, bSlow,, Ctrl_IsSlow
    
    if (bSlow) {
        DetectHiddenText False
        ovVisText := WinGetText() ; WinGetText, ovVisText
        DetectHiddenText True
        ovAllText := WinGetText() ; WinGetText, ovAllText
    } else {
        ovVisText := WinGetTextFast(false)
        ovAllText := WinGetTextFast(true)
    }
    
    UpdateText("Ctrl_VisText", ovVisText)
    UpdateText("Ctrl_AllText", ovAllText)
}

; ===========================================================================================
; WinGetText ALWAYS uses the "slow" mode - TitleMatchMode only affects
; WinText/ExcludeText parameters. In "fast" mode, GetWindowText() is used
; to retrieve the text of each control.
; ===========================================================================================
WinGetTextFast(detect_hidden) {    
    controls := WinGetControlsHwnd() ; "ahk_id " curWin
    
    static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.
    
    buf := Buffer(WINDOW_TEXT_SIZE * 2,0)
    
    text := ""
    
    Loop controls.Length {
        hCtl := controls[A_Index]
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
            continue
        if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
            continue
        ; text .= buf "`r`n"
        text .= StrGet(buf) "`r`n"
    }
    return text
}

; ===========================================================================================
; Unlike using a pure GuiControl, this function causes the text of the
; controls to be updated only when the text has changed, preventing periodic
; flickering (especially on older systems).
; ===========================================================================================
UpdateText(vCtl, NewText) {
    Global oGui
    static OldText := {}
    ctl := oGui[vCtl], hCtl := Integer(ctl.hwnd)
    ; msgbox hCtl
    
    if (!oldText.HasProp(hCtl) Or OldText.%hCtl% != NewText) {
        ctl.Value := NewText
        OldText.%hCtl% := NewText
    }
}

GetClientSize(hWnd, &w, &h) {
    rect := Buffer(16,0)
    ; VarSetCapacity(rect, 16)
    DllCall("GetClientRect", "ptr", hWnd, "ptr", rect.ptr)
    w := NumGet(rect, 8, "int"), h := NumGet(rect, 12, "int")
}

WinToClient(hWnd, &x, &y) {
    WinGetPos &wX, &wY,,, "ahk_id " hWnd
    If (wX != "" And wY != "") {
        x += wX, y += wY
        pt := Buffer(8,0)
        ; VarSetCapacity(pt, 8)
        
        NumPut "Int", x, pt
        NumPut "Int", y, pt, 4
        ; NumPut(y, NumPut(x, pt, "int"), "int")
        
        if !DllCall("ScreenToClient", "ptr", hWnd, "ptr", pt.ptr)
            return false
        x := NumGet(pt, 0, "int"), y := NumGet(pt, 4, "int")
        return true
    } Else
        return false
    
}

textMangle(x) {
    elli := false
    if (pos := InStr(x, "`n"))
        x := SubStr(x, 1, pos-1), elli := true
    else if (StrLen(x) > 40)
        x := SubStr(x,1,40), elli := true
    if elli
        x .= " (...)"
    return x
}

suspend_timer() {
    txtFrozen := oGui.txtFrozen
    SetTimer Update, 0
    UpdateText("Ctrl_Freeze", txtFrozen)
}

~Shift::
~Ctrl::suspend_timer()  ; * is not working here for now

~*Ctrl up::
~*Shift up::SetTimer Update, 250
