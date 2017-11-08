pushd d:\work\Contracts-POC

copy /y d:\work\truffle-localtest.js d:\work\Contracts-POC\truffle.js

call truffle.cmd test --network localtest

copy /y d:\work\truffle-original.js d:\work\Contracts-POC\truffle.js

popd
