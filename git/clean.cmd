@echo off
rem See: https://koukia.ca/how-to-remove-local-untracked-files-from-the-current-git-branch-571c6ce9b6b1
echo Cleaning...
git clean -f -x -d
echo Complete.
