@echo off

echo Clearing Cache
nuget locals all -clear

echo Restoring packages
for /r %%a in (*.sln) do call :restore %%a

echo Done

goto finish

:restore

echo %1
pushd %~DP1
dotnet restore
popd

goto :eof


:finish