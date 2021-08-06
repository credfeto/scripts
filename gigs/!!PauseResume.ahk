#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; **********************************************************************************************************************
; * CONFIGURATION
; **********************************************************************************************************************

; Where is the VLC instance:
VlcHostAndPort := "127.0.0.1:8080"
VlcUsername := ""
VlcPassword := "vlcremote"

;For testing on studio pc uncomment this line
;VlcHostAndPort := "127.0.0.1:8080"

; **********************************************************************************************************************
; * FUNCTIONS
; **********************************************************************************************************************

b64Encode(string) {
    ; BASIC Authentication requires BASE 64 encoding
    VarSetCapacity(bin, StrPut(string, "UTF-8")) && len := StrPut(string, &bin, "UTF-8") - 1
    if !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", 0, "uint*", size))
        throw Exception("CryptBinaryToString failed", -1)
    VarSetCapacity(buf, size << 1, 0)
    if !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", &buf, "uint*", size))
        throw Exception("CryptBinaryToString failed", -1)
    return StrGet(&buf)
}

LC_UriEncode(Uri, RE="[0-9A-Za-z]") {
    ; Make sure parameters are encoded
	VarSetCapacity(Var, StrPut(Uri, "UTF-8"), 0), StrPut(Uri, &Var, "UTF-8")
	While Code := NumGet(Var, A_Index - 1, "UChar")
		Res .= (Chr:=Chr(Code)) ~= RE ? Chr : Format("%{:02X}", Code)
	Return, Res
}

SendBasicAuthGetCommand(Command, Auth) {

    ; Send the request to VLC's web server
    try
    {
        oWhr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        oWhr.SetTimeouts("1000", "1000", "2500", "5000")
        oWhr.Open("GET", command, false)
        oWhr.SetRequestHeader("Content-Type", "application/json")
        oWhr.SetRequestHeader("Authorization", "Basic " . Auth)
        oWhr.Send()
    }
    catch e {
        ; don't care
        ; MsgBox e.Message
    }

}

PauseOrResumeVideoInVlc(HostAndPort, UserName, Password) {
    ; Stop playing whatever may be playing

   ; Generate BASIC AUth token
    auth := b64Encode(UserName . ":" . Password)

    ; Build the stop play playlist command
    command := "http://" . HostAndPort . "/requests/status.xml?command=pl_pause"

    ; Send the request to VLC's web server
    SendBasicAuthGetCommand(command, auth)
}

ShowBuddyPauseResume() {
    SetTitleMatchMode, 1
    if WinExist("Show Buddy") {
        WinActivate
	Send, " "
    }
    else {
        MsgBox Show Buddy not running
        ExitApp
    }
}


; **********************************************************************************************************************
; * SEQUENCE OF ACTIONS
; **********************************************************************************************************************

ShowBuddyPauseResume()
PauseOrResumeVideoInVlc(VlcHostAndPort, VlcUsername, VlcPassword)

return
