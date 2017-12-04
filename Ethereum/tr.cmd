@echo off
cls

d:
pushd d:\work\Contracts

echo Cleaning...
DEL /Q d:\work\Contracts\build\contracts

echo Compiling...
call truffle.cmd compile --network localtest --reset

pushd Contracts
for /r %%a in (*.sol) do call solhint %a%
popd

echo Testing...
call truffle.cmd test --network localtest

git checkout -- sharedABI/*.json

popd
