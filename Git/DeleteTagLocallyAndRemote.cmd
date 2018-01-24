@echo off
SET TAG=%1

git tag -d %1
git push origin :refs/tags/%1
