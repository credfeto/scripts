@echo off
SET WHEN=
FOR /F "tokens=1,2,3 delims=/" %%a in ("%DATE%") DO SET WHEN=%%c-%%b-%%a


git fetch
git checkout master
git pull
git checkout -b backup/%WHEN%
git push --set-upstream origin backup/%WHEN%
git checkout master