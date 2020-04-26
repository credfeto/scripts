@ECHO OFF

SET LOGFILE=C:\LOGS\Gallery.log
SET REPOSITORY=C:\PhotoDB
SET PHOTOSSOURCE=\\nas-01\Photos\Photos\Sorted
SET METADATAOUTPUT=%REPOSITORY%\Source
SET IMAGEOUTPUT=\\nas-02\GalleryUpload 
rem SET IMAGEOUTPUT=C:\Gallery\ImageOutput
SET BROKENIMAGES=%REPOSITORY%\BrokenImages.csv
SET SHORTURLS=%REPOSITORY%\ShortUrls.csv
SET WATERMARK=%REPOSITORY%\Watermark\XXWatermark.png
SET THUMBNAILSIZE=150
SET RESIZES=400,600,800,1024,1600
SET JPEGQUALITY=100

SET ROOT=%CD%
ECHO %ROOT%

if not exist %ROOT%\.config\dotnet-tools.json dotnet new tool-manifest
dotnet tool update --local Credfeto.Gallery.OutputBuilder
dotnet tool update --local Credfeto.Gallery.SiteIndexBuilder

dotnet tool install --local Credfeto.Gallery.OutputBuilder
dotnet tool install --local Credfeto.Gallery.SiteIndexBuilder

dotnet tool list --local


SET STARTTIME=%DATE% %TIME%

SET OUTPUTBUILDER="dotnet buildgalleryoutput -source %PHOTOSSOURCE% -output %METADATAOUTPUT% -imageoutput %IMAGEOUTPUT% -brokenImages %BROKENIMAGES% -shortUrls %SHORTURLS% -watermark %WATERMARK% -thumbnailSize %THUMBNAILSIZE% -quality %JPEGQUALITY% -resizes %RESIZES%
SET BUILDSITEINDEX=dotnet buildgallerysiteindex

SET STARTTIME=%DATE% %TIME%
C:
PUSHD %REPOSITORY%
call :updateshorturls
git reset head --hard
git clean -f -x -d

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



