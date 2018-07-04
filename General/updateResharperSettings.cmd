@echo off
SET SRCEDITORCONFIG=D:\Work\FunServer\.editorconfig
SET SRC=D:\Work\FunServer\src\FunFair.FunServer.sln.DotSettings
SET SRCCODEANALYSIS=D:\Work\FunServer\src\CodeAnalysis.ruleset

for /R D:\Work %%a in (*.sln.DotSettings) do call :updatedotsettings %%a
for /d %%a in (D:\Work\*.*) do call :updateeditorconfig %%a
for /d %%a in (D:\Work\*.*) do call :updatecodeanalysisrules %%a

goto finish

:updatecodeanalysisrules 
echo %1
IF NOT EXIST "%1\.git\HEAD" goto :noupdate
IF "%1\src\CodeAnalysis.ruleset" == "%SRCCODEANALYSIS%" goto :noupdate

pushd "%1"
COPY /Y %SRCCODEANALYSIS%  %1\src\CodeAnalysis.ruleset

git add src/CodeAnalysis.ruleset
git commit -m"Updated %~NX1 CodeAnalysis.ruleset"
git push

popd

goto :eof


:updateeditorconfig 
echo %1
IF NOT EXIST "%1\.git\HEAD" goto :noupdate
IF "%1\.editorconfig" == "%SRCEDITORCONFIG%" goto :noupdate

pushd "%1"
COPY /Y %SRCEDITORCONFIG%  %1\.editorconfig

git add .editorconfig
git commit -m"Updated %~NX1 .editorconfig"
git push

popd

goto :eof

:updatedotsettings
IF "%SRC%" EQU "%1" goto noupdate
IF NOT EXIST %1 goto noupdate

IF "%1" EQU "D:\Work\BuildBot\src\BuildBot.sln.DotSettings" goto noupdate
IF "%1" EQU "D:\Work\CoinBot\src\CoinBot.sln.DotSettings" goto noupdate
IF "%1" EQU "D:\Work\FS\src\FunFair.FunServer.sln.DotSettings" goto noupdate
IF "%1" EQU "D:\Work\Nethereum\Nethereum.sln.DotSettings" goto noupdate
IF "%1" EQU "D:\Work\NuGetGallery\NuGetGallery.sln.DotSettings" goto noupdate
IF "%1" EQU "D:\Work\NuGetGallery\tests\NuGetGallery.FunctionalTests.sln.DotSettings" goto noupdate

pushd "%~DP1"

git pull

COPY /Y %SRC% %1

git add %~NX1
git commit -m"Updated %~NX1"
git push

popd

:noupdate
goto :eof


:finish

