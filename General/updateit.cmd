@echo off

set FILENAME=GitVersion.yml
SET SRC=FunServer
for /d %%a in (*) do IF "%%a" NEQ "%SRC%" If Exist %%a\%FILENAME% call :update %%a

goto :finish

:update

COPY /Y %SRC%\%FILENAME% %1\%FILENAME%

pushd %1
git add %FILENAME%
git commit -m"Updated"
git push
git pull
popd

goto :eof


:finish
