@echo off
cls

d:
pushd d:\work\Contracts

REM copy /y d:\work\truffle-localtest.js d:\work\Contracts\truffle.js

echo Cleaning...
DEL /Q d:\work\Contracts\build\contracts

echo Compiling...
call truffle.cmd compile --network localtest --reset

echo Testing...
call truffle.cmd test --network localtest

REM copy /y d:\work\truffle-original.js d:\work\Contracts\truffle.js

popd
