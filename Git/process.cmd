@ECHO OFF

SET ROOT=%CD%
ECHO %ROOT%

FOR /F %%a IN (%ROOT%\repos.lst) DO CALL :checkrepo %%a

GOTO :finish

:updatepackage
SETLOCAL ENABLEDELAYEDEXPANSION
SET PACKAGE=%1

ECHO.
ECHO *************************** CHECKING ***************************
ECHO * %PACKAGE% 

git reset head --hard
git clean -f -x -d
git checkout master
git reset head --hard
git clean -f -x -d

%ROOT%\UpdatePackages\UpdatePackages\bin\Release\netcoreapp3.0\UpdatePackages.exe -folder "%ROOT%\%FOLDER%" -prefix "%PACKAGE%"
IF NOT ERRORLEVEL == 0 GOTO :noupdate
IF EXIST src\*.sln CD src

dotnet build --configuration Release
IF ERRORLEVEL == 0 call :commit %PACKAGE%

GOTO :completed

:noupdate
ECHO ########################### NO UPDATE ##########################

:completed
ENDLOCAL
GOTO :EOF

:commit
ECHO ************************ UPDATES FOUND *************************
git add -A
git commit -m"FF-1429 Updated Code %PACKAGE% analysis package to latest version"
git push

ECHO *********************** UPDATE COMMITTED ***********************

GOTO :EOF


:checkrepo
SETLOCAL
SET REPO=%1
echo.
ECHO Repo: %REPO%
SET FOLDER=
FOR /F "tokens=1,2,3 delims=:/" %%b IN ("%1") DO SET FOLDER=%%d
SET FOLDER=%FOLDER:~0,-4%
ECHO %FOLDER%

ECHO.
ECHO ================================================================
ECHO ================================================================
ECHO = %FOLDER%

IF NOT EXIST %ROOT%\%FOLDER%\.git\HEAD git clone %REPO%
cd /d %ROOT%
PUSHD %ROOT%\%FOLDER%
ECHO %CD%

git fetch
git rebase

CALL :updatepackage AsyncFixer
CALL :updatepackage NSubstitute.Analyzers.CSharp
CALL :updatepackage Microsoft.CodeAnalysis.FxCopAnalyzers
CALL :updatepackage SonarAnalyzer.CSharp
CALL :updatepackage xunit.analyzers
CALL :updatepackage SourceLink.Create.CommandLine

ECHO.

POPD


ENDLOCAL
GOTO :EOF




:finish