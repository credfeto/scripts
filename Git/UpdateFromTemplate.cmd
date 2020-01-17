@echo off
SETLOCAL
SET TEMPLATE=D:\Work\funfair-server-template
SET ROOT=%CD%
ECHO %ROOT%

echo Updating Template
PUSHD %TEMPLATE%
git reset head --hard
git clean -f -x -d
git checkout master
git rebase
git rebase --abort
git reset head --hard
git clean -f -x -d

POPD

FOR /F %%a IN (%ROOT%\repos.lst) DO CALL :checkrepo %%a

GOTO :finish

:commit
ECHO ************************ UPDATES FOUND *************************
git add -A
git commit -m"FF-1429 Updating to match the template file"
git push

ECHO *********************** UPDATE COMMITTED ***********************

GOTO :EOF

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

git reset head --hard
git clean -f -x -d
git checkout master
git reset head --hard
git clean -f -x -d

REM ALways overwrite
copy /y /z %TEMPLATE%\.editorconfig "%ROOT%\%FOLDER%\.editorconfig"
copy /y /z %TEMPLATE%\src\CodeAnalysis.ruleset "%ROOT%\%FOLDER%\src\CodeAnalysis.ruleset"
REM copy /y /z %TEMPLATE%\src\global.json "%ROOT%\%FOLDER%\src\global.json"
IF NOT EXIST "%ROOT%\%FOLDER%\.github\labeler.yml" copy /y /z %TEMPLATE%\.github\labeler.yml "%ROOT%\%FOLDER%\.github\labeler.yml"
copy /y /z %TEMPLATE%\.github\CODEOWNERS "%ROOT%\%FOLDER%\.github\CODEOWNERS"
copy /y /z %TEMPLATE%\.github\PULL_REQUEST_TEMPLATE.md "%ROOT%\%FOLDER%\.github\PULL_REQUEST_TEMPLATE.md"
md "%ROOT%\%FOLDER%\.github\workflows"
xcopy /s /e /c /y %TEMPLATE%\.github\workflows "%ROOT%\%FOLDER%\.github\workflows"

call :commit


ECHO.

POPD


ENDLOCAL
GOTO :EOF




:finish