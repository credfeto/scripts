@echo off

echo Setup Git Environment
call %~DP0EnvironmentSetup.cmd

rem @echo on
for /d %%a in (*.*) do call :fetch %%a

call %~D0

call %~DP0EnvironmentSetup.cmd

goto finish


:fetch

if not exist %1\.git\index goto :notgit

pushd %1
echo.
echo Retrieving %1:
git remote get-url origin
echo.
echo * Fetching...
git fetch

rem determine whether to pull changes (i.e. if there is no changes in the workspace)
git status > "%TEMP%\gitfetch.log"
find /i "nothing to commit, working tree clean" "%TEMP%\gitfetch.log" > NUL
IF %ERRORLEVEL% == 0 call :pull
popd

:notgit
goto :eof

:pull
echo * Pulling....
git pull
echo * Pruning unreachable...
git prune
echo * Running GC...
git gc --aggressive --prune
echo * Done
echo.

goto :eof

:finish