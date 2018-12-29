@echo off

REM Username/Email
git config --global user.name "Mark Ridgwell"
git config --global user.email credfeto@users.noreply.github.com

REM GPG Signing of commits/Tags etc
REM WORK
REM git config --global user.signingkey F2E608545D203528
REM IRELAND
REM git config --global user.signingkey 4897531CF5AE6253
REM DESKTOP
REM git config --global user.signingkey 4876FADA8731645D
git config --global commit.gpgsign true

REM Git options
git config --global pull.rebase true
git config --global merge.ff false
git config --global rebase.autosquash true
git config --global core.autocrlf true

REM Git Performance
git config --global core.preloadindex true
git config --global core.fscache true

REM Setup LG-> log
rem git config --global alias.lg "log --oneline --color --decorate --graph --branches --tags"
git config --global alias.lg "log --graph --oneline --pretty=format:'%%Cred%%h%%Creset - %%C(yellow)%%s%%Creset %%C(green)%%an%%Creset %%C(blue)%%d%%Creset' --abbrev-commit"
