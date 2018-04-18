@echo off
rem @echo on
set ACTION=%*
for /d %%a in (*.*) do call :push %%a
goto finish

:push

if not exist %1\.git\index goto :notgit

pushd %1
echo.
echo Retrieving %1:
git remote get-url origin
echo.
call %ACTION%
popd

:notgit
goto :eof

:finish