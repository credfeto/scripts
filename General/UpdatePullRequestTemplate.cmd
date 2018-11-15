@echo off
SET SRC=D:\Work\FunServer\.github\PULL_REQUEST_TEMPLATE.md

for /D %%a in (D:\Work\*.*) do call :updateprsettings %%a

goto finish


:updateprsettings
echo %1
IF NOT EXIST "%1\.git\HEAD" goto :noupdate
IF "%1\.github\PULL_REQUEST_TEMPLATE.md" == "%SRC%" goto :noupdate

pushd "%1"
COPY /Y %SRCCODEANALYSIS%  %1\.github\PULL_REQUEST_TEMPLATE.md

git add .github
git commit -m"Updated %~NX1 GitHub PULL_REQUEST_TEMPLATE.md"
git push

popd

:noupdate
goto :eof

:finish

