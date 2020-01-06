@ECHO OFF

SET ROOT=%CD%
ECHO %ROOT%

rd /s /q %ROOT%\tools
md %ROOT%\tools
cd %ROOT%\tools
nuget.exe install Credfeto.UpdatePackages -ExcludeVersion -Source https://www.myget.org/F/credfeto/api/v3/index.json
cd %ROOT%

IF NOT EXIST %ROOT%\tools\Credfeto.UpdatePackages\lib\UpdatePackages.dll GOTO :finish

FOR /F %%a IN (%ROOT%\repos.lst) DO CALL :checkrepo %%a

GOTO :finish

:commit
ECHO ************************ UPDATES FOUND *************************
git add -A
git commit -m"FF-1429 Updated %WHAT% package (%PACKAGE%) to latest version"
git push

ECHO *********************** UPDATE COMMITTED ***********************

GOTO :EOF

:updatepackage
SETLOCAL ENABLEDELAYEDEXPANSION
SET PACKAGE=%~1
Set WHAT=%~2

ECHO.
ECHO *************************** CHECKING ***************************
ECHO * Folder: %FOLDER%
ECHO * Looking for updates of %WHAT%:%PACKAGE% 

git reset head --hard
git clean -f -x -d
git checkout master
git reset head --hard
git clean -f -x -d

dotnet %ROOT%\tools\Credfeto.UpdatePackages\lib\UpdatePackages.dll -folder "%ROOT%\%FOLDER%" -prefix "%PACKAGE%"
SET RC=%ERRORLEVEL%
ECHO Update Code: %RC%
IF NOT %RC% == 0 GOTO :noupdate
IF EXIST src\*.sln CD src

dotnet build --configuration Release
SET RC=%ERRORLEVEL%
ECHO Build Code: %RC%
IF %RC% == 0 call :commit %PACKAGE% %WHAT%

GOTO :completed

:noupdate
ECHO ########################### NO UPDATE ##########################

:completed
ENDLOCAL
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

CALL :updatepackage AsyncFixer "Code analysis"
CALL :updatepackage DisableDateTimeNow "Code analysis"
CALL :updatepackage NSubstitute.Analyzers.CSharp "Code analysis"
CALL :updatepackage Microsoft.CodeAnalysis.FxCopAnalyzers "Code analysis"
CALL :updatepackage SonarAnalyzer.CSharp "Code analysis"
CALL :updatepackage xunit.analyzers "Code analysis"
CALL :updatepackage FunFair.CodeAnalysis "Code analysis"

CALL :updatepackage SourceLink.Create.CommandLine "Source Link"

CALL :updatepackage Microsoft.NET.Test.Sdk "Test Infrastructure"
CALL :updatepackage TeamCity.VSTest.TestAdapter "Test Infrastructure"
CALL :updatepackage xunit.runner.visualstudio "Test Infrastructure"
CALL :updatepackage FunFair.Test.Common "Test Infrastructure"

ECHO.

POPD


ENDLOCAL
GOTO :EOF




:finish