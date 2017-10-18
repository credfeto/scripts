REM @echo off

SET LOGFILE=C:\LOGS\Gallery.log
SET REPOSITORY=C:\PhotoDB
SET OUTPUTBUILDER=C:\Development\GallerySync\OutputBuilderClient\bin\Release\OutputBuilderClient.exe

C:
PUSHD %REPOSITORY%
call :updateshorturls
REM git reset head --hard

echo %DATE% %TIME% Getting latest source...
git pull

echo %DATE% %TIME% Updating Output...
%OUTPUTBUILDER% > %LOGFILE%

call :updateshorturls
call :updateall

git pull
git push

goto finish

:updateall
echo %DATE% %TIME% Updating all metadata...
REM git add -A
REM git commit -m"Updated metadata"
git push
goto :eof

:updateshorturls
ECHO %DATE% %TIME% Updating Short URLS...
git add ShortUrls.csv
git add ShortUrls.csv.tracking.json
git commit -m"Updated Short URLS"
git push
goto :eof



:finish
POPD