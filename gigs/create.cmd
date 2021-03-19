@echo off
if not exist SongList.txt goto :MissingSongList
if not exist Template.ahk goto :MissingTemplate
for /F "delims=" %%a in (SongList.txt) do call :Generate "%%a"

goto :finish

:MissingSongList
echo Songlist.txt Missing
goto :finish

:MissingTemplate
echo Template.ahk Missing
goto :finish


:Generate
echo Creating/Updating: %~1
copy Template.ahk "%~1.ahk"
goto :eof


:finish
pause