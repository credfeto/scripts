@ECHO OFF

SET LOGFILE=C:\LOGS\Gallery.log
SET REPOSITORY=C:\PhotoDB
SET PHOTOSSOURCE=\\nas-01\Photos\Photos\Sorted
SET METADATAOUTPUT=%REPOSITORY%\Source
SET IMAGEOUTPUT=\\nas-02\GalleryUpload 
rem SET IMAGEOUTPUT=C:\Gallery\ImageOutput
SET BROKENIMAGES=%REPOSITORY%\BrokenImages.csv
SET SHORTURLS=%REPOSITORY%\ShortUrls.json
SET WATERMARK=%REPOSITORY%\Watermark\XXWatermark.png
SET THUMBNAILSIZE=150
SET RESIZES=400,600,800,1024,1600
SET JPEGQUALITY=100

SET ROOT=%CD%
ECHO %ROOT%

rd /s /q %ROOT%\tools
md %ROOT%\tools
cd %ROOT%\tools
nuget.exe install Credfeto.Gallery.OutputBuilder -PreRelease -ExcludeVersion -Source https://www.myget.org/F/credfeto/api/v3/index.json
nuget.exe install Credfeto.Gallery.SiteIndexBuilder -PreRelease -ExcludeVersion -Source https://www.myget.org/F/credfeto/api/v3/index.json

cd %ROOT%

IF NOT EXIST %ROOT%\tools\Credfeto.Gallery.OutputBuilder\lib\OutputBuilderClient.dll GOTO :finish
IF NOT EXIST %ROOT%\tools\Credfeto.Gallery.SiteIndexBuilder\lib\BuildSiteIndex.dll GOTO :finish

SET STARTTIME=%DATE% %TIME%

SET OUTPUTBUILDER="C:\Program Files\dotnet\dotnet.exe" "%ROOT%\tools\Credfeto.Gallery.OutputBuilder\lib\OutputBuilderClient.dll" -source %PHOTOSSOURCE% -output %METADATAOUTPUT% -imageoutput %IMAGEOUTPUT% -brokenImages %BROKENIMAGES% -shortUrls %SHORTURLS% -watermark %WATERMARK% -thumbnailSize %THUMBNAILSIZE% -quality JPEGQUALITY -resizes %RESIZES%
SET BUILDSITEINDEX="C:\Program Files\dotnet\dotnet.exe" "%ROOT%\tools\Credfeto.Gallery.SiteIndexBuilder\lib\BuildSiteIndex.dll"


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



