#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; **********************************************************************************************************************
; * CONFIGURATION
; **********************************************************************************************************************



if WinExist("Show Buddy V1.5.3")
	WinActivate
else
	MsgBox Show Buddy not running
	ExitApp
return

MsgBox "Hello"