@echo off
echo Rebasing changes from master into %1...
git pull
git checkout %1
git pull
git rebase master
git pull
git push
git checkout master
git pull
git rebase %1
git pull
git push
echo Done