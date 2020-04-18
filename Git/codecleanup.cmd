@ECHO OFF

SET ROOT=%CD%
ECHO %ROOT%

FOR /F %%a IN (%ROOT%\repos.lst) DO CALL :checkrepo %%a

GOTO :finish

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
git commit -m"[FF-2244] Code Cleanup on %SOLUTIONFILE%"
SET RC=%ERRORLEVEL%
ECHO Commit Code: %RC%
IF NOT %RC% == 0 goto :branchalreadyexists
git push --set-upstream origin %BRANCHNAME%
git checkout master
git branch -D %BRANCHNAME%
git remote update origin --prune

ECHO *********************** UPDATE COMMITTED ***********************

:branchalreadyexists
git checkout master

GOTO :EOF

:cleanup
SETLOCAL ENABLEDELAYEDEXPANSION
SET SOLUTION=%~1

ECHO.
ECHO *************************** CHECKING ***************************
SET SOLUTIONFOLDER=%~dp1
SET SOLUTIONFILE=%~nx1
ECHO * Performing code cleanup on %SOLUTIONFILE% 
ECHO * In folder: %SOLUTIONFOLDER%
pushd %SOLUTIONFOLDER%

git reset head --hard
git clean -f -x -d
git checkout master
git reset head --hard
git clean -f -x -d


SET BRANCHNAME=cleanup/ff-2244-%SOLUTIONFILE%
git remote update origin --prune
git branch -D %BRANCHNAME%
git remote update origin --prune
git checkout %BRANCHNAME%

set GITBRANCH=
for /f %%I in ('git.exe rev-parse --abbrev-ref HEAD 2^> NUL') do set GITBRANCH=%%I
echo Current Branch: %GITBRANCH%

dotnet clean --configuration=Release 

dotnet restore
SET RC=%ERRORLEVEL%
ECHO Build Code: %RC%
IF NOT %RC% == 0 goto :noupdate

dotnet build --configuration=Release --no-restore -warnAsError
SET RC=%ERRORLEVEL%
ECHO Build Code: %RC%
IF NOT %RC% == 0 goto :noupdate

REM Cleanup code
cleanupcode.exe --profile="Full Cleanup" %1 --properties:Configuration=Release

dotnet build --configuration=Release --no-restore -warnAsError
SET RC=%ERRORLEVEL%
ECHO Build Code: %RC%
IF %RC% == 0 call call :branch
IF NOT %RC% == 0 goto :noupdate


GOTO :completed

:noupdate
ECHO ########################### NO UPDATE ##########################

:completed
POPD
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
git rebase
git remote update origin --prune
git prune
git gc --aggressive --prune


FOR %%F IN (src/*.sln) do CALL :cleanup %%~dpnxF

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