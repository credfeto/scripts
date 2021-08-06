@echo off

:start
dotnet clean
dotnet build --configuration=Release
if ERRORLEVEL 1 goto finish

goto start

:finish
