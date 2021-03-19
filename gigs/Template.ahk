#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; Work out what is being played from the filename of the script
; e.g. Comfortably Numb.Ahk
SongNameLength := StrLen(A_ScriptName) - 4
SongName := SubStr(A_ScriptName, 1, SongNameLength)

ControlSend, Edit1, ^a, NowPlaying
ControlSend, Edit1, %SongName%, NowPlaying
ControlSend, Edit1, ^s, NowPlaying

ControlSend, Edit1, {Up}, SongsPreviouslyPlayed
ControlSend, Edit1, {Enter}, SongsPreviouslyPlayed
ControlSend, Edit1, SongsPreviouslyPlayed
ControlSend, Edit1, %SongName%, SongsPreviouslyPlayed
ControlSend, Edit1, ^s, SongsPreviouslyPlayed
return