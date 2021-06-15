@echo off
SET TAG=%1

git branch -d %1
git push origin :%1
