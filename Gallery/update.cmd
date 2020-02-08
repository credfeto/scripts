@echo on

REM TODO: Get these externally configured
SET LOGFILE=C:\LOGS\Gallery.log
SET REPOSITORY=C:\PhotoDB
SET OUTPUTBUILDER="C:\Program Files\dotnet\dotnet.exe" C:/Work/GallerySync/OutputBuilderClient/bin/Release/netcoreapp2.2/OutputBuilderClient.dll -source I:\Photos\Sorted -output C:\PhotoDb\Source -imageoutput \\nas-01\GalleryUpload -brokenImages C:\PhotoDb\BrokenImages.csv -shortUrls C:\PhotoDb\ShortUrls.json -watermark C:\Work\GallerySync\Watermark\Watermark.png -thumbnailSize 150 -quality 100 -resizes 400,600,800,1024,1600

SET BUILDSITEINDEX="C:\Program Files\dotnet\dotnet.exe" C:/Work/GallerySync/BuildSiteIndex/bin/Release/netcoreapp2.2/BuildSiteIndex.dll
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
rem %BUILDSITEINDEX% >> %LOGFILE%
 
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