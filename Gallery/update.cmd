@echo off

REM TODO: Get these externally configured
SET LOGFILE=C:\LOGS\Gallery.log
SET REPOSITORY=C:\PhotoDB
SET OUTPUTBUILDER=C:\Development\GallerySync\OutputBuilderClient\bin\Release\OutputBuilderClient.exe
SET BUILDSITEINDEX=C:\Development\GallerySync\BuildSiteIndex\bin\Release\BuildSiteIndex.exe
SET STARTTIME=%DATE% %TIME%
C:
PUSHD %REPOSITORY%
call :updateshorturls
git reset head --hard

echo %DATE% %TIME% Getting latest source...
git pull

echo %DATE% %TIME% Updating Output...
%OUTPUTBUILDER% > %LOGFILE%

call :updateshorturls
call :updateall "Metadata"

echo %DATE% %TIME% Updating Site Index...
%BUILDSITEINDEX% >> %LOGFILE%
 
call :updateshorturls
call :updateall "Site Index"

git pull
git push

goto finish

:updateall
echo %DATE% %TIME% Updating all metadata...
git add -A
git commit -m"Updated %~1 for %STARTTIME%"
git push
goto :eof

:updateshorturls
ECHO %DATE% %TIME% Updating Short URLS...
git add ShortUrls.csv
git add ShortUrls.csv.tracking.json
git commit -m"Updated Short URLS for %STARTTIME%"
git push
goto :eof



:finish
POPD