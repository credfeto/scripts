@echo off
set GITBRANCH=
for /f %%I in ('git rev-parse --abbrev-ref HEAD 2^> NUL') do set GITBRANCH=%%I


echo Branch: %GITBRANCH%