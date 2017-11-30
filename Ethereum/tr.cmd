@echo off
cls

d:
pushd d:\work\Contracts

echo Cleaning...
DEL /Q d:\work\Contracts\build\contracts

echo Compiling...
call truffle.cmd compile --network localtest --reset

echo Testing...
call truffle.cmd test --network localtest

popd
