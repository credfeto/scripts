#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; **********************************************************************************************************************
; * CONFIGURATION
; **********************************************************************************************************************

; Where is the folder that contain the files for now playing and played
ObsDirectory := "O:"

;For testing on studio pc uncomment this line
;ObsDirectory := "C:\Currently Playing"

; **********************************************************************************************************************
; * FUNCTIONS
; **********************************************************************************************************************

GetSongName() {
    ; Work out what is being played from the filename of the script
    ; e.g. Comfortably Numb.Ahk
    SongNameLength := StrLen(A_ScriptName) - 4
    SongName := SubStr(A_ScriptName, 1, SongNameLength)

    return SongName
}

UpdateNowPlaying(SongTrackingDirectory, SongName) {
    NowPlaying := SongTrackingDirectory . "\NowPlaying.txt"
    Played := SongTrackingDirectory . "\Played.txt"

    ; Update the last played file with the name of the song, with the latest song at the top of the file
    if FileExist(Played)
    {
        FileRead, LastPlayedSongs, %Played%

        FileDelete, %Played%
        FileAppend, %SongName%`n, %Played%
        FileAppend, %LastPlayedSongs%, %Played%
    }
    else
    {
        FileDelete, %Played%
        FileAppend, %SongName%, %Played%
    }

    ; Update the currently playing file with the song name
    FileDelete, %NowPlaying%
    FileAppend, %SongName%, %NowPlaying%

    return
}

StartTrackInShowBuddy() {
    ; Activate Show Buddy, hit space to start playing
	WinActivate, Show Buddy
	Send  {Space}
	return
}


; **********************************************************************************************************************
; * SEQUENCE OF ACTIONS
; **********************************************************************************************************************

SongName := GetSongName()
UpdateNowPlaying(ObsDirectory, SongName)
StartTrackInShowBuddy()

return