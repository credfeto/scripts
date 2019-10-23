@echo off

rem git@github.com:funfair-tech/funfair-build-check.git

SET ROOT=%~dp0
echo %ROOT%

for /F %%a in (repos.lst) do call :checkrepo %%a

goto :finish


:checkrepo
SETLOCAL
SET REPO=%1
echo.
echo Repo: %REPO%
SET FOLDER=
for /F "tokens=1,2,3 delims=:/" %%b in ("%1") do set FOLDER=%%d
SET FOLDER=%FOLDER:~0,-4%
echo %FOLDER%

IF NOT EXIST %ROOT%%FOLDER% git clone %REPO%
PUSHD %ROOT%%FOLDER%

ECHO %CD%

POPD

rd /s /q %ROOT%%FOLDER%

ENDLOCAL
goto :eof


:finish