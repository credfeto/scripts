@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
IF "%TEMPLATE%" EQU "" SET TEMPLATE=D:\Work\funfair-server-template
SET ROOT=%CD%
ECHO %ROOT%

echo Updating Template from %TEMPLATE%
PUSHD %TEMPLATE%
git fetch
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

:updatefile
SET FILENAME=%~1
SET TARGETFILE="%ROOT%\%FOLDER%\%FILENAME%"
SET TARGETFOLDER=
FOR %%f in (%TARGETFILE%) DO SET TARGETFOLDER=%%~dpf
MD %TARGETFOLDER% > NUL 2>&1
copy /y /z %TEMPLATE%\%FILENAME% "%TARGETFILE%"
goto :EOF

:killfile
SET FILENAME=%~1
SET TARGETFILE="%ROOT%\%FOLDER%\%FILENAME%"
del "%TARGETFILE%"
goto :EOF


:updatefileandcommit
ECHO.
echo ***********************************************************************
echo * Update %1
call :updatefile %1
call :commit %1 Updating
echo ***********************************************************************
goto :EOF


:killfileandcommit
ECHO.
echo ***********************************************************************
echo * Kill %1
call :killfile %1
call :commit %1 Removing
echo ***********************************************************************
goto :EOF


:commit
git add -A
git commit -m"[FF-1429] %2 %~1 to match the template repo"

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

REM #########################################################
REM # SIMPLE OVERWRITE UPDATES
call :updatefileandcommit .editorconfig
call :updatefileandcommit .gitleaks.toml
call ::updatefileandcommit src\CodeAnalysis.ruleset
call ::updatefileandcommit src\global.json
call ::updatefileandcommit .github\pr-lint.yml
call ::updatefileandcommit .github\CODEOWNERS
call ::updatefileandcommit .github\PULL_REQUEST_TEMPLATE.md
call ::updatefileandcommit .dependabot\config.yml
call ::updatefileandcommit .github\workflows\cc.yml
call ::updatefileandcommit .github\workflows\dependabot-auto-merge.yml
for %%w in (%TEMPLATE%\.github\workflows\*.yml) DO call ::updatefileandcommit .github\workflows\%%~nxw
call :killfileandcommit .github\workflows\editorconfig.yml
call :killfileandcommit .github\workflows\mergeconflicts.yml
call :killfileandcommit .github\workflows\label.yml
call :killfileandcommit .github\workflows\PRAssigner.yml
call :killfileandcommit .github\workflows\dependabot-auto-merge.yml

REM #########################################################
REM # COMPLICATED UPDATES
ECHO.
echo * Update R# DotSettings
for %%g in ("%ROOT%\%FOLDER%\src\*.sln") do copy /y /z %TEMPLATE%\src\FunFair.Template.sln.DotSettings %%g.DotSettings
call :commit "Jetbrains DotSettings"


ECHO.
ECHO * update .github\labeler.yml
type %TEMPLATE%\.github\labeler.yml > "%ROOT%\%FOLDER%\.github\labeler.yml"
echo. >> "%ROOT%\%FOLDER%\.github\labeler.yml"
IF EXIST "%ROOT%\%FOLDER%\.github\labeler.project-specific.yml" type "%ROOT%\%FOLDER%\.github\labeler.project-specific.yml" >> "%ROOT%\%FOLDER%\.github\labeler.yml"
call :commit "Labeller Config"

git push


ECHO.

POPD


GOTO :EOF




:finish
ENDLOCAL
