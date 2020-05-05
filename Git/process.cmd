@ECHO OFF

SET ROOT=%CD%
ECHO %ROOT%

if not exist %ROOT%\.config\dotnet-tools.json dotnet new tool-manifest
dotnet tool update --local Credfeto.Package.Update
dotnet tool install --local Credfeto.Package.Update

FOR /F %%a IN (%ROOT%\repos.lst) DO CALL :checkrepo %%a

GOTO :finish

:commit
ECHO ************************ UPDATES FOUND *************************
git add -A
git commit -m"FF-1429 Updated %WHAT% package (%PACKAGE%) to latest version"
git push -v

ECHO *********************** UPDATE COMMITTED ***********************

GOTO :EOF

:branch
ECHO ************************ UPDATES FOUND *************************
ECHO * Committing to a separate branch!

ECHO Current Branch: %GITBRANCH%
ECHO New Branch    : %BRANCHNAME%
IF "%BRANCHNAME%" == "%GITBRANCH%" GOTO :updateinexistingbranch

git remote update origin --prune
git branch -D %BRANCHNAME%
git checkout -b %BRANCHNAME%
IF NOT %ERRORLEVEL% == 0 goto :branchalreadyexists

:updateinexistingbranch
git add -A
git commit -m"[FF-1429] Updated %WHAT% package (%PACKAGE%) to latest version"
git push --set-upstream origin %BRANCHNAME% -v
git checkout master
git branch -D %BRANCHNAME%
git remote update origin --prune

ECHO *********************** UPDATE COMMITTED ***********************

:branchalreadyexists

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


SET BRANCHNAME=depends/ff-1429-update-%PACKAGE%
git remote update origin --prune
git branch -D %BRANCHNAME%
git checkout %BRANCHNAME%

set GITBRANCH=
for /f %%I in ('git.exe rev-parse --abbrev-ref HEAD 2^> NUL') do set GITBRANCH=%%I
echo Current Branch: %GITBRANCH%

dotnet updatepackages -folder "%ROOT%\%FOLDER%" -prefix "%PACKAGE%"
SET RC=%ERRORLEVEL%
ECHO Update Code: %RC%
IF NOT %RC% == 0 GOTO :noupdate
IF EXIST src\*.sln CD src

dotnet clean --configuration=Release 

dotnet restore
SET RC=%ERRORLEVEL%
ECHO Build Code: %RC%
IF NOT %RC% == 0 goto :noupdate

dotnet build --configuration=Release --no-restore -warnAsError
SET RC=%ERRORLEVEL%
ECHO Build Code: %RC%
IF %RC% == 0 call :commit %PACKAGE% %WHAT%
IF NOT %RC% == 0 call :branch %PACKAGE% %WHAT%

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

IF NOT EXIST %ROOT%\%FOLDER%\.git\HEAD call :clone
cd /d %ROOT%
PUSHD %ROOT%\%FOLDER%
ECHO %CD%

git reset head --hard
git clean -f -x -d
git checkout master
git reset head --hard
git clean -f -x -d
git fetch
REM NOTE Loses all local commmits on master
git reset --hard origin/master
git remote update origin --prune
git prune
git gc --aggressive --prune

CALL :updatepackage AsyncFixer "Code analysis"
CALL :updatepackage DisableDateTimeNow "Code analysis"
CALL :updatepackage NSubstitute.Analyzers.CSharp "Code analysis"
CALL :updatepackage Microsoft.CodeAnalysis.FxCopAnalyzers "Code analysis"
CALL :updatepackage SonarAnalyzer.CSharp "Code analysis"
CALL :updatepackage xunit.analyzers "Code analysis"
CALL :updatepackage FunFair.CodeAnalysis "Code analysis"
CALL :updatepackage Microsoft.VisualStudio.Threading.Analyzers "Code analysis"
CALL :updatepackage Roslynator.Analyzers "Code analysis"

CALL :updatepackage SourceLink.Create.CommandLine "Source Link"

CALL :updatepackage Microsoft.NET.Test.Sdk "Test Infrastructure"
CALL :updatepackage TeamCity.VSTest.TestAdapter "Test Infrastructure"
CALL :updatepackage xunit.runner.visualstudio "Test Infrastructure"
CALL :updatepackage FunFair.Test.Common "Test Infrastructure"

CALL :updatepackage LibGit2Sharp "Build Infrastructure"

ECHO.

POPD


ENDLOCAL
GOTO :EOF

:clone
git clone %REPO%
rem attempt to register with scalar
cd /d %ROOT%
PUSHD %ROOT%\%FOLDER%
scalar register 
popd

goto :EOF


:finish