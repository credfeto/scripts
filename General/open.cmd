@echo off
cd /d d:\work\
call settitle.cmd

start "funfair-casino-server" cd /d d:\work\funfair-casino-server
start "funfair-wallet-server" cd /d d:\work\funfair-wallet-server
start "funfair-server-common" cd /d d:\work\funfair-server-common
start "funfair-server-ethereum" cd /d d:\work\funfair-server-ethereum
start "funfair-server-content-package-management" cd /d d:\work\funfair-server-content-package-management
start "funfair-server-content-package-builder" cd d:\work\funfair-server-content-package-builder
start "scripts" cd /d d:\work\scripts
start "funfair-server-random" cd /d d:\work\funfair-server-random
start "funfair-server-swagger" cd /d d:\work\funfair-server-swagger
start "funfair-server-alerts" cd /d d:\work\funfair-server-alerts
start "funfair-server-code-analysis" cd /d d:\work\funfair-server-code-analysis
start "funfair-server-template" cd /d d:\work\funfair-server-template
start "funfair-server-test" cd /d d:\work\funfair-server-test
