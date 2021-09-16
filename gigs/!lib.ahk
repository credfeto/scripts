; ********************************************************
; Library Functions
; ********************************************************


; ********************************************************
; Run program with full positioning
; ********************************************************
EnsureRunningFull(Title, Exe, X, Y, Width, Height) {

    SetTitleMatchMode, 1
    if Not WinExist(Title) {
	
	SplitPath, Exe, , WorkingDir
	; Change to be the full path where VLC.exe is installed.
	Run %Exe%, %WorkingDir%

	; Sleep for x miliseconds
	Sleep 2000
    }

    if WinExist(Title) {
        WinActivate
	
	; X, Y, Width, Height
	WinMove, , , X, Y, Width, Height
    }
    else {
	MsgBox, %Title% Not running!
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

  EnsureRunningFull(Title, Exe, Left, Top, Width, Height)
}
