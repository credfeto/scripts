@echo off
rem @echo on
for /d %%a in (*.*) do call :push %%a
goto finish


:push

if not exist %1\.git\index goto :notgit

pushd %1
echo.
echo Retrieving %1:
git remote get-url origin
echo.
echo * Pulling...
git pull

echo * Pushing...
git push
popd

:notgit
goto :eof

:finish