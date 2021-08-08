#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; **********************************************************************************************************************
; * CONFIGURATION
; **********************************************************************************************************************

; Where is the folder that contain the files for now playing and played (Accessing ObsDirectoryStudio on the OBS Machine)
ObsDirectory := "O:"

; Where is the folder that contains files for now playing and played on the studio machine
ObsDirectoryStudio := "C:\Currently Playing"

; Where the videos file exists under BOTH ObsDirectory and ObsDirectoryStudio
VideosDirectoryName := "Videos"

; Where is the VLC instance:
VlcHostAndPort := "127.0.0.1:8080"
VlcUsername := ""
VlcPassword := "vlcremote"

;For testing on studio pc uncomment this line
;ObsDirectory := "C:\Currently Playing"
;ObsDirectoryStudio := ObsDirectory
;VlcHostAndPort := "127.0.0.1:8080"


; **********************************************************************************************************************
; * FUNCTIONS
; **********************************************************************************************************************


ClearNowPlaying(SongTrackingDirectory) {
    NowPlaying := SongTrackingDirectory . "\NowPlaying.txt"
    Played := SongTrackingDirectory . "\Played.txt"

    ; Remove NowPlaying and played and write an empty file.
    NothingPLaying = ""
    FileDelete, %NowPlaying%
    FileDelete, %Played%
    FileAppend, %NothingPLaying%, %Played%
    FileAppend, %NothingPLaying%, %Played%

    return
}

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

StopVideoInVlc(HostAndPort, UserName, Password) {
    ; Stop playing whatever may be playing

   ; Generate BASIC AUth token
    auth := b64Encode(UserName . ":" . Password)

    ; Build the stop play playlist command
    command := "http://" . HostAndPort . "/requests/status.xml?command=pl_stop"

    ; Send the request to VLC's web server
    SendBasicAuthGetCommand(command, auth)
}

ClearPlaylistInVlc(HostAndPort, UserName, Password) {
    ; Clear the playlist

   ; Generate BASIC AUth token
    auth := b64Encode(UserName . ":" . Password)

    ; Build the clear playlist command
    command := "http://" . HostAndPort . "/requests/status.xml?command=pl_empty"

    ; Send the request to VLC's web server
    SendBasicAuthGetCommand(command, auth)
}

; **********************************************************************************************************************
; * SEQUENCE OF ACTIONS
; **********************************************************************************************************************

ClearPlaylistInVlc(VlcHostAndPort, VlcUsername, VlcPassword)
StopVideoInVlc(VlcHostAndPort, VlcUsername, VlcPassword)
ClearNowPlaying(ObsDirectory)

return