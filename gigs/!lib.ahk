; ********************************************************
; Library Functions
; ********************************************************


; ********************************************************
; Run program with full positioning
; ********************************************************
EnsureRunningFull(Title, Exe, X, Y, Width, Height, DelayInMsAfterStarting) {

    SetTitleMatchMode, 1
    if Not WinExist(Title) {
	
	SplitPath, Exe, , WorkingDir
	; Change to be the full path where VLC.exe is installed.
	Run %Exe%, %WorkingDir%

	; Sleep for x miliseconds
	Sleep DelayInMsAfterStarting
    }

    if WinExist(Title) {
        WinActivate
	
	; X, Y, Width, Height
	WinMove, , , X, Y, Width, Height
    }
    else {
;	MsgBox, %Title% Not running!
        Exit
    }
}

EnsureRunning(Program) {
  IniRead, Title, Settings.ini, %Program%, Title
  IniRead, Exe, Settings.ini, %Program%, Exe
  IniRead, Left, Settings.ini, %Program%, Left
  IniRead, Top, Settings.ini, %Program%, Top
  IniRead, Width, Settings.ini, %Program%, Width
  IniRead, Height, Settings.ini, %Program%, Height
  IniRead, DelayInMsAfterStarting, Settings.ini, %Program%, DelayInMsAfterStarting

  EnsureRunningFull(Title, Exe, Left, Top, Width, Height, DelayInMsAfterStarting)
}
