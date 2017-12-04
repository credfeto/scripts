@echo off
cls

d:
pushd d:\work\Contracts

echo Cleaning...
DEL /Q d:\work\Contracts\build\contracts

echo Compiling...
call truffle.cmd compile --network localtest --reset
IF ERRORLEVEL 1 goto error

SET LINTERRORS=0
pushd Contracts
for /r %%a in (*.sol) do call :lint %%a
popd

IF %LINTERRORS% GTR 0 goto :error


pause 
echo Testing...
call truffle.cmd test --network localtest

goto finish

:lint
echo Linting %1
call solhint %1
IF ERRORLEVEL 1 SET /A LINTERRORS=%LINTERRORS%+1

goto :eof

:error
ECHO *******************************************************************************
ECHO **  ERRORS FOUND 
ECHO *******************************************************************************


:finish


git checkout -- sharedABI/*.json



popd
