@echo off
cd /d d:\work\
call settitle.cmd

start "FunServer" cd /d d:\work\FunServer
start "FunWallet-Server" cd /d d:\work\FunWallet-Server
start "Common" cd /d d:\work\Common
start "Ethereum" cd /d d:\work\Ethereum
start "ContentPackageManagement" cd /d d:\work\ContentPackageManagement
start "ContentPackageBuilder" cd d:\work\ContentPackageBuilder
start "Scripts" cd /d d:\work\Scripts
start "Funfair.Random" cd /d d:\work\Funfair.Random
start "Swagger" cd /d d:\work\Swagger
start "Alerts" cd /d d:\work\Alerts
start "funfair-server-code-analysis" cd /d d:\work\funfair-server-code-analysis
start "funfair-server-template" cd /d d:\work\funfair-server-template
start "funfair-server-test" cd /d d:\work\funfair-server-test
start "Automation" cd /d d:\Automation