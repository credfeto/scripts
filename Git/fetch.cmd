@echo off
for /d %%a in (*.) do call :fetch %%a
goto finish


:fetch

if not exist %1\.git\index goto :notgit

pushd %1
echo.
echo Retrieving %1:
git remote get-url origin
echo.
git fetch
popd

:notgit
goto :eof

:finish