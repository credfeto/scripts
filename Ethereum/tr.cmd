@echo off
d:
pushd d:\work\Contracts-POC

copy /y d:\work\truffle-localtest.js d:\work\Contracts-POC\truffle.js

echo Cleaning...
DEL /Q D:\Work\Contracts-POC\build\contracts

echo Compiling...
call truffle.cmd compile --network localtest --reset

echo Testing...
call truffle.cmd test --network localtest

copy /y d:\work\truffle-original.js d:\work\Contracts-POC\truffle.js

popd
