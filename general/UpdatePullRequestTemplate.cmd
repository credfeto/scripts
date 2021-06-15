@echo off
SET SRC=D:\Work\FunServer\.github\PULL_REQUEST_TEMPLATE.md

for /D %%a in (D:\Work\*.*) do call :updateprsettings %%a

goto finish

:updateprsettings
echo %1
IF NOT EXIST "%1\.git\HEAD" goto :noupdate
IF "%1\.github\PULL_REQUEST_TEMPLATE.md" == "%SRC%" goto :noupdate

pushd "%1"
md %1\.github
cd %1\.github
COPY /Y %SRC%  %1\.github\PULL_REQUEST_TEMPLATE.md

git reset head --hard
git checkout master
git pull

git add PULL_REQUEST_TEMPLATE.md
git commit -m"Updated %~NX1 GitHub PULL_REQUEST_TEMPLATE.md"
git push

popd

:noupdate
goto :eof

:finish

