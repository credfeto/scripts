@echo off

rem Username
git config --global user.name "Mark Ridgwell"
git config --global user.email credfeto@users.noreply.github.com

rem Git options
git config --global pull.rebase true
git config --global merge.ff false

rem Setup LG-> log
git config --global alias.lg "log --oneline --color --decorate --graph --branches --tags"

rem it Garbage Collection
git config --global gc.auto=1
git config --global gc.aggressivedepth=100
git config --global gc.aggressivewindow=400