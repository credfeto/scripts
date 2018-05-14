@echo off
SET SRC=D:\Work\FunServer\src\FunFair.FunServer.sln.DotSettings

for /R D:\Work %%a in (*.sln.DotSettings) do call :update %%a

goto finish

:update
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

