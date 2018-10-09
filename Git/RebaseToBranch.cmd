@echo off
echo Rebasing changes from master into %1...
git checkout master
git fetch
git rebase origin/master
git checkout %1
git fetch
git rebase origin/%1
git fetch
git rebase origin/master
git push
git checkout master
git fetch
git rebase origin/%1
git fetch
git rebase origin/master
git push
echo Done