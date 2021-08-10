#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.



; **********************************************************************************************************************
; * CONFIGURATION
; **********************************************************************************************************************


EnsureRunning() {
    SetTitleMatchMode, 1
    if Not WinExist("VLC media player") {
	
	; Change to be the full path where VLC.exe is installed.
        Run "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"

	; Sleep for x miliseconds
	Sleep 2000
    }

    if WinExist("VLC media player") {
        WinActivate
	
	; X, Y, Width, Height
	WinMove, , , 100, 200, 1920, 1080 
    }
    else {
	MsgBox, VLC Not running!
    }
}


; **********************************************************************************************************************
; * SEQUENCE OF ACTIONS
; **********************************************************************************************************************

EnsureRunning()

return