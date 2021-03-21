#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; in windows Set an Environment variable OBS_SHARE to wherever the files to be updated live
; \\STREAMING_PC\OBS
EnvGet, ObsDirectory, OBS_SHARE

NowPlaying := ObsDirectory . "\NowPlaying.txt"
Played := ObsDirectory . "\Played.txt"

; Work out what is being played from the filename of the script
; e.g. Comfortably Numb.Ahk
SongNameLength := StrLen(A_ScriptName) - 4
SongName := SubStr(A_ScriptName, 1, SongNameLength)


; Update the last played file with the name of the song, with the latest song at the top of the file
Lf FileExist(Played)
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
