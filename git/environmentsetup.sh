#! /bin/sh

# Username/Email
git config --global user.name "Mark Ridgwell"
git config --global user.email credfeto@users.noreply.github.com

# GPG Signing of commits/Tags etc
# use the following to get the ykey:
# gpg --list-keys credfeto@users.noreply.github.com | grep -E "^\s\s\s\s\s\s([A-Z0-9]+)$"
# git config --global user.signingkey 4876FADA8731645D
git config --global user.signingkey `gpg --list-keys credfeto@users.noreply.github.com | grep -E "^\s\s\s\s\s\s([A-Z0-9]+)$"`
git config --global commit.gpgsign true

# Git options
git config --global pull.rebase true
git config --global merge.ff false
git config --global rebase.autosquash true
git config --global core.autocrlf false
git config --global core.ignorecase false
git config --global fetch.prune true

# Git Performance
git config --global core.preloadindex true
git config --global core.fscache true

# Setup LG-> log
# git config --global alias.lg "log --oneline --color --decorate --graph --branches --tags"
#git config --global alias.lg "log --graph --oneline --pretty=format:'%%Cred%%h%%Creset - %%C(yellow)%%s%%Creset %%C(green)%%an%%Creset %%C(blue)%%d%%Creset' --abbrev-commit"

git config --global alias.lg "log --oneline --color --decorate --graph --branches --tags"

#renormalise files
git config --global alias.renormalise "add . --renormalize"
git config --global alias.renormalize "add . --renormalize"